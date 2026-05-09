import { randomUUID } from "node:crypto";
import { handleCommand } from "./index.ts";
import type { MeteoraReadOnlyResponse, MeteoraReadOnlyStatus } from "./contracts.ts";

export const DEFAULT_PUBLIC_SMOKE_WALLET = "11111111111111111111111111111111";
export const DEFAULT_MAINNET_RPC_URL = "https://api.mainnet-beta.solana.com";

export type MeteoraSmokeOptions = {
  walletPublicAddress?: string;
  rpcUrl?: string;
  expectedStatus?: MeteoraReadOnlyStatus;
  network?: "mainnet-beta" | "devnet";
  requestId?: string;
};

export type MeteoraSmokeSummary = {
  status: "ok" | "failed";
  requestId: string;
  walletPublicAddress: string;
  expectedStatus?: MeteoraReadOnlyStatus;
  expectedStatusMatched?: boolean;
  healthStatus: MeteoraReadOnlyStatus;
  envStatus: MeteoraReadOnlyStatus;
  positionsStatus: MeteoraReadOnlyStatus;
  sdkVersion?: string;
  sdkImportOk?: boolean;
  readOnlyMethodAvailable?: boolean;
  rpcUrlStatus?: string;
  positionCount: number;
  reason?: string;
  timestamp: string;
};

export async function runMeteoraSmoke(options: MeteoraSmokeOptions = {}): Promise<MeteoraSmokeSummary> {
  const requestId = options.requestId ?? `meteora-smoke-${randomUUID()}`;
  const network = options.network ?? "mainnet-beta";
  const walletPublicAddress =
    options.walletPublicAddress ??
    process.env.GORKH_METEORA_SMOKE_WALLET ??
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
  expectedStatus?: MeteoraReadOnlyStatus;
  health: MeteoraReadOnlyResponse;
  env: MeteoraReadOnlyResponse;
  positions: MeteoraReadOnlyResponse;
}): MeteoraSmokeSummary {
  const expectedStatusMatched = input.expectedStatus === undefined
    ? undefined
    : input.positions.status === input.expectedStatus;
  const positionsSafeStatus = ["loaded", "empty", "partial", "unavailable"].includes(input.positions.status);
  const status =
    input.health.status === "loaded" &&
    input.env.status === "loaded" &&
    positionsSafeStatus &&
    expectedStatusMatched !== false
      ? "ok"
      : "failed";

  const summary: MeteoraSmokeSummary = {
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
    readOnlyMethodAvailable: input.health.sdkValidation?.readOnlyMethodAvailable ?? input.positions.sdkValidation?.readOnlyMethodAvailable,
    rpcUrlStatus: input.env.environmentValidation?.rpcUrlStatus,
    positionCount: input.positions.positionCount ?? 0,
    reason: input.positions.status === "loaded" || input.positions.status === "empty"
      ? undefined
      : input.positions.message,
    timestamp: new Date().toISOString(),
  };

  assertSmokeSummaryIsSafe(summary);
  return summary;
}

export function assertSmokeSummaryIsSafe(summary: MeteoraSmokeSummary): void {
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

function parseArgs(argv: string[]): MeteoraSmokeOptions {
  const options: MeteoraSmokeOptions = {};
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
        options.expectedStatus = argv[++index] as MeteoraReadOnlyStatus;
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
    "Meteora read-only smoke",
    "Usage: node src/smoke.ts [--wallet <public-address>] [--rpc <url>] [--expected <loaded|empty|partial|unavailable>]",
    "Environment: GORKH_METEORA_SMOKE_WALLET may provide a public wallet address.",
    "Output is a redacted safe JSON summary only.",
    "",
  ].join("\n"));
  process.exit(0);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  runMeteoraSmoke(parseArgs(process.argv.slice(2)))
    .then((summary) => {
      process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
      process.exit(summary.status === "ok" ? 0 : 1);
    })
    .catch((error) => {
      const message = error instanceof Error ? error.message : "Meteora smoke failed.";
      process.stdout.write(JSON.stringify({
        status: "failed",
        reason: message,
        timestamp: new Date().toISOString(),
      }, null, 2));
      process.stdout.write("\n");
      process.exit(1);
    });
}
