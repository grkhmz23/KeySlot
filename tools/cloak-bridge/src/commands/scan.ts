import {
  CLOAK_PROGRAM_ID,
  NATIVE_SOL_MINT,
  type CloakBridgeRequest,
  type CloakBridgeResponse,
  type CloakComplianceSummary,
  type CloakScanSummary,
  type CloakScanTransactionSummary,
} from "../contracts.ts";
import { resolveCloakRPCConfiguration } from "../rpc.ts";
import { loadSdkValidation } from "../sdk.ts";
import { response } from "./response.ts";

type Web3Module = {
  Connection: new (endpoint: string, config?: unknown) => unknown;
};

type CloakScanRuntimeModule = {
  CLOAK_PROGRAM_ID: unknown;
  scanTransactions: (options: Record<string, unknown>) => Promise<CloakSDKScanResult>;
  toComplianceReport?: (result: CloakSDKScanResult) => unknown;
  parseError?: (error: unknown) => { message?: string; category?: string; recoverable?: boolean };
};

type CloakSDKScanResult = {
  transactions?: CloakSDKScannedTransaction[];
  summary?: CloakSDKScanTotals;
  rpcCallsMade?: number;
  lastSignature?: string;
};

type CloakSDKScanTotals = {
  totalDeposits?: unknown;
  totalWithdrawals?: unknown;
  totalFees?: unknown;
  netChange?: unknown;
  finalBalance?: unknown;
  transactionCount?: unknown;
};

type CloakSDKScannedTransaction = {
  signature?: unknown;
  txType?: unknown;
  amount?: unknown;
  fee?: unknown;
  netAmount?: unknown;
  runningBalance?: unknown;
  timestamp?: unknown;
  recipient?: unknown;
  commitment?: unknown;
  mint?: unknown;
  symbol?: unknown;
};

export async function scan(request: CloakBridgeRequest): Promise<CloakBridgeResponse> {
  if (request.network !== "mainnet-beta") {
    return rejected(request, "Cloak private scan is mainnet-beta only.");
  }
  if (request.programId && request.programId !== CLOAK_PROGRAM_ID) {
    return rejected(request, "programId mismatch");
  }
  const scanState = request.scanStateBase64;
  if (!scanState || scanState.trim().length === 0) {
    return rejected(request, "Cloak scan state is required and must come from the local vault.");
  }

  const scanStateBytes = Buffer.from(scanState, "base64");
  if (scanStateBytes.length === 0) {
    return rejected(request, "Cloak scan state is invalid.");
  }

  const limit = clampLimit(request.scanLimit);

  try {
    const sdk = await import("@cloak.dev/sdk") as CloakScanRuntimeModule;
    const web3 = await import("@solana/web3.js") as Web3Module;
    if (publicKeyString(sdk.CLOAK_PROGRAM_ID) !== CLOAK_PROGRAM_ID) {
      return rejected(request, "Cloak SDK program id does not match the GORKH allowlist.");
    }

    const rpc = resolveCloakRPCConfiguration(undefined);
    const connection = new web3.Connection(rpc.endpoint, { commitment: "confirmed", httpHeaders: rpc.httpHeaders });
    const result = await sdk.scanTransactions({
      connection,
      programId: sdk.CLOAK_PROGRAM_ID,
      viewingKeyNk: Uint8Array.from(scanStateBytes),
      limit,
      untilSignature: optionalString(request.untilSignature),
      walletPublicKey: optionalString(request.walletPublicAddress),
      onProgress: (_progress: unknown) => undefined,
      onStatus: (_status: unknown) => undefined,
    });

    const summary = normalizeScanResult(result, rpc.provider, rpc.host);
    const complianceSummary = safeComplianceSummary(summary, result, sdk.toComplianceReport);
    const mergedSummary = { ...summary, complianceSummary };
    return response("scan", {
      request,
      actionKind: "scan",
      status: "ok",
      errorCategory: "none",
      message: summary.transactionCount === 0
        ? "Cloak private scan completed with no chain activity for this local scan state."
        : "Cloak private scan completed. Safe summary returned to Swift.",
      sdkValidation: await loadSdkValidation(),
      scanSummary: mergedSummary,
      complianceSummary,
    });
  } catch (error) {
    const message = await safeErrorMessage(error);
    return response("scan", {
      request,
      actionKind: "scan",
      status: "error",
      errorCategory: "invalid-request",
      message,
      sdkValidation: await loadSdkValidation(),
      scanSummary: errorSummary(message),
    });
  } finally {
    scanStateBytes.fill(0);
  }
}

function normalizeScanResult(result: CloakSDKScanResult, rpcProvider: "rpcfast" | "fallback", rpcHost: string): CloakScanSummary {
  const transactions = (result.transactions ?? []).map(normalizeTransaction);
  const totals = result.summary ?? {};
  const transactionCount = numberValue(totals.transactionCount) ?? transactions.length;
  const lastSignature = stringValue(result.lastSignature) ?? transactions.at(-1)?.signature;
  return {
    status: transactionCount > 0 ? "loaded" : "empty",
    transactions,
    totalDepositsLamports: decimalString(totals.totalDeposits),
    totalWithdrawalsLamports: decimalString(totals.totalWithdrawals),
    totalFeesLamports: decimalString(totals.totalFees),
    netChangeLamports: decimalString(totals.netChange),
    finalBalanceLamports: decimalString(totals.finalBalance),
    transactionCount,
    scannedAt: new Date().toISOString(),
    lastSignature,
    rpcProvider,
    rpcHost,
  };
}

function normalizeTransaction(transaction: CloakSDKScannedTransaction): CloakScanTransactionSummary {
  return {
    signature: stringValue(transaction.signature),
    txType: stringValue(transaction.txType),
    amountLamports: decimalString(transaction.amount),
    feeLamports: decimalString(transaction.fee),
    netAmountLamports: decimalString(transaction.netAmount),
    runningBalanceLamports: optionalDecimalString(transaction.runningBalance),
    timestampMillis: timestampMillis(transaction.timestamp),
    recipient: stringValue(transaction.recipient),
    commitmentPrefix: prefix(stringValue(transaction.commitment)),
    mintAddress: stringValue(transaction.mint) ?? NATIVE_SOL_MINT,
    symbol: stringValue(transaction.symbol),
    status: "scanned",
  };
}

function safeComplianceSummary(
  summary: CloakScanSummary,
  result: CloakSDKScanResult,
  toComplianceReport: ((result: CloakSDKScanResult) => unknown) | undefined,
): CloakComplianceSummary {
  let dateRangeStart: string | undefined;
  let dateRangeEnd: string | undefined;
  if (summary.transactions.length > 0) {
    const timestamps = summary.transactions
      .map((transaction) => transaction.timestampMillis)
      .filter((value): value is string => value !== undefined)
      .sort();
    dateRangeStart = timestamps[0];
    dateRangeEnd = timestamps.at(-1);
  }

  if (typeof toComplianceReport === "function") {
    try {
      toComplianceReport(result);
    } catch {
      // Compliance reports are optional; the safe aggregate below is enough.
    }
  }

  const mintTotals = new Map<string, { symbol?: string; net: bigint }>();
  for (const transaction of summary.transactions) {
    const mint = transaction.mintAddress ?? NATIVE_SOL_MINT;
    const current = mintTotals.get(mint) ?? { symbol: transaction.symbol, net: 0n };
    current.net += BigInt(transaction.netAmountLamports);
    if (!current.symbol) {
      current.symbol = transaction.symbol;
    }
    mintTotals.set(mint, current);
  }

  return {
    transactionCount: summary.transactionCount,
    totalDepositsLamports: summary.totalDepositsLamports,
    totalWithdrawalsLamports: summary.totalWithdrawalsLamports,
    totalFeesLamports: summary.totalFeesLamports,
    netChangeLamports: summary.netChangeLamports,
    finalBalanceLamports: summary.finalBalanceLamports,
    mintBreakdown: Array.from(mintTotals.entries()).map(([mintAddress, value]) => ({
      mintAddress,
      symbol: value.symbol,
      netLamports: value.net.toString(),
    })),
    dateRangeStart,
    dateRangeEnd,
    generatedAt: new Date().toISOString(),
  };
}

function rejected(request: CloakBridgeRequest, message: string): CloakBridgeResponse {
  return response("scan", {
    request,
    actionKind: "scan",
    status: "rejected",
    errorCategory: "invalid-request",
    message,
    scanSummary: errorSummary(message),
  });
}

function errorSummary(message: string): CloakScanSummary {
  return {
    status: "error",
    transactions: [],
    totalDepositsLamports: "0",
    totalWithdrawalsLamports: "0",
    totalFeesLamports: "0",
    netChangeLamports: "0",
    finalBalanceLamports: "0",
    transactionCount: 0,
    scannedAt: new Date().toISOString(),
    errorMessage: message,
  };
}

function clampLimit(value: number | undefined): number {
  if (value === undefined || !Number.isFinite(value)) {
    return 250;
  }
  return Math.max(1, Math.min(500, Math.trunc(value)));
}

function optionalString(value: string | undefined): string | undefined {
  if (!value || value.trim().length === 0) {
    return undefined;
  }
  return value;
}

function stringValue(value: unknown): string | undefined {
  if (typeof value === "string" && value.length > 0) {
    return value;
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    return String(value);
  }
  if (typeof value === "bigint") {
    return value.toString();
  }
  if (value && typeof value === "object" && "toString" in value && typeof value.toString === "function") {
    const converted = value.toString();
    return converted === "[object Object]" ? undefined : converted;
  }
  return undefined;
}

function decimalString(value: unknown): string {
  const converted = stringValue(value);
  if (converted && /^-?[0-9]+$/.test(converted)) {
    return converted;
  }
  return "0";
}

function optionalDecimalString(value: unknown): string | undefined {
  const converted = stringValue(value);
  return converted && /^-?[0-9]+$/.test(converted) ? converted : undefined;
}

function numberValue(value: unknown): number | undefined {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "bigint") {
    return Number(value);
  }
  if (typeof value === "string" && /^[0-9]+$/.test(value)) {
    return Number(value);
  }
  return undefined;
}

function timestampMillis(value: unknown): string | undefined {
  if (value instanceof Date) {
    return String(value.getTime());
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    return String(value);
  }
  if (typeof value === "string" && value.length > 0) {
    const parsed = Date.parse(value);
    return Number.isFinite(parsed) ? String(parsed) : value;
  }
  return undefined;
}

function prefix(value: string | undefined): string | undefined {
  if (!value || value.length === 0) {
    return undefined;
  }
  return value.slice(0, 12);
}

function publicKeyString(value: unknown): string | undefined {
  if (typeof value === "string") {
    return value;
  }
  if (value && typeof value === "object" && "toBase58" in value && typeof value.toBase58 === "function") {
    return value.toBase58();
  }
  if (value && typeof value === "object" && "toString" in value && typeof value.toString === "function") {
    return value.toString();
  }
  return undefined;
}

async function safeErrorMessage(error: unknown): Promise<string> {
  try {
    const sdk = await import("@cloak.dev/sdk") as CloakScanRuntimeModule;
    const parsed = typeof sdk.parseError === "function" ? sdk.parseError(error) : undefined;
    if (parsed?.message) {
      return parsed.message.slice(0, 500);
    }
  } catch {
    // Fall through to local normalization.
  }
  return (error instanceof Error ? error.message : "Cloak scan failed.").slice(0, 500);
}
