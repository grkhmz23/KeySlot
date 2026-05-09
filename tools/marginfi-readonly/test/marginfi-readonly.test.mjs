import test from "node:test";
import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import { PublicKey } from "@solana/web3.js";
import { handleCommand } from "../src/index.ts";
import { FORBIDDEN_SDK_METHODS, isForbiddenSdkMethodName } from "../src/forbiddenMethods.ts";
import { ReadOnlyWallet } from "../src/readOnlyWallet.ts";
import { hasForbiddenField, SUSPICIOUS_SECRET_ENV_NAMES, validateNoForbiddenFields } from "../src/redaction.ts";
import {
  DEFAULT_PUBLIC_SMOKE_WALLET,
  assertSmokeSummaryIsSafe,
  buildSmokeSummary,
} from "../src/smoke.ts";

test("health returns safe SDK read-only status", async () => {
  const result = await handleCommand("health", {});
  const json = JSON.stringify(result).toLowerCase();

  assert.equal(result.command, "health");
  assert.equal(result.programId, "MFv2hWf31Z9kbCa1snEPYctwafyhdvnV7FZnsebVacA");
  assert.equal(result.sdkValidation.expectedProgramId, "MFv2hWf31Z9kbCa1snEPYctwafyhdvnV7FZnsebVacA");
  assert.equal(result.sdkValidation.readOnlyWallet, true);
  assert.equal(json.includes("privatekey"), false);
  assert.equal(json.includes("serializedtransaction"), false);
  assert.equal(json.includes("instructionpayload"), false);
});

test("env-check rejects suspicious env names without printing values", async () => {
  const oldSuspicious = snapshotEnv(SUSPICIOUS_SECRET_ENV_NAMES);
  clearEnv(SUSPICIOUS_SECRET_ENV_NAMES);
  process.env.PRIVATE_KEY = "do-not-print";
  const result = await handleCommand("env-check", { network: "mainnet-beta", rpcUrl: "https://example.invalid/?token=secret" });
  restoreEnv(oldSuspicious);
  const json = JSON.stringify(result);

  assert.equal(result.status, "rejected");
  assert.deepEqual(result.environmentValidation.suspiciousEnvVarNames, ["PRIVATE_KEY"]);
  assert.equal(json.includes("do-not-print"), false);
  assert.equal(json.includes("token=secret"), false);
});

test("forbidden input fields are rejected", () => {
  assert.equal(hasForbiddenField("privateKey"), true);
  assert.equal(hasForbiddenField("signingSeed"), true);
  assert.equal(hasForbiddenField("transactionPayload"), true);
  assert.throws(() => validateNoForbiddenFields({ nested: { walletJson: "no" } }));
});

test("read-only wallet stub throws on every signing method", async () => {
  const wallet = new ReadOnlyWallet(new PublicKey("11111111111111111111111111111111"));

  await assert.rejects(() => wallet.signTransaction({}));
  await assert.rejects(() => wallet.signAllTransactions([]));
  await assert.rejects(() => wallet.signMessage(new Uint8Array([1, 2, 3])));
});

test("positions handles missing RPC as unavailable without executable payload", async () => {
  const oldRpc = process.env.SOLANA_RPC_URL;
  delete process.env.SOLANA_RPC_URL;
  const result = await handleCommand("positions", {
    requestId: "req-1",
    network: "mainnet-beta",
    walletPublicAddress: "11111111111111111111111111111111",
  });
  if (oldRpc === undefined) {
    delete process.env.SOLANA_RPC_URL;
  } else {
    process.env.SOLANA_RPC_URL = oldRpc;
  }

  const json = JSON.stringify(result).toLowerCase();
  assert.equal(result.status, "unavailable");
  assert.equal(result.errorCategory, "rpc-unavailable");
  assert.equal(json.includes("serializedtransaction"), false);
  assert.equal(json.includes("transactionpayload"), false);
});

test("dangerous SDK method names are denylisted and not used by read-only client", async () => {
  for (const method of FORBIDDEN_SDK_METHODS) {
    assert.equal(isForbiddenSdkMethodName(method), true);
  }

  const source = await readFile(new URL("../src/readOnlyClient.ts", import.meta.url), "utf8");
  for (const method of FORBIDDEN_SDK_METHODS) {
    assert.equal(source.includes(`${method}(`), false, `${method} must not be called`);
    assert.equal(source.includes(`.${method}(`), false, `${method} must not be referenced as a method call`);
  }
});

test("forbidden SDK action method names are absent from runtime source outside denylist", async () => {
  const srcDir = new URL("../src/", import.meta.url);
  const files = (await readdir(srcDir)).filter((file) => file.endsWith(".ts") && file !== "forbiddenMethods.ts");

  for (const file of files) {
    const source = await readFile(new URL(`../src/${file}`, import.meta.url), "utf8");
    for (const method of FORBIDDEN_SDK_METHODS) {
      assert.equal(source.includes(`${method}(`), false, `${method} must not be called in ${file}`);
      assert.equal(source.includes(`.${method}(`), false, `${method} must not be called as a method in ${file}`);
    }
  }
});

test("future execution commands are unsupported", async () => {
  const result = await handleCommand("deposit", {});
  assert.equal(result.status, "rejected");
});

test("smoke summary reports empty wallet state without raw helper payloads", () => {
  const health = baseResponse("health", "ok", {
    sdkValidation: {
      sdkInstalled: true,
      sdkImportOk: true,
      sdkVersion: "4.0.4",
      programId: "MFv2hWf31Z9kbCa1snEPYctwafyhdvnV7FZnsebVacA",
      expectedProgramId: "MFv2hWf31Z9kbCa1snEPYctwafyhdvnV7FZnsebVacA",
      programIdMatches: true,
      groupId: "4qp6Fx6tnZkY5Wropq9wUYgtFxXKwE6viZxFHg3rdAG8",
      groupIdSource: "sdk-config",
      readOnlyWallet: true,
    },
  });
  const env = baseResponse("env-check", "ok", {
    environmentValidation: {
      network: "mainnet-beta",
      networkSupported: true,
      rpcUrlStatus: "present-redacted",
      rpcUrlRedacted: "RPC URL configured (redacted)",
      walletSecretEnvAccepted: false,
      suspiciousEnvVarNames: [],
    },
  });
  const positions = baseResponse("positions", "empty", {
    message: "No MarginFi accounts returned for this public authority.",
    positions: [],
    accountCount: 0,
    suppliedPositionCount: 0,
    borrowedPositionCount: 0,
  });

  const summary = buildSmokeSummary({
    requestId: "smoke-test",
    walletPublicAddress: DEFAULT_PUBLIC_SMOKE_WALLET,
    expectedStatus: "empty",
    health,
    env,
    positions,
  });
  const json = JSON.stringify(summary).toLowerCase();

  assert.equal(summary.status, "ok");
  assert.equal(summary.expectedStatusMatched, true);
  assert.equal(summary.positionsStatus, "empty");
  assert.equal(json.includes("serializedtransaction"), false);
  assert.equal(json.includes("instructionpayload"), false);
});

test("smoke summary redaction rejects unsafe fields", () => {
  assert.throws(() => assertSmokeSummaryIsSafe({
    status: "failed",
    requestId: "bad",
    walletPublicAddress: DEFAULT_PUBLIC_SMOKE_WALLET,
    healthStatus: "ok",
    envStatus: "ok",
    positionsStatus: "error",
    programId: "MFv2hWf31Z9kbCa1snEPYctwafyhdvnV7FZnsebVacA",
    accountCount: 0,
    suppliedPositionCount: 0,
    borrowedPositionCount: 0,
    reason: "serializedTransaction appeared in a bad helper response",
    timestamp: new Date().toISOString(),
  }));
});

test("direct helper dependencies are exact pinned versions", async () => {
  const pkg = JSON.parse(await readFile(new URL("../package.json", import.meta.url), "utf8"));
  assert.equal(pkg.dependencies["@mrgnlabs/marginfi-client-v2"], "4.0.4");
  assert.equal(pkg.dependencies["@mrgnlabs/mrgn-common"], "2.0.7");
  assert.equal(pkg.dependencies["@solana/web3.js"], "1.98.4");
  assert.equal(pkg.dependencies.debug, "4.4.1");
  for (const version of Object.values(pkg.dependencies)) {
    assert.equal(/^[~^*]/.test(version), false, `${version} must be exact`);
  }
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

function baseResponse(command, status, overrides = {}) {
  return {
    id: `test-${command}`,
    command,
    status,
    errorCategory: "none",
    message: "",
    programId: "MFv2hWf31Z9kbCa1snEPYctwafyhdvnV7FZnsebVacA",
    timestamp: new Date().toISOString(),
    ...overrides,
  };
}
