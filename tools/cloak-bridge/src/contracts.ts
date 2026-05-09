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
  | "private-transfer"
  | "full-withdraw"
  | "partial-withdraw"
  | "scan";

export type CloakBridgeStatus =
  | "ok"
  | "locked"
  | "unavailable"
  | "rejected"
  | "error";

export type CloakBridgeErrorCategory =
  | "none"
  | "locked-in-phase-2-2"
  | "forbidden-field"
  | "invalid-request"
  | "unsupported-command";

export type CloakFeeQuote = {
  grossLamports: string;
  fixedFeeLamports: string;
  variableFeeLamports: string;
  totalFeeLamports: string;
  netLamports: string;
  minimumDepositLamports: string;
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
  timestamp?: string;
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
  txSignature?: string;
  commitmentPrefix?: string;
  timestamp: string;
};

export const ALLOWED_COMMANDS: CloakBridgeCommand[] = [
  "health",
  "env-check",
  "deposit-plan",
];

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
