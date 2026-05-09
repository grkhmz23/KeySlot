import test from "node:test";
import assert from "node:assert/strict";
import { calculateFeeQuote } from "../src/contracts.ts";
import { SUSPICIOUS_SECRET_ENV_NAMES } from "../src/environment.ts";
import { handleCommand } from "../src/index.ts";
import { hasForbiddenField, validateNoForbiddenFields } from "../src/redaction.ts";

test("health returns safe JSON with SDK validation", async () => {
  const response = await handleCommand("health", {});

  assert.equal(response.status, "ok");
  assert.equal(response.programId, "zh1eLd6rSphLejbFfJEneUwzHRfMKxgzrgkfwA6qRkW");
  assert.equal("txPayload" in response, false);
  assert.equal(response.sdkValidation.sdkInstalled, true);
  assert.equal(response.sdkValidation.sdkImportOk, true);
  assert.equal(response.sdkValidation.expectedProgramId, "zh1eLd6rSphLejbFfJEneUwzHRfMKxgzrgkfwA6qRkW");
  assert.equal(response.sdkValidation.programIdMatches, true);
  assert.equal(response.sdkValidation.nativeSolMint, "So11111111111111111111111111111111111111112");
});

test("env-check returns no secrets and redacts RPC URL", async () => {
  const oldRpc = process.env.SOLANA_RPC_URL;
  const oldSuspicious = snapshotEnv(SUSPICIOUS_SECRET_ENV_NAMES);
  clearEnv(SUSPICIOUS_SECRET_ENV_NAMES);
  process.env.SOLANA_RPC_URL = "https://api.mainnet-beta.solana.com/path?token=do-not-print";
  const response = await handleCommand("env-check", { network: "mainnet-beta" });
  if (oldRpc === undefined) {
    delete process.env.SOLANA_RPC_URL;
  } else {
    process.env.SOLANA_RPC_URL = oldRpc;
  }
  restoreEnv(oldSuspicious);

  const json = JSON.stringify(response).toLowerCase();

  assert.equal(response.status, "ok");
  assert.equal(response.environmentValidation.solanaRpcUrlStatus, "present-redacted");
  assert.equal(response.environmentValidation.rpcUrlRedacted, "SOLANA_RPC_URL configured (redacted)");
  assert.equal(json.includes("api.mainnet-beta.solana.com"), false);
  assert.equal(json.includes("do-not-print"), false);
  assert.equal(json.includes("privatekey"), false);
  assert.equal(json.includes("mnemonic"), false);
  assert.equal(json.includes("serializedtransaction"), false);
});

test("env-check rejects suspicious wallet secret env names without printing values", async () => {
  const oldSuspicious = snapshotEnv(SUSPICIOUS_SECRET_ENV_NAMES);
  clearEnv(SUSPICIOUS_SECRET_ENV_NAMES);
  process.env.PRIVATE_KEY = "do-not-print";
  const response = await handleCommand("env-check", { network: "mainnet-beta" });
  restoreEnv(oldSuspicious);

  const json = JSON.stringify(response);
  assert.equal(response.status, "rejected");
  assert.equal(response.errorCategory, "forbidden-field");
  assert.deepEqual(response.environmentValidation.suspiciousEnvVarNames, ["PRIVATE_KEY"]);
  assert.equal(json.includes("do-not-print"), false);
});

function snapshotEnv(names) {
  return Object.fromEntries(names.map((name) => [name, process.env[name]]));
}

function clearEnv(names) {
  for (const name of names) {
    delete process.env[name];
  }
}

function restoreEnv(snapshot) {
  for (const [name, value] of Object.entries(snapshot)) {
    if (value === undefined) {
      delete process.env[name];
    } else {
      process.env[name] = value;
    }
  }
}

test("deposit-plan uses integer fee math and returns no executable payload", async () => {
  const response = await handleCommand("deposit-plan", {
    requestId: "req-1",
    network: "mainnet-beta",
    walletPublicAddress: "11111111111111111111111111111111",
    amountLamports: "50000000",
  });

  assert.equal(response.status, "locked");
  assert.equal(response.errorCategory, "locked-in-phase-2-3");
  assert.equal(response.feeQuote.totalFeeLamports, "5150000");
  assert.equal(response.feeQuote.netLamports, "44850000");
  assert.equal("serializedTransaction" in response, false);
  assert.equal("transactionPayload" in response, false);
  assert.equal(response.sdkValidation.programIdMatches, true);
  assert.equal(response.feeValidation.available, true);
  assert.equal(response.feeValidation.samples.length, 3);
  assert.equal(response.signerRequestSummary.requestKind, "sign_transaction_preview");
  assert.equal(response.signerRequestSummary.bridgeState, "locked");
  assert.equal(response.signerRequestSummary.amountLamports, "50000000");
  assert.equal(response.signerRequestSummary.programId, "zh1eLd6rSphLejbFfJEneUwzHRfMKxgzrgkfwA6qRkW");
  assert.equal(response.signerRequestSummary.draftFingerprint.length, 64);
  assert.equal(response.nextRequiredGates.includes("Shield review"), true);
});

test("forbidden fields are rejected", async () => {
  assert.equal(hasForbiddenField("privateKey"), true);
  assert.equal(hasForbiddenField("PRIVATE_KEY"), true);
  assert.equal(hasForbiddenField("signingSeed"), true);
  assert.equal(hasForbiddenField("serializedTransaction"), true);
  assert.equal(hasForbiddenField("messageBytes"), true);
  assert.throws(() => validateNoForbiddenFields({ nested: { viewingKey: "no" } }));
  await assert.rejects(() => handleCommand("deposit-plan", {
    amountLamports: "50000000",
    utxoPrivateKey: "no",
  }));
  await assert.rejects(() => handleCommand("deposit-plan", {
    amountLamports: "50000000",
    messageBytes: "no",
  }));
});

test("deposit-plan signer placeholder is locked and contains no executable payload", async () => {
  const response = await handleCommand("deposit-plan", {
    requestId: "req-2",
    network: "mainnet-beta",
    walletPublicAddress: "11111111111111111111111111111111",
    amountLamports: "50000000",
  });
  const json = JSON.stringify(response).toLowerCase();

  assert.equal(response.signerRequestSummary.approvalState, "locked");
  assert.equal(response.signerRequestSummary.bridgeState, "locked");
  assert.equal(response.signerRequestSummary.walletPublicKey, "11111111111111111111111111111111");
  assert.equal("serializedTransaction" in response.signerRequestSummary, false);
  assert.equal("transactionPayload" in response.signerRequestSummary, false);
  assert.equal("transactionBytes" in response.signerRequestSummary, false);
  assert.equal("messageBytes" in response.signerRequestSummary, false);
  assert.equal(json.includes("serializedtransaction"), false);
  assert.equal(json.includes("transactionpayload"), false);
  assert.equal(json.includes("transactionbytes"), false);
  assert.equal(json.includes("messagebytes"), false);
});

test("future execution commands are locked", async () => {
  const response = await handleCommand("execute-deposit", { amountLamports: "50000000" });
  const complianceResponse = await handleCommand("compliance-export", {});

  assert.equal(response.status, "locked");
  assert.equal(response.errorCategory, "locked-in-phase-2-3");
  assert.equal(complianceResponse.status, "locked");
  assert.equal(complianceResponse.errorCategory, "locked-in-phase-2-3");
});

test("fee helper rejects below-minimum deposit", () => {
  assert.throws(() => calculateFeeQuote("9999999"));
});

test("helper source does not call SDK transaction methods", async () => {
  const { readFile } = await import("node:fs/promises");
  const files = [
    new URL("../src/sdk.ts", import.meta.url),
    new URL("../src/commands/health.ts", import.meta.url),
    new URL("../src/commands/envCheck.ts", import.meta.url),
    new URL("../src/commands/depositPlan.ts", import.meta.url),
  ];
  const combined = (await Promise.all(files.map((file) => readFile(file, "utf8")))).join("\n");

  for (const forbiddenCall of [
    "transact(",
    "fullWithdraw(",
    "partialWithdraw(",
    "transfer(",
    "swapWithChange(",
    "swapUtxo(",
    "scanTransactions(",
    "toComplianceReport(",
  ]) {
    assert.equal(combined.includes(forbiddenCall), false);
  }
});
