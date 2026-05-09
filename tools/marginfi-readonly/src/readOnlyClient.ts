import { createRequire } from "node:module";
import { Connection, PublicKey } from "@solana/web3.js";
import {
  MARGINFI_PROGRAM_ID,
  SDK_MAIN_GROUP_ID,
  type MarginFiReadOnlyPosition,
  type MarginFiReadOnlyRequest,
  type MarginFiReadOnlyResponse,
  type MarginFiSdkValidation,
  response,
} from "./contracts.ts";
import { ReadOnlyWallet } from "./readOnlyWallet.ts";

type UnknownRecord = Record<string, unknown>;

export async function sdkValidation(): Promise<MarginFiSdkValidation> {
  const sdk = await importSdk();
  const group = resolveGroupId(sdk.exports);
  return {
    sdkInstalled: sdk.installed,
    sdkImportOk: sdk.importOk,
    sdkVersion: sdk.version,
    programId: MARGINFI_PROGRAM_ID,
    expectedProgramId: MARGINFI_PROGRAM_ID,
    programIdMatches: true,
    groupId: group.groupId,
    groupIdSource: group.source,
    readOnlyWallet: true,
  };
}

export async function fetchPositionsReadOnly(request: MarginFiReadOnlyRequest): Promise<MarginFiReadOnlyResponse> {
  if (request.network !== "mainnet-beta") {
    return response("positions", {
      requestId: request.requestId,
      status: "unavailable",
      errorCategory: "unsupported-network",
      message: "MarginFi SDK read-only adapter is mainnet-beta only.",
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
    const publicKey = new PublicKey(request.walletPublicAddress);
    const sdk = await importSdk();
    if (!sdk.importOk || !sdk.exports) {
      return response("positions", {
        requestId: request.requestId,
        status: "unavailable",
        errorCategory: "sdk-unavailable",
        message: "MarginFi SDK could not be imported.",
        sdkValidation: await sdkValidation(),
      });
    }

    const config = resolveConfig(sdk.exports);
    const connection = new Connection(request.rpcUrl, "confirmed");
    const wallet = new ReadOnlyWallet(publicKey);
    const clientClass = (sdk.exports as UnknownRecord).MarginfiClient as
      | { fetch?: (config: unknown, wallet: ReadOnlyWallet, connection: Connection) => Promise<unknown> }
      | undefined;
    if (!clientClass?.fetch) {
      return response("positions", {
        requestId: request.requestId,
        status: "unavailable",
        errorCategory: "sdk-unavailable",
        message: "MarginfiClient.fetch was not available from the SDK.",
        sdkValidation: await sdkValidation(),
      });
    }

    const client = await clientClass.fetch(config, wallet, connection);
    const accounts = await getAccountsForAuthority(client, publicKey);
    if (accounts.length === 0) {
      return response("positions", {
        requestId: request.requestId,
        status: "empty",
        errorCategory: "none",
        message: "No MarginFi accounts returned for this public authority.",
        sdkValidation: await sdkValidation(),
        positions: [],
        accountCount: 0,
        suppliedPositionCount: 0,
        borrowedPositionCount: 0,
      });
    }

    const positions = await Promise.all(accounts.map((account) => normalizeAccount(client, account, publicKey)));
    const suppliedCount = positions.reduce((sum, position) => sum + position.suppliedPositionCount, 0);
    const borrowedCount = positions.reduce((sum, position) => sum + position.borrowedPositionCount, 0);
    const allLoaded = positions.every((position) => position.status === "loaded");

    return response("positions", {
      requestId: request.requestId,
      status: allLoaded ? "loaded" : "partial",
      errorCategory: "none",
      message: allLoaded
        ? "MarginFi SDK read-only positions loaded."
        : "MarginFi SDK read-only positions loaded with partial value or metadata coverage.",
      sdkValidation: await sdkValidation(),
      positions,
      accountCount: positions.length,
      suppliedPositionCount: suppliedCount,
      borrowedPositionCount: borrowedCount,
    });
  } catch (error) {
    return response("positions", {
      requestId: request.requestId,
      status: "error",
      errorCategory: "sdk-unavailable",
      message: error instanceof Error ? error.message : "MarginFi SDK read-only lookup failed.",
      sdkValidation: await sdkValidation().catch(() => undefined),
    });
  }
}

async function importSdk(): Promise<{
  installed: boolean;
  importOk: boolean;
  version?: string;
  exports?: unknown;
}> {
  try {
    const exports = await import("@mrgnlabs/marginfi-client-v2");
    return {
      installed: true,
      importOk: true,
      version: packageVersion("@mrgnlabs/marginfi-client-v2"),
      exports,
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

function resolveConfig(sdk: unknown): unknown {
  const exported = sdk as UnknownRecord;
  const getConfig = exported.getConfig as ((cluster: string) => unknown) | undefined;
  if (getConfig) {
    for (const candidate of ["production", "mainnet-beta", "mainnet"]) {
      try {
        const config = getConfig(candidate);
        if (config) {
          return config;
        }
      } catch {
        // Try the next documented alias.
      }
    }
  }

  return {
    cluster: "mainnet-beta",
    programId: new PublicKey(MARGINFI_PROGRAM_ID),
    groupPk: new PublicKey(SDK_MAIN_GROUP_ID),
  };
}

function resolveGroupId(sdk: unknown): { groupId?: string; source: "sdk-config" | "local-candidate" | "unavailable" } {
  try {
    const config = resolveConfig(sdk);
    const group =
      readPublicKey(config, ["groupPk", "groupPubkey", "group"]) ??
      readPublicKey(config, ["marginfiGroup", "marginfiGroupPk"]);
    if (group) {
      return { groupId: group, source: "sdk-config" };
    }
  } catch {
    // Fall back to the local candidate from current docs.
  }

  return { groupId: SDK_MAIN_GROUP_ID, source: "local-candidate" };
}

async function getAccountsForAuthority(client: unknown, authority: PublicKey): Promise<unknown[]> {
  const method = (client as UnknownRecord).getMarginfiAccountsForAuthority;
  if (typeof method !== "function") {
    throw new Error("getMarginfiAccountsForAuthority is unavailable on the SDK client.");
  }
  const result = await method.call(client, authority);
  return Array.isArray(result) ? result : [];
}

async function normalizeAccount(client: unknown, account: unknown, authority: PublicKey): Promise<MarginFiReadOnlyPosition> {
  const accountAddress =
    readPublicKey(account, ["address", "publicKey", "pubkey"]) ??
    readPublicKey((account as UnknownRecord)?.account, ["address", "publicKey", "pubkey"]) ??
    "unknown";
  const groupAddress =
    readPublicKey(account, ["group", "groupPk", "groupAddress"]) ??
    readPublicKey((account as UnknownRecord)?.account, ["group", "groupPk"]) ??
    SDK_MAIN_GROUP_ID;
  const balances = readBalances(account);
  const suppliedAssets = [];
  const borrowedAssets = [];
  let suppliedUsd = 0;
  let borrowedUsd = 0;
  let suppliedUsdComplete = true;
  let borrowedUsdComplete = true;

  for (const balance of balances) {
    const bankAddress = readPublicKey(balance, ["bankPk", "bank", "bankAddress"]);
    const bank = bankAddress ? await getBank(client, bankAddress) : undefined;
    const mintAddress = readPublicKey(bank, ["mint", "mintAddress", "tokenMint"]);
    const symbol = readString(bank, ["tokenSymbol", "symbol", "name"]);
    const assetQuantity = computeQuantityUi(balance, bank, "asset");
    const liabilityQuantity = computeQuantityUi(balance, bank, "liability");
    const assetUsd = computeUsdValue(balance, bank, "asset");
    const liabilityUsd = computeUsdValue(balance, bank, "liability");

    if (assetQuantity || assetUsd) {
      if (assetUsd === undefined) {
        suppliedUsdComplete = false;
      } else {
        suppliedUsd += assetUsd;
      }
      suppliedAssets.push({
        side: "supplied" as const,
        bankAddress,
        mintAddress,
        symbol,
        quantityUi: assetQuantity,
        usdValue: assetUsd === undefined ? undefined : String(assetUsd),
      });
    }

    if (liabilityQuantity || liabilityUsd) {
      if (liabilityUsd === undefined) {
        borrowedUsdComplete = false;
      } else {
        borrowedUsd += liabilityUsd;
      }
      borrowedAssets.push({
        side: "borrowed" as const,
        bankAddress,
        mintAddress,
        symbol,
        quantityUi: liabilityQuantity,
        usdValue: liabilityUsd === undefined ? undefined : String(liabilityUsd),
      });
    }
  }

  const suppliedValueUsd = suppliedAssets.length > 0 && suppliedUsdComplete ? String(suppliedUsd) : undefined;
  const borrowedValueUsd = borrowedAssets.length > 0 && borrowedUsdComplete ? String(borrowedUsd) : undefined;
  const netValueUsd =
    suppliedValueUsd !== undefined && borrowedValueUsd !== undefined
      ? String(Number(suppliedValueUsd) - Number(borrowedValueUsd))
      : undefined;

  return {
    walletPublicAddress: authority.toBase58(),
    accountAddress,
    groupAddress,
    suppliedAssets,
    borrowedAssets,
    suppliedPositionCount: suppliedAssets.length,
    borrowedPositionCount: borrowedAssets.length,
    suppliedValueUsd,
    borrowedValueUsd,
    netValueUsd,
    riskLevel: "unavailable",
    status: netValueUsd === undefined && (suppliedAssets.length > 0 || borrowedAssets.length > 0) ? "partial" : "loaded",
    metadataStatus: "Official SDK read-only account data. Health and LTV are shown only when SDK exposes them without transaction helpers.",
  };
}

function readBalances(account: unknown): unknown[] {
  const candidates = [
    (account as UnknownRecord)?.activeBalances,
    (account as UnknownRecord)?.balances,
    ((account as UnknownRecord)?.account as UnknownRecord | undefined)?.activeBalances,
    ((account as UnknownRecord)?.account as UnknownRecord | undefined)?.balances,
    (((account as UnknownRecord)?.account as UnknownRecord | undefined)?.data as UnknownRecord | undefined)?.balances,
  ];
  for (const candidate of candidates) {
    if (Array.isArray(candidate)) {
      return candidate.filter(isActiveBalance);
    }
  }
  return [];
}

function isActiveBalance(balance: unknown): boolean {
  const active = (balance as UnknownRecord)?.active;
  if (typeof active === "boolean") {
    return active;
  }
  if (typeof active === "number") {
    return active !== 0;
  }
  return true;
}

async function getBank(client: unknown, bankAddress: string): Promise<unknown | undefined> {
  const method = (client as UnknownRecord).getBankByPk;
  if (typeof method !== "function") {
    return undefined;
  }
  try {
    return await method.call(client, new PublicKey(bankAddress));
  } catch {
    return undefined;
  }
}

function computeQuantityUi(balance: unknown, bank: unknown, side: "asset" | "liability"): string | undefined {
  const method = (balance as UnknownRecord)?.computeQuantityUi;
  if (typeof method !== "function") {
    return undefined;
  }
  try {
    const value = method.call(balance, bank, side === "asset" ? "asset" : "liability");
    return decimalLikeToString(value);
  } catch {
    try {
      const value = method.call(balance, bank);
      return decimalLikeToString(value);
    } catch {
      return undefined;
    }
  }
}

function computeUsdValue(balance: unknown, bank: unknown, side: "asset" | "liability"): number | undefined {
  const method = (balance as UnknownRecord)?.computeUsdValue;
  if (typeof method !== "function") {
    return undefined;
  }
  try {
    const value = method.call(balance, bank, side === "asset" ? "asset" : "liability");
    return decimalLikeToNumber(value);
  } catch {
    try {
      const value = method.call(balance, bank);
      return decimalLikeToNumber(value);
    } catch {
      return undefined;
    }
  }
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

function readString(value: unknown, keys: string[]): string | undefined {
  if (!value || typeof value !== "object") {
    return undefined;
  }
  const record = value as UnknownRecord;
  for (const key of keys) {
    const candidate = record[key];
    if (typeof candidate === "string") {
      return candidate;
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

function decimalLikeToNumber(value: unknown): number | undefined {
  const text = decimalLikeToString(value);
  if (!text) {
    return undefined;
  }
  const parsed = Number(text);
  return Number.isFinite(parsed) ? parsed : undefined;
}
