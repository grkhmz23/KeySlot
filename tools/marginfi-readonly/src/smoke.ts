import { randomUUID } from "node:crypto";
import { handleCommand } from "./index.ts";
import type { MarginFiReadOnlyResponse, MarginFiReadOnlyStatus } from "./contracts.ts";

export const DEFAULT_PUBLIC_SMOKE_WALLET = "11111111111111111111111111111111";
export const DEFAULT_MAINNET_RPC_URL = "https://api.mainnet-beta.solana.com";

export type MarginFiSmokeOptions = {
  walletPublicAddress?: string;
  rpcUrl?: string;
  expectedStatus?: MarginFiReadOnlyStatus;
  network?: "mainnet-beta" | "devnet";
  requestId?: string;
};

export type MarginFiSmokeSummary = {
  status: "ok" | "failed";
  requestId: string;
  walletPublicAddress: string;
  expectedStatus?: MarginFiReadOnlyStatus;
  expectedStatusMatched?: boolean;
  healthStatus: MarginFiReadOnlyStatus;
  envStatus: MarginFiReadOnlyStatus;
  positionsStatus: MarginFiReadOnlyStatus;
  sdkVersion?: string;
  sdkImportOk?: boolean;
  programId: string;
  groupId?: string;
  rpcUrlStatus?: string;
  accountCount: number;
  suppliedPositionCount: number;
  borrowedPositionCount: number;
  suppliedValueUsd?: string;
  borrowedValueUsd?: string;
  netValueUsd?: string;
  reason?: string;
  timestamp: string;
};

export async function runMarginFiSmoke(options: MarginFiSmokeOptions = {}): Promise<MarginFiSmokeSummary> {
  const requestId = options.requestId ?? `marginfi-smoke-${randomUUID()}`;
  const network = options.network ?? "mainnet-beta";
  const walletPublicAddress =
    options.walletPublicAddress ??
    process.env.GORKH_MARGINFI_SMOKE_WALLET ??
    DEFAULT_PUBLIC_SMOKE_WALLET;
  const rpcUrl = options.rpcUrl ?? process.env.SOLANA_RPC_URL ?? DEFAULT_MAINNET_RPC_URL;

  const health = await handleCommand("health", { requestId, network });
  const env = await handleCommand("env-check", { requestId, network, rpcUrl });
  const positions = await handleCommand("positions", {
    requestId,
    network,
    walletPublicAddress,
    rpcUrl,
  });

  return buildSmokeSummary({
    requestId,
    walletPublicAddress,
    expectedStatus: options.expectedStatus,
    health,
    env,
    positions,
  });
}

export function buildSmokeSummary(input: {
  requestId: string;
  walletPublicAddress: string;
  expectedStatus?: MarginFiReadOnlyStatus;
  health: MarginFiReadOnlyResponse;
  env: MarginFiReadOnlyResponse;
  positions: MarginFiReadOnlyResponse;
}): MarginFiSmokeSummary {
  const valueSummary = summarizeValues(input.positions);
  const expectedStatusMatched = input.expectedStatus === undefined
    ? undefined
    : input.positions.status === input.expectedStatus;
  const positionsSafeStatus = ["loaded", "empty", "partial", "unavailable"].includes(input.positions.status);
  const status =
    input.health.status === "ok" &&
    input.env.status === "ok" &&
    positionsSafeStatus &&
    expectedStatusMatched !== false
      ? "ok"
      : "failed";

  const summary: MarginFiSmokeSummary = {
    status,
    requestId: input.requestId,
    walletPublicAddress: input.walletPublicAddress,
    expectedStatus: input.expectedStatus,
    expectedStatusMatched,
    healthStatus: input.health.status,
    envStatus: input.env.status,
    positionsStatus: input.positions.status,
    sdkVersion: input.health.sdkValidation?.sdkVersion ?? input.positions.sdkValidation?.sdkVersion,
    sdkImportOk: input.health.sdkValidation?.sdkImportOk ?? input.positions.sdkValidation?.sdkImportOk,
    programId: input.positions.programId || input.health.programId,
    groupId: input.positions.groupId ?? input.positions.sdkValidation?.groupId ?? input.health.sdkValidation?.groupId,
    rpcUrlStatus: input.env.environmentValidation?.rpcUrlStatus,
    accountCount: input.positions.accountCount ?? 0,
    suppliedPositionCount: input.positions.suppliedPositionCount ?? 0,
    borrowedPositionCount: input.positions.borrowedPositionCount ?? 0,
    suppliedValueUsd: valueSummary.suppliedValueUsd,
    borrowedValueUsd: valueSummary.borrowedValueUsd,
    netValueUsd: valueSummary.netValueUsd,
    reason: input.positions.status === "loaded" || input.positions.status === "empty"
      ? undefined
      : input.positions.message,
    timestamp: new Date().toISOString(),
  };

  assertSmokeSummaryIsSafe(summary);
  return summary;
}

export function assertSmokeSummaryIsSafe(summary: MarginFiSmokeSummary): void {
  const text = JSON.stringify(summary).toLowerCase();
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
  const found = forbidden.find((token) => text.includes(token));
  if (found) {
    throw new Error(`Unsafe smoke summary field detected: ${found}`);
  }
}

function summarizeValues(response: MarginFiReadOnlyResponse): {
  suppliedValueUsd?: string;
  borrowedValueUsd?: string;
  netValueUsd?: string;
} {
  const positions = response.positions ?? [];
  const supplied = sumDecimalStrings(positions.map((position) => position.suppliedValueUsd));
  const borrowed = sumDecimalStrings(positions.map((position) => position.borrowedValueUsd));
  const net = sumDecimalStrings(positions.map((position) => position.netValueUsd));
  return {
    suppliedValueUsd: supplied,
    borrowedValueUsd: borrowed,
    netValueUsd: net,
  };
}

function sumDecimalStrings(values: Array<string | undefined>): string | undefined {
  let total = 0;
  let hasValue = false;
  for (const value of values) {
    if (value === undefined) {
      continue;
    }
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) {
      continue;
    }
    total += parsed;
    hasValue = true;
  }
  return hasValue ? String(total) : undefined;
}

function parseArgs(argv: string[]): MarginFiSmokeOptions {
  const options: MarginFiSmokeOptions = {};
  const positional: string[] = [];

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    switch (arg) {
      case "--wallet":
        options.walletPublicAddress = argv[++index];
        break;
      case "--rpc":
        options.rpcUrl = argv[++index];
        break;
      case "--expected":
        options.expectedStatus = argv[++index] as MarginFiReadOnlyStatus;
        break;
      case "--network":
        options.network = argv[++index] as "mainnet-beta" | "devnet";
        break;
      case "--help":
        printHelpAndExit();
        break;
      default:
        positional.push(arg);
    }
  }

  if (!options.walletPublicAddress && positional[0]) {
    options.walletPublicAddress = positional[0];
  }
  return options;
}

function printHelpAndExit(): never {
  process.stdout.write([
    "MarginFi read-only smoke",
    "Usage: node src/smoke.ts [--wallet <public-address>] [--rpc <url>] [--expected <loaded|empty|partial|unavailable>]",
    "Environment: GORKH_MARGINFI_SMOKE_WALLET may provide a public wallet address.",
    "Output is a redacted safe JSON summary only.",
    "",
  ].join("\n"));
  process.exit(0);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  runMarginFiSmoke(parseArgs(process.argv.slice(2)))
    .then((summary) => {
      process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
      process.exit(summary.status === "ok" ? 0 : 1);
    })
    .catch((error) => {
      const message = error instanceof Error ? error.message : "MarginFi smoke failed.";
      process.stdout.write(JSON.stringify({
        status: "failed",
        reason: message,
        timestamp: new Date().toISOString(),
      }, null, 2));
      process.stdout.write("\n");
      process.exit(1);
    });
}
