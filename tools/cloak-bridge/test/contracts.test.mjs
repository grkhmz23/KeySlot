import test from "node:test";
import assert from "node:assert/strict";
import { calculateFeeQuote, EXECUTION_COMMANDS } from "../src/contracts.ts";
import { SUSPICIOUS_SECRET_ENV_NAMES } from "../src/environment.ts";
import { handleCommand } from "../src/index.ts";
import { resolveCloakRPCConfiguration } from "../src/rpc.ts";
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
  const oldRpcFast = process.env.GORKH_RPCFAST_MAINNET_TOKEN;
  const oldSuspicious = snapshotEnv(SUSPICIOUS_SECRET_ENV_NAMES);
  clearEnv(SUSPICIOUS_SECRET_ENV_NAMES);
  process.env.SOLANA_RPC_URL = "https://api.mainnet-beta.solana.com/path?token=do-not-print";
  process.env.GORKH_RPCFAST_MAINNET_TOKEN = "rpcfast-token-do-not-print";
  const response = await handleCommand("env-check", { network: "mainnet-beta" });
  if (oldRpc === undefined) {
    delete process.env.SOLANA_RPC_URL;
  } else {
    process.env.SOLANA_RPC_URL = oldRpc;
  }
  if (oldRpcFast === undefined) {
    delete process.env.GORKH_RPCFAST_MAINNET_TOKEN;
  } else {
    process.env.GORKH_RPCFAST_MAINNET_TOKEN = oldRpcFast;
  }
  restoreEnv(oldSuspicious);

  const json = JSON.stringify(response).toLowerCase();

  assert.equal(response.status, "ok");
  assert.equal(response.environmentValidation.solanaRpcUrlStatus, "present-redacted");
  assert.equal(response.environmentValidation.rpcUrlRedacted, "SOLANA_RPC_URL configured (redacted)");
  assert.equal(response.environmentValidation.rpcProvider, "rpcfast");
  assert.equal(response.environmentValidation.rpcHost, "solana-rpc.rpcfast.com");
  assert.equal(response.environmentValidation.rpcFastTokenStatus, "present");
  assert.equal(json.includes("api.mainnet-beta.solana.com"), false);
  assert.equal(json.includes("do-not-print"), false);
  assert.equal(json.includes("rpcfast-token-do-not-print"), false);
  assert.equal(json.includes("privatekey"), false);
  assert.equal(json.includes("mnemonic"), false);
  assert.equal(json.includes("serializedtransaction"), false);
});

test("RPC Fast configuration uses X-Token header without exposing token", () => {
  const config = resolveCloakRPCConfiguration(undefined, {
    GORKH_RPCFAST_MAINNET_TOKEN: "rpcfast-token-do-not-print",
  });

  assert.equal(config.provider, "rpcfast");
  assert.equal(config.endpoint, "https://solana-rpc.rpcfast.com/");
  assert.equal(config.httpHeaders["X-Token"], "rpcfast-token-do-not-print");
  assert.equal(JSON.stringify({
    provider: config.provider,
    host: config.host,
    tokenStatus: config.tokenStatus,
    message: config.message,
  }).includes("rpcfast-token-do-not-print"), false);
  assert.equal(config.endpoint.includes("api_key="), false);
});

test("RPC Fast missing token fallback is explicit and redacted", () => {
  const config = resolveCloakRPCConfiguration(undefined, {});

  assert.equal(config.provider, "fallback");
  assert.equal(config.tokenStatus, "missing");
  assert.equal(config.host, "api.mainnet-beta.solana.com");
  assert.equal(config.message.includes("RPC Fast token missing"), true);
  assert.equal(JSON.stringify(config).includes("api_key="), false);
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

test("scan command rejects missing local scan state safely", async () => {
  const response = await handleCommand("scan", {
    requestId: "req-scan-1",
    network: "mainnet-beta",
    walletPublicAddress: "11111111111111111111111111111111",
  });
  const json = JSON.stringify(response).toLowerCase();

  assert.equal(response.status, "rejected");
  assert.equal(response.errorCategory, "invalid-request");
  assert.equal(response.scanSummary.status, "error");
  assert.equal(response.scanSummary.transactionCount, 0);
  assert.equal(json.includes("viewingkey"), false);
  assert.equal(json.includes("utxoprivatekey"), false);
  assert.equal(json.includes("nullifier"), false);
  assert.equal(json.includes("proofinput"), false);
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

test("phase 2.5 execution commands are isolated from dry-run handleCommand", async () => {
  assert.deepEqual(EXECUTION_COMMANDS, ["execute-deposit", "full-withdraw"]);

  for (const command of EXECUTION_COMMANDS) {
    const response = await handleCommand(command, {
      network: "mainnet-beta",
      walletPublicAddress: "11111111111111111111111111111111",
      amountLamports: "50000000",
      approvedDraftFingerprint: "abc",
    });
    assert.equal(response.status, "locked");
    assert.equal(response.errorCategory, "locked-in-phase-2-3");
    assert.equal("secureOutputStateBase64" in response, false);
    assert.equal("secureViewingStateBase64" in response, false);
    assert.equal("secureSpentStateBase64" in response, false);
  }
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
  ]) {
    assert.equal(combined.includes(forbiddenCall), false);
  }
});

test("scan helper source only calls approved read-only scan methods", async () => {
  const { readFile } = await import("node:fs/promises");
  const source = await readFile(new URL("../src/commands/scan.ts", import.meta.url), "utf8");

  assert.equal(source.includes("scanTransactions("), true);
  assert.equal(source.includes("toComplianceReport("), true);
  for (const forbiddenCall of [
    "transact(",
    "fullWithdraw(",
    "partialWithdraw(",
    "transfer(",
    "swapWithChange(",
    "swapUtxo(",
    "console.log",
    "child_process",
    "exec(",
    "spawn(",
  ]) {
    assert.equal(source.includes(forbiddenCall), false);
  }
});

test("execution helper source only calls approved Cloak SDK execution methods", async () => {
  const { readFile } = await import("node:fs/promises");
  const source = await readFile(new URL("../src/commands/execute.ts", import.meta.url), "utf8");

  assert.equal(source.includes("transact("), true);
  assert.equal(source.includes("fullWithdraw("), true);
  assert.equal(source.includes("privateOutputAmount = amount"), true);
  assert.equal(source.includes("privateOutputAmount = BigInt(feeQuote.netLamports)"), false);
  for (const forbiddenCall of [
    "partialWithdraw(",
    "transfer(",
    "swapWithChange(",
    "swapUtxo(",
    "scanTransactions(",
    "toComplianceReport(",
    "console.log",
    "child_process",
    "exec(",
    "spawn(",
  ]) {
    assert.equal(source.includes(forbiddenCall), false);
  }
});
