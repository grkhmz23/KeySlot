import { createRequire } from "node:module";
import { Connection, PublicKey } from "@solana/web3.js";
import type {
  MeteoraReadOnlyPosition,
  MeteoraReadOnlyRequest,
  MeteoraReadOnlyResponse,
  MeteoraSdkValidation,
} from "./contracts.ts";
import { response } from "./contracts.ts";

type UnknownRecord = Record<string, unknown>;

export async function sdkValidation(): Promise<MeteoraSdkValidation> {
  const sdk = await importSdk();
  return {
    sdkInstalled: sdk.installed,
    sdkImportOk: sdk.importOk,
    sdkVersion: sdk.version,
    readOnlyMethodAvailable: Boolean(sdk.dlmm?.getAllLbPairPositionsByUser),
  };
}

export async function fetchPositionsReadOnly(request: MeteoraReadOnlyRequest): Promise<MeteoraReadOnlyResponse> {
  if (request.network !== "mainnet-beta") {
    return response("positions", {
      requestId: request.requestId,
      status: "unavailable",
      errorCategory: "unsupported-network",
      message: "Meteora DLMM read-only adapter is mainnet-beta only.",
    });
  }

  if (!request.walletPublicAddress) {
    return response("positions", {
      requestId: request.requestId,
      status: "rejected",
      errorCategory: "invalid-request",
      message: "positions requires a wallet public address.",
    });
  }

  if (!request.rpcUrl) {
    return response("positions", {
      requestId: request.requestId,
      status: "unavailable",
      errorCategory: "rpc-unavailable",
      message: "positions requires an RPC URL. No RPC value is printed or persisted.",
      sdkValidation: await sdkValidation(),
    });
  }

  try {
    const sdk = await importSdk();
    if (!sdk.importOk || !sdk.dlmm?.getAllLbPairPositionsByUser) {
      return response("positions", {
        requestId: request.requestId,
        status: "unavailable",
        errorCategory: "sdk-unavailable",
        message: "Meteora DLMM SDK read-only user-position method is unavailable.",
        sdkValidation: await sdkValidation(),
      });
    }

    const userPublicKey = new PublicKey(request.walletPublicAddress);
    const connection = new Connection(request.rpcUrl, "confirmed");
    const rawPositions = await sdk.dlmm.getAllLbPairPositionsByUser(connection, userPublicKey);
    const positions = normalizePositions(rawPositions, userPublicKey.toBase58());
    if (positions.length === 0) {
      return response("positions", {
        requestId: request.requestId,
        status: "empty",
        errorCategory: "none",
        message: "No Meteora DLMM positions returned for this public wallet.",
        sdkValidation: await sdkValidation(),
        positions: [],
        positionCount: 0,
      });
    }

    const allLoaded = positions.every((position) => position.status === "loaded");
    return response("positions", {
      requestId: request.requestId,
      status: allLoaded ? "loaded" : "partial",
      errorCategory: "none",
      message: allLoaded
        ? "Meteora DLMM read-only positions loaded."
        : "Meteora DLMM read-only positions loaded with partial amount, value, or range coverage.",
      sdkValidation: await sdkValidation(),
      positions,
      positionCount: positions.length,
    });
  } catch (error) {
    return response("positions", {
      requestId: request.requestId,
      status: "error",
      errorCategory: "sdk-unavailable",
      message: error instanceof Error ? error.message.slice(0, 180) : "Meteora read-only lookup failed.",
      sdkValidation: await sdkValidation().catch(() => undefined),
    });
  }
}

function normalizePositions(rawPositions: unknown, walletPublicAddress: string): MeteoraReadOnlyPosition[] {
  const entries = entriesFromPositionMap(rawPositions);
  const normalized: MeteoraReadOnlyPosition[] = [];

  for (const [poolAddress, info] of entries) {
    for (const position of positionRecords(info)) {
      const tokenAMint = readPublicKey(info, ["tokenXMint", "tokenAMint", "mintX", "mintA"])
        ?? readPublicKey((info as UnknownRecord)?.lbPair, ["tokenXMint", "tokenAMint", "mintX", "mintA"]);
      const tokenBMint = readPublicKey(info, ["tokenYMint", "tokenBMint", "mintY", "mintB"])
        ?? readPublicKey((info as UnknownRecord)?.lbPair, ["tokenYMint", "tokenBMint", "mintY", "mintB"]);
      const lowerBinId = readNumber(position, ["lowerBinId", "lowerBinID", "lowerBin"]);
      const upperBinId = readNumber(position, ["upperBinId", "upperBinID", "upperBin"]);
      const currentBinId =
        readNumber(info, ["activeBinId", "currentBinId", "activeId"]) ??
        readNumber((info as UnknownRecord)?.lbPair, ["activeId", "activeBinId", "currentBinId"]);
      const tokenAAmountUi = readDecimalString(position, ["totalXAmount", "tokenXAmount", "amountX", "tokenAAmount"]);
      const tokenBAmountUi = readDecimalString(position, ["totalYAmount", "tokenYAmount", "amountY", "tokenBAmount"]);
      const tokenAFeesUi = readDecimalString(position, ["feeX", "feeXAmount", "tokenXFees", "claimableFeeX"]);
      const tokenBFeesUi = readDecimalString(position, ["feeY", "feeYAmount", "tokenYFees", "claimableFeeY"]);
      const positionAddress =
        readPublicKey(position, ["publicKey", "positionPubKey", "positionAddress", "address"]) ??
        readPublicKey(position, ["key"]) ??
        `${poolAddress}:position`;
      const rangeState = rangeStateFromBins(lowerBinId, upperBinId, currentBinId);
      const loaded = Boolean(tokenAMint && tokenBMint && tokenAAmountUi !== undefined && tokenBAmountUi !== undefined);

      normalized.push({
        walletPublicAddress,
        poolAddress,
        positionAddress,
        tokenAMint,
        tokenBMint,
        tokenAAmountUi,
        tokenBAmountUi,
        tokenAFeesUi,
        tokenBFeesUi,
        lowerBinId,
        upperBinId,
        currentBinId,
        rangeState,
        status: loaded ? "loaded" : "partial",
        metadataStatus: loaded
          ? "Official Meteora DLMM read-only SDK position data."
          : "Position found, but token amount or range metadata was incomplete in the read-only SDK response.",
      });
    }
  }

  return normalized;
}

function entriesFromPositionMap(rawPositions: unknown): Array<[string, unknown]> {
  if (rawPositions instanceof Map) {
    return Array.from(rawPositions.entries()).map(([key, value]) => [String(key), value]);
  }
  if (rawPositions && typeof rawPositions === "object") {
    return Object.entries(rawPositions as UnknownRecord);
  }
  return [];
}

function positionRecords(info: unknown): unknown[] {
  const candidates = [
    (info as UnknownRecord)?.positions,
    (info as UnknownRecord)?.userPositions,
    (info as UnknownRecord)?.positionData,
    (info as UnknownRecord)?.position,
  ];
  for (const candidate of candidates) {
    if (Array.isArray(candidate)) {
      return candidate;
    }
    if (candidate && typeof candidate === "object") {
      return [candidate];
    }
  }
  return info && typeof info === "object" ? [info] : [];
}

async function importSdk(): Promise<{
  installed: boolean;
  importOk: boolean;
  version?: string;
  dlmm?: { getAllLbPairPositionsByUser?: (connection: Connection, userPublicKey: PublicKey) => Promise<unknown> };
}> {
  try {
    const module = await import("@meteora-ag/dlmm");
    const candidates = [
      (module as UnknownRecord).default,
      ((module as UnknownRecord).default as UnknownRecord | undefined)?.default,
      (module as UnknownRecord).DLMM,
      module,
    ];
    const dlmm = candidates.find((candidate) => typeof (candidate as UnknownRecord | undefined)?.getAllLbPairPositionsByUser === "function") as
      | { getAllLbPairPositionsByUser?: (connection: Connection, userPublicKey: PublicKey) => Promise<unknown> }
      | undefined;
    return {
      installed: true,
      importOk: true,
      version: packageVersion("@meteora-ag/dlmm"),
      dlmm,
    };
  } catch {
    return {
      installed: false,
      importOk: false,
    };
  }
}

function packageVersion(name: string): string | undefined {
  try {
    const require = createRequire(import.meta.url);
    const pkg = require(`${name}/package.json`) as { version?: string };
    return pkg.version;
  } catch {
    return undefined;
  }
}

function rangeStateFromBins(
  lowerBinId: number | undefined,
  upperBinId: number | undefined,
  currentBinId: number | undefined,
): "in_range" | "out_of_range" | "unknown" {
  if (lowerBinId === undefined || upperBinId === undefined || currentBinId === undefined) {
    return "unknown";
  }
  return currentBinId >= lowerBinId && currentBinId <= upperBinId ? "in_range" : "out_of_range";
}

function readPublicKey(value: unknown, keys: string[]): string | undefined {
  if (!value || typeof value !== "object") {
    return undefined;
  }
  const record = value as UnknownRecord;
  for (const key of keys) {
    const candidate = record[key];
    if (!candidate) {
      continue;
    }
    if (typeof candidate === "string") {
      return candidate;
    }
    if (typeof (candidate as { toBase58?: unknown }).toBase58 === "function") {
      return (candidate as { toBase58: () => string }).toBase58();
    }
    if (typeof (candidate as { toString?: unknown }).toString === "function") {
      const text = (candidate as { toString: () => string }).toString();
      if (text && text !== "[object Object]") {
        return text;
      }
    }
  }
  return undefined;
}

function readNumber(value: unknown, keys: string[]): number | undefined {
  if (!value || typeof value !== "object") {
    return undefined;
  }
  const record = value as UnknownRecord;
  for (const key of keys) {
    const candidate = record[key];
    if (typeof candidate === "number" && Number.isFinite(candidate)) {
      return candidate;
    }
    if (typeof candidate === "string") {
      const parsed = Number(candidate);
      if (Number.isFinite(parsed)) {
        return parsed;
      }
    }
  }
  return undefined;
}

function readDecimalString(value: unknown, keys: string[]): string | undefined {
  if (!value || typeof value !== "object") {
    return undefined;
  }
  const record = value as UnknownRecord;
  for (const key of keys) {
    const candidate = record[key];
    const text = decimalLikeToString(candidate);
    if (text !== undefined) {
      return text;
    }
  }
  return undefined;
}

function decimalLikeToString(value: unknown): string | undefined {
  if (value === undefined || value === null) {
    return undefined;
  }
  if (typeof value === "string") {
    return value;
  }
  if (typeof value === "number") {
    return Number.isFinite(value) ? String(value) : undefined;
  }
  if (typeof (value as { toString?: unknown }).toString === "function") {
    const text = (value as { toString: () => string }).toString();
    return text === "[object Object]" ? undefined : text;
  }
  return undefined;
}
