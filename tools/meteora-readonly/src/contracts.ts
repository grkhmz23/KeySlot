import { randomUUID } from "node:crypto";

export type MeteoraReadOnlyCommand = "health" | "env-check" | "positions";

export type MeteoraReadOnlyStatus =
  | "loaded"
  | "empty"
  | "partial"
  | "unavailable"
  | "error"
  | "rejected";

export type MeteoraReadOnlyErrorCategory =
  | "none"
  | "forbidden-field"
  | "invalid-request"
  | "unsupported-network"
  | "sdk-unavailable"
  | "rpc-unavailable"
  | "read-only-guard";

export type MeteoraReadOnlyRequest = {
  requestId?: string;
  command?: MeteoraReadOnlyCommand;
  walletPublicAddress?: string;
  network?: "mainnet-beta" | "devnet";
  rpcUrl?: string;
  timestamp?: string;
};

export type MeteoraSdkValidation = {
  sdkInstalled: boolean;
  sdkImportOk: boolean;
  sdkVersion?: string;
  readOnlyMethodAvailable: boolean;
};

export type MeteoraEnvironmentValidation = {
  network?: "mainnet-beta" | "devnet";
  networkSupported: boolean;
  rpcUrlStatus: "missing" | "present-redacted";
  rpcUrlRedacted?: string;
  walletSecretEnvAccepted: false;
  suspiciousEnvVarNames: string[];
};

export type MeteoraReadOnlyPosition = {
  walletPublicAddress: string;
  poolAddress: string;
  positionAddress: string;
  tokenAMint?: string;
  tokenBMint?: string;
  tokenAAmountUi?: string;
  tokenBAmountUi?: string;
  tokenAFeesUi?: string;
  tokenBFeesUi?: string;
  lowerBinId?: number;
  upperBinId?: number;
  currentBinId?: number;
  rangeState: "in_range" | "out_of_range" | "unknown";
  estimatedValueUsd?: string;
  status: "loaded" | "partial";
  metadataStatus?: string;
};

export type MeteoraReadOnlyResponse = {
  id: string;
  requestId?: string;
  command: MeteoraReadOnlyCommand;
  status: MeteoraReadOnlyStatus;
  errorCategory: MeteoraReadOnlyErrorCategory;
  message: string;
  sdkValidation?: MeteoraSdkValidation;
  environmentValidation?: MeteoraEnvironmentValidation;
  positions?: MeteoraReadOnlyPosition[];
  positionCount?: number;
  timestamp: string;
};

export const ALLOWED_COMMANDS: MeteoraReadOnlyCommand[] = ["health", "env-check", "positions"];

export function response(
  command: MeteoraReadOnlyCommand,
  fields: Partial<MeteoraReadOnlyResponse>,
): MeteoraReadOnlyResponse {
  return {
    id: randomUUID(),
    requestId: fields.requestId,
    command,
    status: fields.status ?? "unavailable",
    errorCategory: fields.errorCategory ?? "none",
    message: fields.message ?? "",
    sdkValidation: fields.sdkValidation,
    environmentValidation: fields.environmentValidation,
    positions: fields.positions,
    positionCount: fields.positionCount,
    timestamp: new Date().toISOString(),
  };
}
