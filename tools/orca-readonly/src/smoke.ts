import { randomUUID } from "node:crypto";
import { handleCommand } from "./index.ts";
import { hasForbiddenField } from "./redaction.ts";
import type { OrcaReadOnlyResponse, OrcaReadOnlyStatus } from "./contracts.ts";

export const DEFAULT_PUBLIC_SMOKE_WALLET = "11111111111111111111111111111111";

type SmokeOptions = {
  requestId: string;
  walletPublicAddress: string;
  expectedStatus?: OrcaReadOnlyStatus;
  health: OrcaReadOnlyResponse;
  env: OrcaReadOnlyResponse;
  positions: OrcaReadOnlyResponse;
};

type SmokeSummary = {
  status: "ok" | "failed";
  requestId: string;
  walletPublicAddress: string;
  expectedStatus?: OrcaReadOnlyStatus;
  expectedStatusMatched?: boolean;
  sdkVersion?: string;
  kitVersion?: string;
  healthStatus: OrcaReadOnlyStatus;
  envStatus: OrcaReadOnlyStatus;
  positionsStatus: OrcaReadOnlyStatus;
  positionCount: number;
  reason?: string;
  timestamp: string;
};

export function buildSmokeSummary(options: SmokeOptions): SmokeSummary {
  const positionCount = options.positions.positionCount ?? options.positions.positions?.length ?? 0;
  const expectedStatusMatched = options.expectedStatus === undefined
    ? undefined
    : options.positions.status === options.expectedStatus;
  const ok = options.positions.status !== "rejected"
    && options.positions.status !== "error"
    && expectedStatusMatched !== false;
  const summary: SmokeSummary = {
    status: ok ? "ok" : "failed",
    requestId: options.requestId,
    walletPublicAddress: options.walletPublicAddress,
    expectedStatus: options.expectedStatus,
    expectedStatusMatched,
    sdkVersion: options.health.sdkValidation?.sdkVersion,
    kitVersion: options.health.sdkValidation?.kitVersion,
    healthStatus: options.health.status,
    envStatus: options.env.status,
    positionsStatus: options.positions.status,
    positionCount,
    reason: options.positions.message,
    timestamp: new Date().toISOString(),
  };
  assertSmokeSummaryIsSafe(summary);
  return summary;
}

export function assertSmokeSummaryIsSafe(summary: SmokeSummary): void {
  const json = JSON.stringify(summary);
  const forbidden = [
    "privateKey",
    "secretKey",
    "seedPhrase",
    "mnemonic",
    "walletJson",
    "signingSeed",
    "transactionPayload",
    "serializedTransaction",
    "unsignedTransaction",
    "instructionPayload",
  ];
  for (const key of forbidden) {
    if (json.toLowerCase().includes(key.toLowerCase()) || hasForbiddenField(key)) {
      if (json.toLowerCase().includes(key.toLowerCase())) {
        throw new Error(`Unsafe smoke summary contains ${key}`);
      }
    }
  }
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const expectedIndex = args.indexOf("--expect");
  const walletArgIndex = args.indexOf("--wallet");
  const rpcArgIndex = args.indexOf("--rpc-url");
  const requestId = randomUUID();
  const walletPublicAddress =
    walletArgIndex >= 0 && args[walletArgIndex + 1]
      ? args[walletArgIndex + 1]
      : process.env.GORKH_ORCA_SMOKE_WALLET ?? DEFAULT_PUBLIC_SMOKE_WALLET;
  const expectedStatus = expectedIndex >= 0 ? args[expectedIndex + 1] as OrcaReadOnlyStatus | undefined : undefined;
  const rpcUrl = rpcArgIndex >= 0 && args[rpcArgIndex + 1] ? args[rpcArgIndex + 1] : process.env.SOLANA_RPC_URL;
  const request = {
    requestId,
    network: "mainnet-beta" as const,
    walletPublicAddress,
    rpcUrl,
  };

  const health = await handleCommand("health", request);
  const env = await handleCommand("env-check", request);
  const positions = await handleCommand("positions", request);
  const summary = buildSmokeSummary({
    requestId,
    walletPublicAddress,
    expectedStatus,
    health,
    env,
    positions,
  });

  process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
  process.exit(summary.status === "ok" ? 0 : 1);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    process.stderr.write(error instanceof Error ? error.message : "Orca smoke failed.");
    process.exit(1);
  });
}
