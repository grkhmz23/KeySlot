import { randomUUID } from "node:crypto";

export type OrcaReadOnlyCommand = "health" | "env-check" | "positions" | "harvest-plan";

export type OrcaReadOnlyStatus =
  | "loaded"
  | "empty"
  | "partial"
  | "unavailable"
  | "error"
  | "rejected";

export type OrcaReadOnlyErrorCategory =
  | "none"
  | "forbidden-field"
  | "invalid-request"
  | "unsupported-network"
  | "sdk-unavailable"
  | "rpc-unavailable"
  | "read-only-guard"
  | "harvest-unavailable";

export type OrcaReadOnlyRequest = {
  requestId?: string;
  command?: OrcaReadOnlyCommand;
  walletPublicAddress?: string;
  positionMint?: string;
  positionAddress?: string;
  network?: "mainnet-beta" | "devnet";
  rpcUrl?: string;
  timestamp?: string;
};

export type OrcaSdkValidation = {
  sdkInstalled: boolean;
  sdkImportOk: boolean;
  sdkVersion?: string;
  kitInstalled: boolean;
  kitImportOk: boolean;
  kitVersion?: string;
  readOnlyMethodAvailable: boolean;
  harvestInstructionMethodAvailable?: boolean;
  whirlpoolProgramId?: string;
  mainnetWhirlpoolConfig?: string;
  devnetWhirlpoolConfig?: string;
  publicApiBaseUrl?: string;
};

export type OrcaEnvironmentValidation = {
  network?: "mainnet-beta" | "devnet";
  networkSupported: boolean;
  rpcUrlStatus: "missing" | "present-redacted";
  rpcUrlRedacted?: string;
  rpcProvider?: "rpcfast" | "custom" | "missing";
  tokenStatus?: "present" | "missing" | "not-required";
  walletSecretEnvAccepted: false;
  suspiciousEnvVarNames: string[];
};

export type OrcaReadOnlyPosition = {
  walletPublicAddress: string;
  poolAddress: string;
  positionAddress: string;
  positionMint?: string;
  tokenAMint?: string;
  tokenBMint?: string;
  tokenAAmountUi?: string;
  tokenBAmountUi?: string;
  tokenAFeesUi?: string;
  tokenBFeesUi?: string;
  tickLowerIndex?: number;
  tickUpperIndex?: number;
  tickCurrentIndex?: number;
  rangeState: "in_range" | "out_of_range" | "unknown";
  estimatedValueUsd?: string;
  status: "loaded" | "partial";
  metadataStatus?: string;
};

export type OrcaHarvestInstructionAccount = {
  address: string;
  isSigner: boolean;
  isWritable: boolean;
};

export type OrcaHarvestInstruction = {
  programId: string;
  accounts: OrcaHarvestInstructionAccount[];
  dataBase64: string;
};

export type OrcaHarvestTokenAmount = {
  mintAddress?: string;
  amountRaw: string;
  amountUi?: string;
};

export type OrcaHarvestPlan = {
  walletPublicAddress: string;
  positionMint: string;
  positionAddress?: string;
  poolAddress?: string;
  tokenAMint?: string;
  tokenBMint?: string;
  feeOwedA?: OrcaHarvestTokenAmount;
  feeOwedB?: OrcaHarvestTokenAmount;
  rewardOwed?: OrcaHarvestTokenAmount[];
  instructionCount: number;
  writableAccountCount: number;
  signerAccounts: string[];
  programIds: string[];
  instructions: OrcaHarvestInstruction[];
  source: "official-orca-sdk-harvest-instructions";
  expiresAt: string;
  warning?: string;
};

export type OrcaReadOnlyResponse = {
  id: string;
  requestId?: string;
  command: OrcaReadOnlyCommand;
  status: OrcaReadOnlyStatus;
  errorCategory: OrcaReadOnlyErrorCategory;
  message: string;
  sdkValidation?: OrcaSdkValidation;
  environmentValidation?: OrcaEnvironmentValidation;
  positions?: OrcaReadOnlyPosition[];
  harvestPlan?: OrcaHarvestPlan;
  positionCount?: number;
  timestamp: string;
};

export const ALLOWED_COMMANDS: OrcaReadOnlyCommand[] = ["health", "env-check", "positions", "harvest-plan"];

export const ORCA_WHIRLPOOL_PROGRAM_ID = "whirLbMiicVdio4qvUfM5KAg6Ct8VwpYzGff3uctyCc";
export const ORCA_MAINNET_WHIRLPOOL_CONFIG = "2LecshUwdy9xi7meFgHtFJQNSKk4KdTrcpvaB56dP2NQ";
export const ORCA_DEVNET_WHIRLPOOL_CONFIG = "FcrweFY1G9HJAHG5inkGB6pKg1HZ6x9UC2WioAfWrGkR";
export const ORCA_PUBLIC_API_BASE_URL = "https://api.orca.so/v2/solana";

export function response(
  command: OrcaReadOnlyCommand,
  fields: Partial<OrcaReadOnlyResponse>,
): OrcaReadOnlyResponse {
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
    harvestPlan: fields.harvestPlan,
    positionCount: fields.positionCount,
    timestamp: new Date().toISOString(),
  };
}
