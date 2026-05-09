#!/usr/bin/env node
import { performance } from "node:perf_hooks";

const DEFAULT_WALLET = "11111111111111111111111111111111";
const TOKEN_PROGRAM_ID = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA";
const TOKEN_2022_PROGRAM_ID = "TokenzQdBNbLqP5VEhdkAS6EPFLCn8G1SU4Bvf9Ss623VQ5DA";
const STAKE_PROGRAM_ID = "Stake11111111111111111111111111111111111111";

const NETWORKS = {
  devnet: {
    id: "devnet",
    displayName: "Devnet",
    httpURL: "https://sol-devnet-rpc.rpcfast.com",
    webSocketURL: "wss://sol-devnet-rpc.rpcfast.com",
    tokenNames: ["GORKH_RPCFAST_DEVNET_TOKEN", "RPCFAST_DEVNET_TOKEN"],
  },
  "mainnet-beta": {
    id: "mainnet-beta",
    displayName: "Mainnet Beta",
    httpURL: "https://solana-rpc.rpcfast.com/",
    webSocketURL: "wss://solana-rpc.rpcfast.com/",
    tokenNames: ["GORKH_RPCFAST_MAINNET_TOKEN", "RPCFAST_MAINNET_TOKEN"],
  },
};

const READ_CHECKS = [
  { name: "getHealth", method: "getHealth", params: [], required: true },
  { name: "getVersion", method: "getVersion", params: [], required: true },
  { name: "getSlot", method: "getSlot", params: [{ commitment: "confirmed" }], required: true },
  { name: "getBlockHeight", method: "getBlockHeight", params: [{ commitment: "confirmed" }], required: true },
  { name: "getBalance", method: "getBalance", params: ({ wallet }) => [wallet], required: true },
  {
    name: "getTokenAccountsByOwner:spl-token",
    method: "getTokenAccountsByOwner",
    params: ({ wallet }) => [
      wallet,
      { programId: TOKEN_PROGRAM_ID },
      { encoding: "jsonParsed", commitment: "confirmed" },
    ],
    required: false,
  },
  {
    name: "getTokenAccountsByOwner:token-2022",
    method: "getTokenAccountsByOwner",
    params: ({ wallet }) => [
      wallet,
      { programId: TOKEN_2022_PROGRAM_ID },
      { encoding: "jsonParsed", commitment: "confirmed" },
    ],
    required: false,
  },
  {
    name: "stakeDiscovery:stakerAuthority",
    method: "getProgramAccounts",
    params: ({ wallet }) => stakeDiscoveryParams(wallet, 12),
    required: false,
    planLimited: true,
  },
  {
    name: "stakeDiscovery:withdrawerAuthority",
    method: "getProgramAccounts",
    params: ({ wallet }) => stakeDiscoveryParams(wallet, 44),
    required: false,
    planLimited: true,
  },
];

function stakeDiscoveryParams(wallet, offset) {
  return [
    STAKE_PROGRAM_ID,
    {
      encoding: "jsonParsed",
      commitment: "confirmed",
      filters: [
        { dataSize: 200 },
        { memcmp: { offset, bytes: wallet } },
      ],
    },
  ];
}

function parseArgs(argv) {
  const options = {
    networks: new Set(),
    wallet: process.env.GORKH_RPCFAST_SMOKE_WALLET || DEFAULT_WALLET,
    json: false,
    skipMainnet: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    switch (arg) {
      case "--devnet":
        options.networks.add("devnet");
        break;
      case "--mainnet":
        options.networks.add("mainnet-beta");
        break;
      case "--all":
        options.networks.add("devnet");
        options.networks.add("mainnet-beta");
        break;
      case "--skip-mainnet":
        options.skipMainnet = true;
        break;
      case "--wallet":
        options.wallet = argv[++index];
        break;
      case "--json":
        options.json = true;
        break;
      case "--help":
        printHelpAndExit();
        break;
      default:
        throw new Error(`Unsupported argument: ${arg}`);
    }
  }

  if (options.networks.size === 0) {
    options.networks.add("devnet");
  }
  if (options.skipMainnet) {
    options.networks.delete("mainnet-beta");
  }
  return options;
}

function printHelpAndExit() {
  process.stdout.write([
    "GORKH RPC Fast wallet read-path smoke",
    "Usage: scripts/rpcfast-wallet-smoke.sh [--devnet|--mainnet|--all] [--skip-mainnet] [--wallet <public-address>] [--json]",
    "Environment: GORKH_RPCFAST_DEVNET_TOKEN, GORKH_RPCFAST_MAINNET_TOKEN, RPCFAST_DEVNET_TOKEN, RPCFAST_MAINNET_TOKEN.",
    "Output never prints token values.",
    "",
  ].join("\n"));
  process.exit(0);
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const summaries = [];
  for (const id of options.networks) {
    summaries.push(await smokeNetwork(NETWORKS[id], options.wallet));
  }

  const summary = {
    status: overallStatus(summaries),
    provider: "RPC Fast",
    walletPublicAddress: options.wallet,
    networks: summaries,
    beamStatus: "locked-future",
    timestamp: new Date().toISOString(),
  };
  assertSafeSummary(summary);

  if (options.json) {
    process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
  } else {
    printHumanSummary(summary);
  }

  process.exit(summary.status === "failed" ? 1 : 0);
}

async function smokeNetwork(network, wallet) {
  const tokenInfo = tokenFor(network);
  const base = {
    network: network.id,
    httpHost: host(network.httpURL),
    webSocketHost: host(network.webSocketURL),
    tokenStatus: tokenInfo.present ? "present" : "missing",
    status: "skipped-token-missing",
    checks: [],
    providerLimitations: [],
  };

  if (!tokenInfo.present) {
    return {
      ...base,
      message: `RPC Fast token missing. Set ${network.tokenNames.join(" or ")}.`,
    };
  }

  for (const check of READ_CHECKS) {
    const result = await runReadCheck(network, tokenInfo.value, check, wallet);
    base.checks.push(result);
    if (result.status !== "pass" && result.normalizedError) {
      base.providerLimitations.push({
        check: check.name,
        category: result.normalizedError.category,
        message: result.normalizedError.message,
      });
    }
  }

  const requiredFailures = base.checks.filter((check) => check.required && check.status !== "pass");
  base.status = requiredFailures.length === 0
    ? (base.providerLimitations.length === 0 ? "passed" : "degraded")
    : "failed";
  return base;
}

function tokenFor(network) {
  for (const name of network.tokenNames) {
    const value = (process.env[name] || "").trim();
    if (value.length > 0) {
      return { present: true, name, value };
    }
  }
  return { present: false };
}

async function runReadCheck(network, token, check, wallet) {
  const started = performance.now();
  const params = typeof check.params === "function" ? check.params({ wallet }) : check.params;
  try {
    const result = await rpcCall(network, token, check.method, params);
    return {
      name: check.name,
      method: check.method,
      required: check.required,
      planLimited: check.planLimited === true,
      status: "pass",
      latencyMs: Math.round(performance.now() - started),
      summary: summarizeResult(check.name, result),
    };
  } catch (error) {
    const normalizedError = normalizeError(error);
    return {
      name: check.name,
      method: check.method,
      required: check.required,
      planLimited: check.planLimited === true,
      status: check.required ? "fail" : "warn",
      latencyMs: Math.round(performance.now() - started),
      normalizedError,
    };
  }
}

async function rpcCall(network, token, method, params) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 12_000);
  try {
    const response = await fetch(network.httpURL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Token": token,
      },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: `rpcfast-smoke-${Date.now()}`,
        method,
        params,
      }),
      signal: controller.signal,
    });
    const text = await response.text();
    if (!response.ok) {
      throw { statusCode: response.status, message: text || response.statusText };
    }
    const json = JSON.parse(text);
    if (json.error) {
      throw { statusCode: undefined, message: json.error.message || "RPC error" };
    }
    return json.result;
  } finally {
    clearTimeout(timeout);
  }
}

function summarizeResult(name, result) {
  if (name === "getHealth") {
    return { health: String(result) };
  }
  if (name === "getVersion") {
    return { version: result?.["solana-core"] || "unknown" };
  }
  if (name === "getSlot") {
    return { slot: Number(result) };
  }
  if (name === "getBlockHeight") {
    return { blockHeight: Number(result) };
  }
  if (name === "getBalance") {
    return { lamports: Number(result?.value ?? 0) };
  }
  if (name.startsWith("getTokenAccountsByOwner")) {
    return { accountCount: Array.isArray(result?.value) ? result.value.length : 0 };
  }
  if (name.startsWith("stakeDiscovery")) {
    return { stakeAccountCount: Array.isArray(result) ? result.length : 0 };
  }
  return { ok: true };
}

function normalizeError(error) {
  const statusCode = error?.statusCode;
  const message = redact(String(error?.message || error?.cause || error || "RPC Fast request failed."));
  const lower = message.toLowerCase();
  if (statusCode === 401 || statusCode === 403 || lower.includes("unauthorized") || lower.includes("forbidden")) {
    return { category: "unauthorized", message: "RPC Fast authorization failed. Check local token env vars." };
  }
  if (statusCode === 429 || lower.includes("rate limit") || lower.includes("too many requests")) {
    return { category: "rate-limited", message: "RPC Fast rate limit reached." };
  }
  if (lower.includes("upgrade") || lower.includes("plan") || lower.includes("compute unit")) {
    return { category: "plan-upgrade-required", message: "RPC Fast plan does not allow this method or usage level." };
  }
  if (lower.includes("blocked") || lower.includes("not allowed") || lower.includes("disabled")) {
    return { category: "method-blocked", message: "RPC Fast blocked this RPC method or program." };
  }
  if (lower.includes("abort") || lower.includes("timeout") || lower.includes("timed out")) {
    return { category: "timeout", message: "RPC Fast endpoint timed out." };
  }
  return { category: "unknown", message };
}

function overallStatus(networks) {
  if (networks.some((network) => network.status === "failed")) {
    return "failed";
  }
  if (networks.some((network) => network.status === "degraded")) {
    return "degraded";
  }
  if (networks.every((network) => network.status === "skipped-token-missing")) {
    return "skipped-token-missing";
  }
  return "passed";
}

function printHumanSummary(summary) {
  process.stdout.write("GORKH RPC Fast wallet read-path smoke\n");
  process.stdout.write(`Provider: ${summary.provider}\n`);
  process.stdout.write(`Wallet: ${summary.walletPublicAddress}\n`);
  process.stdout.write(`Beam: ${summary.beamStatus}\n\n`);

  for (const network of summary.networks) {
    process.stdout.write(`${network.network}\n`);
    process.stdout.write(`  HTTP host: ${network.httpHost}\n`);
    process.stdout.write(`  WebSocket host: ${network.webSocketHost}\n`);
    process.stdout.write(`  Token: ${network.tokenStatus}\n`);
    process.stdout.write(`  Status: ${network.status}\n`);
    if (network.message) {
      process.stdout.write(`  Message: ${network.message}\n`);
    }
    for (const check of network.checks) {
      const marker = check.status === "pass" ? "pass" : check.status;
      const suffix = check.normalizedError
        ? ` - ${check.normalizedError.category}: ${check.normalizedError.message}`
        : ` - ${JSON.stringify(check.summary)}`;
      process.stdout.write(`  [${marker}] ${check.name} (${check.latencyMs} ms)${suffix}\n`);
    }
    process.stdout.write("\n");
  }

  process.stdout.write(`Overall: ${summary.status}\n`);
}

function host(value) {
  return new URL(value).host;
}

function redact(value) {
  let redacted = value;
  for (const network of Object.values(NETWORKS)) {
    for (const name of network.tokenNames) {
      const token = (process.env[name] || "").trim();
      if (token.length > 0) {
        redacted = redacted.split(token).join("[redacted]");
      }
    }
  }
  return redacted
    .replace(/(X-Token\s*[:=]\s*)[^\s,}]+/gi, "$1[redacted]")
    .replace(/(GORKH_RPCFAST_(DEVNET|MAINNET)_TOKEN\s*[:=]\s*)[^\s,}]+/gi, "$1[redacted]")
    .replace(/(RPCFAST_(DEVNET|MAINNET)_TOKEN\s*[:=]\s*)[^\s,}]+/gi, "$1[redacted]");
}

function assertSafeSummary(summary) {
  const text = JSON.stringify(summary);
  for (const network of Object.values(NETWORKS)) {
    for (const name of network.tokenNames) {
      const token = (process.env[name] || "").trim();
      if (token.length > 0 && text.includes(token)) {
        throw new Error("Unsafe smoke summary contains an RPC Fast token value.");
      }
    }
  }
  const lower = text.toLowerCase();
  const forbidden = [
    "privatekey",
    "secretkey",
    "seedphrase",
    "mnemonic",
    "walletjson",
    "signingseed",
    "serializedtransaction",
    "transactionpayload",
    "unsignedtransaction",
    "instructionpayload",
  ];
  const found = forbidden.find((term) => lower.includes(term));
  if (found) {
    throw new Error(`Unsafe smoke summary field detected: ${found}`);
  }
}

main().catch((error) => {
  const message = redact(error instanceof Error ? error.message : String(error));
  process.stdout.write(`${JSON.stringify({
    status: "failed",
    reason: message,
    timestamp: new Date().toISOString(),
  }, null, 2)}\n`);
  process.exit(1);
});
