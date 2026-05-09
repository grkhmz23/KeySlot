import { createRequire } from "node:module";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import type {
  OrcaReadOnlyPosition,
  OrcaReadOnlyRequest,
  OrcaReadOnlyResponse,
  OrcaSdkValidation,
} from "./contracts.ts";
import {
  ORCA_DEVNET_WHIRLPOOL_CONFIG,
  ORCA_MAINNET_WHIRLPOOL_CONFIG,
  ORCA_PUBLIC_API_BASE_URL,
  ORCA_WHIRLPOOL_PROGRAM_ID,
  response,
} from "./contracts.ts";

type UnknownRecord = Record<string, unknown>;

export async function sdkValidation(): Promise<OrcaSdkValidation> {
  const sdk = await importSdk();
  const kit = await importKit();
  return {
    sdkInstalled: sdk.installed,
    sdkImportOk: sdk.importOk,
    sdkVersion: sdk.version,
    kitInstalled: kit.installed,
    kitImportOk: kit.importOk,
    kitVersion: kit.version,
    readOnlyMethodAvailable: Boolean(sdk.module?.fetchPositionsForOwner && kit.module?.createSolanaRpc && kit.module?.address),
    whirlpoolProgramId: ORCA_WHIRLPOOL_PROGRAM_ID,
    mainnetWhirlpoolConfig: ORCA_MAINNET_WHIRLPOOL_CONFIG,
    devnetWhirlpoolConfig: ORCA_DEVNET_WHIRLPOOL_CONFIG,
    publicApiBaseUrl: ORCA_PUBLIC_API_BASE_URL,
  };
}

export async function fetchPositionsReadOnly(request: OrcaReadOnlyRequest): Promise<OrcaReadOnlyResponse> {
  if (request.network !== "mainnet-beta") {
    return response("positions", {
      requestId: request.requestId,
      status: "unavailable",
      errorCategory: "unsupported-network",
      message: "Orca Whirlpools read-only adapter is mainnet-beta only.",
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
    const kit = await importKit();
    if (!sdk.importOk || !sdk.module?.fetchPositionsForOwner || !sdk.module?.setWhirlpoolsConfig) {
      return response("positions", {
        requestId: request.requestId,
        status: "unavailable",
        errorCategory: "sdk-unavailable",
        message: "Orca Whirlpools SDK read-only user-position method is unavailable.",
        sdkValidation: await sdkValidation(),
      });
    }
    if (!kit.importOk || !kit.module?.createSolanaRpc || !kit.module?.address) {
      return response("positions", {
        requestId: request.requestId,
        status: "unavailable",
        errorCategory: "sdk-unavailable",
        message: "Solana Kit RPC helpers required by the Orca read-only SDK are unavailable.",
        sdkValidation: await sdkValidation(),
      });
    }

    await sdk.module.setWhirlpoolsConfig("solanaMainnet");
    const rpc = kit.module.createSolanaRpc(request.rpcUrl);
    const owner = kit.module.address(request.walletPublicAddress);
    const rawPositions = await sdk.module.fetchPositionsForOwner(rpc, owner);
    const positions = await normalizePositions(rawPositions, request.walletPublicAddress);

    if (positions.length === 0) {
      return response("positions", {
        requestId: request.requestId,
        status: "empty",
        errorCategory: "none",
        message: "No Orca Whirlpools positions returned for this public wallet.",
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
        ? "Orca Whirlpools read-only positions loaded."
        : "Orca Whirlpools positions loaded with partial amount, fee, or pool metadata coverage.",
      sdkValidation: await sdkValidation(),
      positions,
      positionCount: positions.length,
    });
  } catch (error) {
    return response("positions", {
      requestId: request.requestId,
      status: "error",
      errorCategory: "sdk-unavailable",
      message: error instanceof Error ? error.message.slice(0, 180) : "Orca read-only lookup failed.",
      sdkValidation: await sdkValidation().catch(() => undefined),
    });
  }
}

async function normalizePositions(rawPositions: unknown, walletPublicAddress: string): Promise<OrcaReadOnlyPosition[]> {
  const entries = Array.isArray(rawPositions) ? rawPositions : [];
  const normalized: OrcaReadOnlyPosition[] = [];

  for (const raw of entries) {
    const data = readObject(raw, ["data", "position", "account", "positionData"]) ?? (typeof raw === "object" ? raw : undefined);
    const poolAddress = readPublicKey(data, ["whirlpool", "whirlpoolAddress", "poolAddress"])
      ?? readPublicKey(raw, ["whirlpool", "whirlpoolAddress", "poolAddress"]);
    const positionAddress = readPublicKey(raw, ["address", "publicKey", "positionAddress", "position"])
      ?? readPublicKey(data, ["address", "publicKey", "positionAddress", "positionMint"])
      ?? `${poolAddress ?? "unknown-pool"}:position`;
    const tickLowerIndex = readNumber(data, ["tickLowerIndex", "lowerTickIndex"]);
    const tickUpperIndex = readNumber(data, ["tickUpperIndex", "upperTickIndex"]);
    const tickCurrentIndex = readNumber(raw, ["tickCurrentIndex", "currentTickIndex"])
      ?? readNumber(data, ["tickCurrentIndex", "currentTickIndex"]);
    const tokenAMint = readPublicKey(raw, ["tokenMintA", "tokenAMint", "mintA"])
      ?? readPublicKey(data, ["tokenMintA", "tokenAMint", "mintA"]);
    const tokenBMint = readPublicKey(raw, ["tokenMintB", "tokenBMint", "mintB"])
      ?? readPublicKey(data, ["tokenMintB", "tokenBMint", "mintB"]);
    const tokenAAmountUi = readDecimalString(raw, ["tokenAAmountUi", "tokenAAmount", "amountA"])
      ?? readDecimalString(data, ["tokenAAmountUi", "tokenAAmount", "amountA"]);
    const tokenBAmountUi = readDecimalString(raw, ["tokenBAmountUi", "tokenBAmount", "amountB"])
      ?? readDecimalString(data, ["tokenBAmountUi", "tokenBAmount", "amountB"]);
    const tokenAFeesUi = readDecimalString(raw, ["tokenAFeesUi", "feeOwedA", "feesA"])
      ?? readDecimalString(data, ["feeOwedA", "feesA"]);
    const tokenBFeesUi = readDecimalString(raw, ["tokenBFeesUi", "feeOwedB", "feesB"])
      ?? readDecimalString(data, ["feeOwedB", "feesB"]);
    const rangeState = rangeStateFromTicks(tickLowerIndex, tickUpperIndex, tickCurrentIndex);
    const loaded = Boolean(poolAddress && tokenAMint && tokenBMint && tickLowerIndex !== undefined && tickUpperIndex !== undefined);

    normalized.push({
      walletPublicAddress,
      poolAddress: poolAddress ?? "pool-unavailable",
      positionAddress,
      tokenAMint,
      tokenBMint,
      tokenAAmountUi,
      tokenBAmountUi,
      tokenAFeesUi,
      tokenBFeesUi,
      tickLowerIndex,
      tickUpperIndex,
      tickCurrentIndex,
      rangeState,
      status: loaded ? "loaded" : "partial",
      metadataStatus: loaded
        ? "Official Orca Whirlpools read-only SDK position data."
        : "Position found, but token amount, pool, or tick metadata was incomplete in the read-only SDK response.",
    });
  }

  return normalized;
}

async function importSdk(): Promise<{
  installed: boolean;
  importOk: boolean;
  version?: string;
  module?: {
    fetchPositionsForOwner?: (rpc: unknown, owner: unknown) => Promise<unknown>;
    setWhirlpoolsConfig?: (config: string) => Promise<void> | void;
  };
}> {
  try {
    const module = await import("@orca-so/whirlpools");
    return {
      installed: true,
      importOk: true,
      version: packageVersion("@orca-so/whirlpools"),
      module: module as {
        fetchPositionsForOwner?: (rpc: unknown, owner: unknown) => Promise<unknown>;
        setWhirlpoolsConfig?: (config: string) => Promise<void> | void;
      },
    };
  } catch {
    return {
      installed: false,
      importOk: false,
    };
  }
}

async function importKit(): Promise<{
  installed: boolean;
  importOk: boolean;
  version?: string;
  module?: {
    createSolanaRpc?: (url: string) => unknown;
    address?: (value: string) => unknown;
  };
}> {
  try {
    const module = await import("@solana/kit");
    return {
      installed: true,
      importOk: true,
      version: packageVersion("@solana/kit"),
      module: module as {
        createSolanaRpc?: (url: string) => unknown;
        address?: (value: string) => unknown;
      },
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
    return packageVersionByWalkingModulePath(name);
  }
}

function packageVersionByWalkingModulePath(name: string): string | undefined {
  try {
    const require = createRequire(import.meta.url);
    let cursor = dirname(require.resolve(name));
    for (let index = 0; index < 8; index += 1) {
      const candidate = join(cursor, "package.json");
      if (existsSync(candidate)) {
        const pkg = JSON.parse(readFileSync(candidate, "utf8")) as { name?: string; version?: string };
        if (pkg.name === name) {
          return pkg.version;
        }
      }
      const parent = dirname(cursor);
      if (parent === cursor) {
        break;
      }
      cursor = parent;
    }
  } catch {
    return undefined;
  }
  return undefined;
}

function rangeStateFromTicks(
  lower: number | undefined,
  upper: number | undefined,
  current: number | undefined,
): "in_range" | "out_of_range" | "unknown" {
  if (lower === undefined || upper === undefined || current === undefined) {
    return "unknown";
  }
  return current >= lower && current <= upper ? "in_range" : "out_of_range";
}

function readObject(value: unknown, keys: string[]): UnknownRecord | undefined {
  if (!value || typeof value !== "object") {
    return undefined;
  }
  const record = value as UnknownRecord;
  for (const key of keys) {
    const candidate = record[key];
    if (candidate && typeof candidate === "object") {
      return candidate as UnknownRecord;
    }
  }
  return undefined;
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
  if (typeof value === "number" && Number.isFinite(value)) {
    return String(value);
  }
  if (typeof value === "bigint") {
    return value.toString();
  }
  if (typeof value === "object" && typeof (value as { toString?: unknown }).toString === "function") {
    const text = (value as { toString: () => string }).toString();
    if (text && text !== "[object Object]") {
      return text;
    }
  }
  return undefined;
}
