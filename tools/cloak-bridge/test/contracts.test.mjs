import test from "node:test";
import assert from "node:assert/strict";
import { calculateFeeQuote } from "../src/contracts.ts";
import { handleCommand } from "../src/index.ts";
import { hasForbiddenField, validateNoForbiddenFields } from "../src/redaction.ts";

test("health returns safe JSON", () => {
  const response = handleCommand("health", {});

  assert.equal(response.status, "ok");
  assert.equal(response.programId, "zh1eLd6rSphLejbFfJEneUwzHRfMKxgzrgkfwA6qRkW");
  assert.equal("txPayload" in response, false);
});

test("env-check returns no secrets", () => {
  const response = handleCommand("env-check", { network: "mainnet-beta" });
  const json = JSON.stringify(response).toLowerCase();

  assert.equal(response.status, "ok");
  assert.equal(json.includes("privatekey"), false);
  assert.equal(json.includes("mnemonic"), false);
  assert.equal(json.includes("serializedtransaction"), false);
});

test("deposit-plan uses integer fee math and returns no executable payload", () => {
  const response = handleCommand("deposit-plan", {
    requestId: "req-1",
    network: "mainnet-beta",
    walletPublicAddress: "11111111111111111111111111111111",
    amountLamports: "50000000",
  });

  assert.equal(response.status, "locked");
  assert.equal(response.errorCategory, "locked-in-phase-2-2");
  assert.equal(response.feeQuote.totalFeeLamports, "5150000");
  assert.equal(response.feeQuote.netLamports, "44850000");
  assert.equal("serializedTransaction" in response, false);
  assert.equal("transactionPayload" in response, false);
});

test("forbidden fields are rejected", () => {
  assert.equal(hasForbiddenField("privateKey"), true);
  assert.equal(hasForbiddenField("serializedTransaction"), true);
  assert.throws(() => validateNoForbiddenFields({ nested: { viewingKey: "no" } }));
  assert.throws(() => handleCommand("deposit-plan", {
    amountLamports: "50000000",
    utxoPrivateKey: "no",
  }));
});

test("future execution commands are locked", () => {
  const response = handleCommand("execute-deposit", { amountLamports: "50000000" });
  const complianceResponse = handleCommand("compliance-export", {});

  assert.equal(response.status, "locked");
  assert.equal(response.errorCategory, "locked-in-phase-2-2");
  assert.equal(complianceResponse.status, "locked");
  assert.equal(complianceResponse.errorCategory, "locked-in-phase-2-2");
});

test("fee helper rejects below-minimum deposit", () => {
  assert.throws(() => calculateFeeQuote("9999999"));
});
