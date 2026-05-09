import { createHash, randomUUID } from "node:crypto";

export const CLOAK_PROGRAM_ID = "zh1eLd6rSphLejbFfJEneUwzHRfMKxgzrgkfwA6qRkW";
export const NATIVE_SOL_MINT = "So11111111111111111111111111111111111111112";
export const MINIMUM_DEPOSIT_LAMPORTS = 10_000_000n;
export const FIXED_FEE_LAMPORTS = 5_000_000n;
export const VARIABLE_FEE_NUMERATOR = 3n;
export const VARIABLE_FEE_DENOMINATOR = 1_000n;

export type CloakBridgeCommand =
  | "health"
  | "env-check"
  | "deposit-plan"
  | "execute-deposit"
  | "full-withdraw"
  | "partial-withdraw"
  | "private-transfer"
  | "swap"
  | "scan"
  | "compliance-export";

export type CloakActionKind =
  | "deposit"
  | "private_transfer"
  | "full_withdraw"
  | "partial_withdraw"
  | "scan";

export type CloakBridgeStatus =
  | "ok"
  | "locked"
  | "unavailable"
  | "rejected"
  | "error";

export type CloakBridgeErrorCategory =
  | "none"
  | "locked-in-phase-2-3"
  | "forbidden-field"
  | "invalid-request"
  | "unsupported-command"
  | "helper-unavailable";

export type CloakSignerRequestKind =
  | "sign_transaction_preview"
  | "sign_message_preview"
  | "future_sign_transaction_locked"
  | "future_sign_message_locked";

export type CloakSignerBridgeState = "locked" | "unavailable" | "rejected";

export type CloakSignerRequestSummary = {
  id: string;
  requestKind: CloakSignerRequestKind;
  walletPublicKey: string;
  network: "mainnet-beta" | "devnet";
  actionKind: CloakActionKind;
  amountLamports?: string;
  mintAddress: string;
  programId: string;
  feeQuote?: CloakFeeQuote;
  humanReadableSummary: string;
  expectedTransactionPurpose?: string;
  expectedMessagePurpose?: string;
  draftFingerprint: string;
  approvalState: "locked";
  bridgeState: CloakSignerBridgeState;
  timestamp: string;
};

export type CloakFeeQuote = {
  grossLamports: string;
  fixedFeeLamports: string;
  variableFeeLamports: string;
  totalFeeLamports: string;
  netLamports: string;
  minimumDepositLamports: string;
};

export type CloakSdkValidation = {
  sdkInstalled: boolean;
  sdkImportOk: boolean;
  sdkVersion?: string;
  cloakProgramId?: string;
  expectedProgramId: string;
  programIdMatches: boolean;
  nativeSolMint?: string;
  feeHelpersAvailable: boolean;
};

export type CloakFeeValidationSample = {
  grossLamports: string;
  gorkhFeeLamports: string;
  gorkhNetLamports: string;
  sdkFeeLamports?: string;
  sdkNetLamports?: string;
  matches?: boolean;
};

export type CloakFeeValidation = {
  available: boolean;
  source: "sdk" | "gorkh-local" | "unavailable";
  samples: CloakFeeValidationSample[];
  message: string;
};

export type CloakEnvironmentValidation = {
  solanaRpcUrlStatus: "missing" | "present-redacted";
  rpcUrlRedacted?: string;
  rpcProvider?: "rpcfast" | "fallback" | "missing";
  rpcHost?: string;
  rpcFastTokenStatus?: "present" | "missing";
  rpcMessage?: string;
  requestedNetwork?: "mainnet-beta" | "devnet";
  networkSupportedForFutureExecution: boolean;
  helperMode: "dry-run-non-executing";
  executionCommandsLocked: boolean;
  keypairPathRequired: false;
  walletSecretEnvAccepted: false;
  suspiciousEnvVarNames: string[];
};

export type CloakBridgeRequest = {
  requestId?: string;
  command: CloakBridgeCommand;
  actionKind?: CloakActionKind;
  network?: "mainnet-beta" | "devnet";
  walletPublicAddress?: string;
  amountLamports?: string | number;
  mintAddress?: string;
  programId?: string;
  feeQuote?: CloakFeeQuote;
  scanStateBase64?: string;
  scanLimit?: number;
  untilSignature?: string;
  timestamp?: string;
};

export type CloakScanStatus =
  | "loaded"
  | "empty"
  | "partial"
  | "unavailable"
  | "error";

export type CloakScanTransactionSummary = {
  signature?: string;
  txType?: string;
  amountLamports: string;
  feeLamports: string;
  netAmountLamports: string;
  runningBalanceLamports?: string;
  timestampMillis?: string;
  recipient?: string;
  commitmentPrefix?: string;
  mintAddress?: string;
  symbol?: string;
  status: "scanned";
};

export type CloakComplianceSummary = {
  transactionCount: number;
  totalDepositsLamports: string;
  totalWithdrawalsLamports: string;
  totalFeesLamports: string;
  netChangeLamports: string;
  finalBalanceLamports: string;
  mintBreakdown: { mintAddress: string; symbol?: string; netLamports: string }[];
  dateRangeStart?: string;
  dateRangeEnd?: string;
  generatedAt: string;
};

export type CloakScanSummary = {
  status: CloakScanStatus;
  transactions: CloakScanTransactionSummary[];
  totalDepositsLamports: string;
  totalWithdrawalsLamports: string;
  totalFeesLamports: string;
  netChangeLamports: string;
  finalBalanceLamports: string;
  transactionCount: number;
  scannedAt: string;
  lastSignature?: string;
  errorMessage?: string;
  rpcProvider?: "rpcfast" | "fallback" | "missing";
  rpcHost?: string;
  complianceSummary?: CloakComplianceSummary;
};

export type CloakBridgeResponse = {
  id: string;
  requestId?: string;
  command: CloakBridgeCommand;
  actionKind?: CloakActionKind;
  status: CloakBridgeStatus;
  errorCategory: CloakBridgeErrorCategory;
  message: string;
  programId: string;
  feeQuote?: CloakFeeQuote;
  sdkValidation?: CloakSdkValidation;
  feeValidation?: CloakFeeValidation;
  environmentValidation?: CloakEnvironmentValidation;
  scanSummary?: CloakScanSummary;
  complianceSummary?: CloakComplianceSummary;
  signerRequestSummary?: CloakSignerRequestSummary;
  nextRequiredGates?: string[];
  txSignature?: string;
  commitmentPrefix?: string;
  timestamp: string;
};

export const ALLOWED_COMMANDS: CloakBridgeCommand[] = [
  "health",
  "env-check",
  "deposit-plan",
  "scan",
];

export const EXECUTION_COMMANDS: CloakBridgeCommand[] = [
  "execute-deposit",
  "full-withdraw",
];

export type CloakSigningRequestKind = "sign_transaction" | "sign_message";

export type CloakSigningRequestFrame = {
  type: "sign-request";
  id: string;
  requestId?: string;
  signingKind: CloakSigningRequestKind;
  walletPublicKey: string;
  network: "mainnet-beta";
  actionKind: "deposit" | "full_withdraw";
  amountLamports: string;
  mintAddress: string;
  programId: string;
  draftFingerprint: string;
  purpose: string;
  payloadBase64: string;
  timestamp: string;
  expiresAt: string;
};

export type CloakSigningResponseFrame = {
  type: "sign-response";
  id: string;
  signedPayloadBase64: string;
};

export type CloakExecutionResultFrame = {
  type: "result";
  response: CloakBridgeResponse;
  secureOutputStateBase64?: string;
  secureViewingStateBase64?: string;
  secureSpentStateBase64?: string;
  leafIndex?: number;
};

export type CloakExecutionRequest = CloakBridgeRequest & {
  approvedDraftFingerprint?: string;
  recipientAddress?: string;
  rpcUrl?: string;
  relayUrl?: string;
  spendStateBase64?: string;
};

export function calculateFeeQuote(amountLamports: string | number): CloakFeeQuote {
  const gross = parseLamports(amountLamports);
  if (gross < MINIMUM_DEPOSIT_LAMPORTS) {
    throw new Error(`minimum deposit is ${MINIMUM_DEPOSIT_LAMPORTS.toString()} lamports`);
  }

  const variableFee = (gross * VARIABLE_FEE_NUMERATOR) / VARIABLE_FEE_DENOMINATOR;
  const totalFee = FIXED_FEE_LAMPORTS + variableFee;
  if (gross <= totalFee) {
    throw new Error("gross amount must exceed Cloak fee");
  }

  return {
    grossLamports: gross.toString(),
    fixedFeeLamports: FIXED_FEE_LAMPORTS.toString(),
    variableFeeLamports: variableFee.toString(),
    totalFeeLamports: totalFee.toString(),
    netLamports: (gross - totalFee).toString(),
    minimumDepositLamports: MINIMUM_DEPOSIT_LAMPORTS.toString(),
  };
}

export const NEXT_EXECUTION_GATES = [
  "native signer bridge",
  "wallet unlock",
  "LocalAuthentication",
  "Shield review",
  "explicit approval",
  "audit log",
  "tiny mainnet smoke",
] as const;

export function buildDepositSignerRequestSummary(
  request: CloakBridgeRequest,
  feeQuote: CloakFeeQuote,
): CloakSignerRequestSummary {
  const walletPublicKey = request.walletPublicAddress ?? "";
  const network = request.network ?? "mainnet-beta";
  const amountLamports = feeQuote.grossLamports;
  const mintAddress = request.mintAddress ?? NATIVE_SOL_MINT;
  const draftFingerprint = signerDraftFingerprint({
    walletPublicKey,
    network,
    actionKind: "deposit",
    amountLamports,
    mintAddress,
    programId: CLOAK_PROGRAM_ID,
    feeQuote,
  });

  return {
    id: randomUUID(),
    requestKind: "sign_transaction_preview",
    walletPublicKey,
    network,
    actionKind: "deposit",
    amountLamports,
    mintAddress,
    programId: CLOAK_PROGRAM_ID,
    feeQuote,
    humanReadableSummary: `Future Cloak SOL deposit review for ${amountLamports} lamports.`,
    expectedTransactionPurpose: "Create a reviewed Cloak public deposit into a shielded balance.",
    expectedMessagePurpose: "Future viewing-key registration may require a separately reviewed message signature.",
    draftFingerprint,
    approvalState: "locked",
    bridgeState: "locked",
    timestamp: new Date().toISOString(),
  };
}

function signerDraftFingerprint(input: {
  walletPublicKey: string;
  network: "mainnet-beta" | "devnet";
  actionKind: CloakActionKind;
  amountLamports: string;
  mintAddress: string;
  programId: string;
  feeQuote: CloakFeeQuote;
}): string {
  const source = [
    input.walletPublicKey,
    input.network,
    input.actionKind,
    input.amountLamports,
    input.mintAddress,
    input.programId,
    `${input.feeQuote.grossLamports}:${input.feeQuote.totalFeeLamports}:${input.feeQuote.netLamports}`,
  ].join("|");
  return createHash("sha256").update(source).digest("hex");
}

export function parseLamports(value: string | number): bigint {
  if (typeof value === "number") {
    if (!Number.isSafeInteger(value) || value < 0) {
      throw new Error("amountLamports must be a safe unsigned integer");
    }
    return BigInt(value);
  }

  if (!/^[0-9]+$/.test(value)) {
    throw new Error("amountLamports must be a base-10 integer string");
  }
  return BigInt(value);
}
