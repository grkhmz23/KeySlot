import { randomUUID } from "node:crypto";

export const MARGINFI_PROGRAM_ID = "MFv2hWf31Z9kbCa1snEPYctwafyhdvnV7FZnsebVacA";
export const SDK_MAIN_GROUP_ID = "4qp6Fx6tnZkY5Wropq9wUYgtFxXKwE6viZxFHg3rdAG8";
export const REVIEWED_GROUP_CANDIDATE = "4qp6Fx6tnZkY5Wropq9wUYgtFxXKwE6viZxFHg3rdAG4";

export type MarginFiReadOnlyCommand = "health" | "env-check" | "positions";

export type MarginFiReadOnlyStatus =
  | "ok"
  | "loaded"
  | "empty"
  | "partial"
  | "unavailable"
  | "error"
  | "rejected";

export type MarginFiReadOnlyErrorCategory =
  | "none"
  | "forbidden-field"
  | "invalid-request"
  | "unsupported-network"
  | "sdk-unavailable"
  | "rpc-unavailable"
  | "read-only-guard";

export type MarginFiReadOnlyRequest = {
  requestId?: string;
  command: MarginFiReadOnlyCommand;
  walletPublicAddress?: string;
  network?: "mainnet-beta" | "devnet";
  rpcUrl?: string;
  timestamp?: string;
};

export type MarginFiSdkValidation = {
  sdkInstalled: boolean;
  sdkImportOk: boolean;
  sdkVersion?: string;
  programId: string;
  expectedProgramId: string;
  programIdMatches: boolean;
  groupId?: string;
  groupIdSource: "sdk-config" | "local-candidate" | "unavailable";
  readOnlyWallet: true;
};

export type MarginFiEnvironmentValidation = {
  network?: "mainnet-beta" | "devnet";
  networkSupported: boolean;
  rpcUrlStatus: "missing" | "present-redacted";
  rpcUrlRedacted?: string;
  walletSecretEnvAccepted: false;
  suspiciousEnvVarNames: string[];
};

export type MarginFiReadOnlyAsset = {
  side: "supplied" | "borrowed";
  bankAddress?: string;
  mintAddress?: string;
  symbol?: string;
  quantityUi?: string;
  usdValue?: string;
};

export type MarginFiReadOnlyPosition = {
  walletPublicAddress: string;
  accountAddress: string;
  groupAddress?: string;
  suppliedAssets: MarginFiReadOnlyAsset[];
  borrowedAssets: MarginFiReadOnlyAsset[];
  suppliedPositionCount: number;
  borrowedPositionCount: number;
  suppliedValueUsd?: string;
  borrowedValueUsd?: string;
  netValueUsd?: string;
  healthFactor?: string;
  ltv?: string;
  riskLevel: "healthy" | "caution" | "high_risk" | "liquidation_risk" | "unavailable";
  status: "loaded" | "partial";
  metadataStatus?: string;
};

export type MarginFiReadOnlyResponse = {
  id: string;
  requestId?: string;
  command: MarginFiReadOnlyCommand;
  status: MarginFiReadOnlyStatus;
  errorCategory: MarginFiReadOnlyErrorCategory;
  message: string;
  programId: string;
  groupId?: string;
  sdkValidation?: MarginFiSdkValidation;
  environmentValidation?: MarginFiEnvironmentValidation;
  positions?: MarginFiReadOnlyPosition[];
  accountCount?: number;
  suppliedPositionCount?: number;
  borrowedPositionCount?: number;
  timestamp: string;
};

export const ALLOWED_COMMANDS: MarginFiReadOnlyCommand[] = ["health", "env-check", "positions"];

export function response(
  command: MarginFiReadOnlyCommand,
  fields: Partial<MarginFiReadOnlyResponse>,
): MarginFiReadOnlyResponse {
  return {
    id: randomUUID(),
    requestId: fields.requestId,
    command,
    status: fields.status ?? "unavailable",
    errorCategory: fields.errorCategory ?? "none",
    message: fields.message ?? "",
    programId: MARGINFI_PROGRAM_ID,
    groupId: fields.groupId,
    sdkValidation: fields.sdkValidation,
    environmentValidation: fields.environmentValidation,
    positions: fields.positions,
    accountCount: fields.accountCount,
    suppliedPositionCount: fields.suppliedPositionCount,
    borrowedPositionCount: fields.borrowedPositionCount,
    timestamp: new Date().toISOString(),
  };
}
