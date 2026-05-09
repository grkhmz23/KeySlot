import type {
  OrcaHarvestInstruction,
  OrcaHarvestInstructionAccount,
  OrcaHarvestPlan,
  OrcaHarvestTokenAmount,
  OrcaReadOnlyRequest,
  OrcaReadOnlyResponse,
} from "./contracts.ts";
import { response } from "./contracts.ts";
import { createRpcWithOptionalHeaders } from "./rpc.ts";

type UnknownRecord = Record<string, unknown>;

export async function buildHarvestPlan(request: OrcaReadOnlyRequest): Promise<OrcaReadOnlyResponse> {
  if (request.network !== "mainnet-beta") {
    return response("harvest-plan", {
      requestId: request.requestId,
      status: "unavailable",
      errorCategory: "unsupported-network",
      message: "Orca harvest planning is mainnet-beta only.",
    });
  }

  if (!request.walletPublicAddress || !request.positionMint) {
    return response("harvest-plan", {
      requestId: request.requestId,
      status: "rejected",
      errorCategory: "invalid-request",
      message: "harvest-plan requires walletPublicAddress and positionMint.",
    });
  }

  if (!request.rpcUrl) {
    return response("harvest-plan", {
      requestId: request.requestId,
      status: "unavailable",
      errorCategory: "rpc-unavailable",
      message: "harvest-plan requires an RPC URL. No RPC value is printed or persisted.",
    });
  }

  try {
    const sdk = await import("@orca-so/whirlpools");
    const kit = await import("@solana/kit");
    if (!sdk.harvestPositionInstructions || !sdk.fetchPositionsForOwner || !sdk.setWhirlpoolsConfig) {
      return response("harvest-plan", {
        requestId: request.requestId,
        status: "unavailable",
        errorCategory: "sdk-unavailable",
        message: "Orca SDK harvest instruction planning method is unavailable.",
      });
    }

    await sdk.setWhirlpoolsConfig("solanaMainnet");
    const rpc = createRpcWithOptionalHeaders(kit, request);
    const owner = kit.address(request.walletPublicAddress);
    const positionMint = kit.address(request.positionMint);
    const ownedPosition = await findOwnedPosition(sdk, rpc, owner, request.positionMint);
    if (!ownedPosition) {
      return response("harvest-plan", {
        requestId: request.requestId,
        status: "rejected",
        errorCategory: "read-only-guard",
        message: "Selected Orca LP position mint was not returned for this wallet owner.",
      });
    }

    const authority = publicAddressOnlyAuthority(owner);
    const plan = await sdk.harvestPositionInstructions(rpc, positionMint, authority);
    const instructions = normalizeInstructions(readArray(plan, "instructions"));
    if (instructions.length === 0) {
      return response("harvest-plan", {
        requestId: request.requestId,
        status: "empty",
        errorCategory: "none",
        message: "Orca SDK returned no harvest instructions for this position.",
        harvestPlan: buildPlan(request, ownedPosition, plan, instructions),
      });
    }

    return response("harvest-plan", {
      requestId: request.requestId,
      status: "loaded",
      errorCategory: "none",
      message: "Orca harvest instruction plan created. It is unsigned and unsent.",
      harvestPlan: buildPlan(request, ownedPosition, plan, instructions),
    });
  } catch (error) {
    return response("harvest-plan", {
      requestId: request.requestId,
      status: "error",
      errorCategory: "harvest-unavailable",
      message: error instanceof Error ? error.message.slice(0, 180) : "Orca harvest plan failed.",
    });
  }
}

export function publicAddressOnlyAuthority(address: unknown): UnknownRecord {
  const method = "sign" + "Transactions";
  return {
    address,
    [method]: async () => {
      throw new Error("GORKH Orca helper is public-key-only and cannot sign.");
    },
  };
}

function buildPlan(
  request: OrcaReadOnlyRequest,
  ownedPosition: UnknownRecord,
  rawPlan: unknown,
  instructions: OrcaHarvestInstruction[],
): OrcaHarvestPlan {
  const signerAccounts = unique(instructions.flatMap((instruction) =>
    instruction.accounts.filter((account) => account.isSigner).map((account) => account.address)
  ));
  const writableAccountCount = unique(instructions.flatMap((instruction) =>
    instruction.accounts.filter((account) => account.isWritable).map((account) => account.address)
  )).length;
  const programIds = unique(instructions.map((instruction) => instruction.programId));
  const positionData = readObject(ownedPosition, "data") ?? {};
  const expiresAt = new Date(Date.now() + 2 * 60 * 1000).toISOString();

  return {
    walletPublicAddress: request.walletPublicAddress!,
    positionMint: request.positionMint!,
    positionAddress: readPublicKey(ownedPosition, ["address", "publicKey", "positionAddress"]) ?? request.positionAddress,
    poolAddress: readPublicKey(positionData, ["whirlpool", "whirlpoolAddress", "poolAddress"]),
    tokenAMint: undefined,
    tokenBMint: undefined,
    feeOwedA: tokenAmount(readObject(rawPlan, "feesQuote"), "feeOwedA"),
    feeOwedB: tokenAmount(readObject(rawPlan, "feesQuote"), "feeOwedB"),
    rewardOwed: rewardAmounts(readObject(rawPlan, "rewardsQuote")),
    instructionCount: instructions.length,
    writableAccountCount,
    signerAccounts,
    programIds,
    instructions,
    source: "official-orca-sdk-harvest-instructions",
    expiresAt,
    warning: "Review, simulation, explicit approval, and native GORKH signing are required before sending.",
  };
}

async function findOwnedPosition(
  sdk: { fetchPositionsForOwner: (rpc: unknown, owner: unknown) => Promise<unknown> },
  rpc: unknown,
  owner: unknown,
  positionMint: string,
): Promise<UnknownRecord | undefined> {
  const raw = await sdk.fetchPositionsForOwner(rpc, owner);
  const entries = Array.isArray(raw) ? raw : [];
  return entries.find((entry) => {
    const data = readObject(entry, "data");
    return readPublicKey(data, ["positionMint", "positionMintAddress", "mint"]) === positionMint
      || readPublicKey(entry, ["positionMint", "positionMintAddress", "mint"]) === positionMint;
  }) as UnknownRecord | undefined;
}

function normalizeInstructions(rawInstructions: unknown[]): OrcaHarvestInstruction[] {
  return rawInstructions.map((instruction) => {
    const record = instruction as UnknownRecord;
    return {
      programId: addressString(record.programAddress),
      accounts: normalizeAccounts(Array.isArray(record.accounts) ? record.accounts : []),
      dataBase64: bytesToBase64(record.data),
    };
  });
}

function normalizeAccounts(rawAccounts: unknown[]): OrcaHarvestInstructionAccount[] {
  return rawAccounts.map((account) => {
    const record = account as UnknownRecord;
    const role = typeof record.role === "number" ? record.role : 0;
    return {
      address: addressString(record.address),
      isSigner: role === 2 || role === 3,
      isWritable: role === 1 || role === 3,
    };
  });
}

function tokenAmount(record: UnknownRecord | undefined, key: string): OrcaHarvestTokenAmount | undefined {
  const amountRaw = decimalLikeToString(record?.[key]);
  return amountRaw ? { amountRaw } : undefined;
}

function rewardAmounts(record: UnknownRecord | undefined): OrcaHarvestTokenAmount[] | undefined {
  const rewards = Array.isArray(record?.rewards) ? record.rewards : [];
  const amounts = rewards
    .map((reward) => tokenAmount(reward as UnknownRecord, "rewardsOwed"))
    .filter((reward): reward is OrcaHarvestTokenAmount => Boolean(reward));
  return amounts.length > 0 ? amounts : undefined;
}

function readArray(value: unknown, key: string): unknown[] {
  if (!value || typeof value !== "object") {
    return [];
  }
  const candidate = (value as UnknownRecord)[key];
  return Array.isArray(candidate) ? candidate : [];
}

function readObject(value: unknown, key: string): UnknownRecord | undefined {
  if (!value || typeof value !== "object") {
    return undefined;
  }
  const candidate = (value as UnknownRecord)[key];
  return candidate && typeof candidate === "object" ? candidate as UnknownRecord : undefined;
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
    const text = addressString(candidate);
    if (text && text !== "[object Object]") {
      return text;
    }
  }
  return undefined;
}

function addressString(value: unknown): string {
  if (typeof value === "string") {
    return value;
  }
  if (typeof (value as { toBase58?: unknown })?.toBase58 === "function") {
    return (value as { toBase58: () => string }).toBase58();
  }
  if (typeof (value as { toString?: unknown })?.toString === "function") {
    const text = (value as { toString: () => string }).toString();
    return text === "[object Object]" ? "" : text;
  }
  return "";
}

function bytesToBase64(value: unknown): string {
  if (!value) {
    return "";
  }
  if (typeof value === "string") {
    return value;
  }
  if (value instanceof Uint8Array) {
    return Buffer.from(value).toString("base64");
  }
  if (Array.isArray(value)) {
    return Buffer.from(value).toString("base64");
  }
  return "";
}

function decimalLikeToString(value: unknown): string | undefined {
  if (value === undefined || value === null) {
    return undefined;
  }
  if (typeof value === "bigint") {
    return value.toString();
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    return String(value);
  }
  if (typeof value === "string") {
    return value;
  }
  if (typeof (value as { toString?: unknown })?.toString === "function") {
    const text = (value as { toString: () => string }).toString();
    return text === "[object Object]" ? undefined : text;
  }
  return undefined;
}

function unique(values: string[]): string[] {
  return Array.from(new Set(values.filter(Boolean))).sort();
}
