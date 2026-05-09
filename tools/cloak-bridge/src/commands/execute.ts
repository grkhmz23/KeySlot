import { randomUUID } from "node:crypto";
import {
  CLOAK_PROGRAM_ID,
  NATIVE_SOL_MINT,
  calculateFeeQuote,
  type CloakBridgeCommand,
  type CloakBridgeResponse,
  type CloakExecutionRequest,
  type CloakExecutionResultFrame,
  type CloakSigningRequestFrame,
  type CloakSigningResponseFrame,
} from "../contracts.ts";
import { loadSdkValidation } from "../sdk.ts";
import { resolveCloakRPCConfiguration } from "../rpc.ts";
import { response } from "./response.ts";

type SignerRoundTrip = (frame: CloakSigningRequestFrame) => Promise<CloakSigningResponseFrame>;

type CloakRuntimeModule = {
  CLOAK_PROGRAM_ID: unknown;
  NATIVE_SOL_MINT: unknown;
  createUtxo: (amount: bigint, keypair: unknown, mint?: unknown) => Promise<unknown>;
  createZeroUtxo: (mint?: unknown) => Promise<unknown>;
  deserializeUtxo: (bytes: Uint8Array) => Promise<unknown>;
  fullWithdraw: (inputUtxos: unknown[], recipient: unknown, options: Record<string, unknown>) => Promise<CloakRuntimeResult>;
  generateUtxoKeypair: () => Promise<{ privateKey: bigint; publicKey: bigint }>;
  getNkFromUtxoPrivateKey: (utxoPrivateKey: bigint) => Uint8Array;
  parseError?: (error: unknown) => { message?: string; category?: string; recoverable?: boolean };
  serializeUtxo: (utxo: unknown) => Uint8Array;
  transact: (params: Record<string, unknown>, options: Record<string, unknown>) => Promise<CloakRuntimeResult>;
};

type Web3Module = {
  Connection: new (endpoint: string, config?: unknown) => unknown;
  PublicKey: new (value: string) => unknown;
  Transaction: {
    from(data: Buffer): unknown;
  };
  VersionedTransaction: {
    deserialize(data: Uint8Array): unknown;
  };
};

type CloakRuntimeResult = {
  signature?: string;
  outputCommitments?: bigint[];
  commitmentIndices?: [number, number];
  outputUtxos?: unknown[];
  viewingKeyRegistered?: boolean;
};

export async function executeCloakCommand(
  command: CloakBridgeCommand,
  request: CloakExecutionRequest,
  sign: SignerRoundTrip,
): Promise<CloakExecutionResultFrame> {
  validateExecutionRequest(command, request);
  const sdk = await import("@cloak.dev/sdk") as CloakRuntimeModule;
  const web3 = await import("@solana/web3.js") as Web3Module;

  if (publicKeyString(sdk.CLOAK_PROGRAM_ID) !== CLOAK_PROGRAM_ID) {
    return resultFrame(response(command, {
      request,
      actionKind: request.actionKind,
      status: "rejected",
      errorCategory: "invalid-request",
      message: "Cloak SDK program id does not match the GORKH allowlist.",
      sdkValidation: await loadSdkValidation(),
    }));
  }

  try {
    switch (command) {
      case "execute-deposit":
        return await executeDeposit(request, sdk, web3, sign);
      case "full-withdraw":
        return await executeFullWithdraw(request, sdk, web3, sign);
      default:
        return resultFrame(response(command, {
          request,
          actionKind: request.actionKind,
          status: "locked",
          errorCategory: "unsupported-command",
          message: "Unsupported Cloak execution command.",
        }));
    }
  } catch (error) {
    return resultFrame(response(command, {
      request,
      actionKind: request.actionKind,
      status: "error",
      errorCategory: "invalid-request",
      message: safeErrorMessage(error, sdk),
      sdkValidation: await loadSdkValidation(),
    }));
  }
}

async function executeDeposit(
  request: CloakExecutionRequest,
  sdk: CloakRuntimeModule,
  web3: Web3Module,
  sign: SignerRoundTrip,
): Promise<CloakExecutionResultFrame> {
  const amount = parsePositiveLamports(request.amountLamports, "amountLamports");
  const feeQuote = calculateFeeQuote(amount.toString());
  const walletPublicKey = new web3.PublicKey(requiredString(request.walletPublicAddress, "walletPublicAddress"));
  const rpc = resolveCloakRPCConfiguration(request.rpcUrl);
  const connection = new web3.Connection(rpc.endpoint, { commitment: "confirmed", httpHeaders: rpc.httpHeaders });
  const programId = sdk.CLOAK_PROGRAM_ID;
  const outputKeypair = await sdk.generateUtxoKeypair();
  const privateOutputAmount = amount;
  const output = await sdk.createUtxo(privateOutputAmount, outputKeypair, sdk.NATIVE_SOL_MINT);
  const zero = await sdk.createZeroUtxo(sdk.NATIVE_SOL_MINT);
  const nk = sdk.getNkFromUtxoPrivateKey(outputKeypair.privateKey);

  const runtimeOptions = {
    connection,
    programId,
    signTransaction: async <T>(transaction: T): Promise<T> => {
      const unsignedBase64 = serializeTransactionForSigning(transaction);
      const signed = await sign(signingFrame(request, "sign_transaction", unsignedBase64, "Approve Cloak SOL shield deposit transaction."));
      return deserializeSignedTransaction(signed.signedPayloadBase64, transaction, web3) as T;
    },
    signMessage: async (message: Uint8Array): Promise<Uint8Array> => {
      const signed = await sign(signingFrame(request, "sign_message", Buffer.from(message).toString("base64"), "Approve Cloak viewing-key registration message."));
      return Uint8Array.from(Buffer.from(signed.signedPayloadBase64, "base64"));
    },
    depositorPublicKey: walletPublicKey,
    walletPublicKey,
    relayUrl: request.relayUrl,
    chainNoteViewingKeyNk: nk,
    onProgress: (_status: string) => undefined,
    onProofProgress: (_percent: number) => undefined,
  };

  const deposited = await sdk.transact(
    {
      inputUtxos: [zero],
      outputUtxos: [output],
      externalAmount: amount,
      depositor: walletPublicKey,
    },
    runtimeOptions,
  );

  const outputUtxo = requiredOutputUtxo(deposited);
  const commitment = deposited.outputCommitments?.[0];
  const leafIndex = deposited.commitmentIndices?.[0];
  return {
    type: "result",
    response: response("execute-deposit", {
      request,
      actionKind: "deposit",
      status: "ok",
      message: "Cloak SOL deposit confirmed. Private state returned to Swift for local vault storage only.",
      feeQuote,
      sdkValidation: await loadSdkValidation(),
    }, {
      txSignature: deposited.signature,
      commitmentPrefix: commitmentPrefix(commitment),
    }),
    secureOutputStateBase64: Buffer.from(sdk.serializeUtxo(outputUtxo)).toString("base64"),
    secureViewingStateBase64: Buffer.from(nk).toString("base64"),
    leafIndex,
  };
}

async function executeFullWithdraw(
  request: CloakExecutionRequest,
  sdk: CloakRuntimeModule,
  web3: Web3Module,
  sign: SignerRoundTrip,
): Promise<CloakExecutionResultFrame> {
  const amount = parsePositiveLamports(request.amountLamports, "amountLamports");
  const spendState = requiredString(request.spendStateBase64, "spendStateBase64");
  const walletPublicKey = new web3.PublicKey(requiredString(request.walletPublicAddress, "walletPublicAddress"));
  const recipient = new web3.PublicKey(requiredString(request.recipientAddress, "recipientAddress"));
  const rpc = resolveCloakRPCConfiguration(request.rpcUrl);
  const connection = new web3.Connection(rpc.endpoint, { commitment: "confirmed", httpHeaders: rpc.httpHeaders });
  const inputUtxo = await sdk.deserializeUtxo(Uint8Array.from(Buffer.from(spendState, "base64")));

  const runtimeOptions = {
    connection,
    programId: sdk.CLOAK_PROGRAM_ID,
    signTransaction: async <T>(transaction: T): Promise<T> => {
      const unsignedBase64 = serializeTransactionForSigning(transaction);
      const signed = await sign(signingFrame(request, "sign_transaction", unsignedBase64, "Approve Cloak SOL full-withdraw transaction."));
      return deserializeSignedTransaction(signed.signedPayloadBase64, transaction, web3) as T;
    },
    signMessage: async (message: Uint8Array): Promise<Uint8Array> => {
      const signed = await sign(signingFrame(request, "sign_message", Buffer.from(message).toString("base64"), "Approve Cloak viewing-key registration message."));
      return Uint8Array.from(Buffer.from(signed.signedPayloadBase64, "base64"));
    },
    depositorPublicKey: walletPublicKey,
    walletPublicKey,
    relayUrl: request.relayUrl,
    onProgress: (_status: string) => undefined,
    onProofProgress: (_percent: number) => undefined,
  };

  const withdrawn = await sdk.fullWithdraw([inputUtxo], recipient, runtimeOptions);
  return {
    type: "result",
    response: response("full-withdraw", {
      request,
      actionKind: "full_withdraw",
      status: "ok",
      message: "Cloak SOL full withdraw confirmed. Local shielded state should be marked spent.",
      sdkValidation: await loadSdkValidation(),
    }, {
      txSignature: withdrawn.signature,
      commitmentPrefix: commitmentPrefix(withdrawn.outputCommitments?.[0]),
    }),
    secureSpentStateBase64: spendState,
  };
}

function validateExecutionRequest(command: CloakBridgeCommand, request: CloakExecutionRequest): void {
  if (request.network !== "mainnet-beta") {
    throw new Error("Cloak execution is mainnet-beta only.");
  }
  if (request.programId && request.programId !== CLOAK_PROGRAM_ID) {
    throw new Error("programId mismatch");
  }
  if (request.mintAddress && request.mintAddress !== NATIVE_SOL_MINT) {
    throw new Error("Phase 2.5 supports native SOL only.");
  }
  if (!request.approvedDraftFingerprint || request.approvedDraftFingerprint.trim().length === 0) {
    throw new Error("approvedDraftFingerprint is required.");
  }
  if (command === "execute-deposit" && request.actionKind !== "deposit") {
    throw new Error("execute-deposit requires actionKind deposit.");
  }
  if (command === "full-withdraw" && request.actionKind !== "full_withdraw") {
    throw new Error("full-withdraw requires actionKind full_withdraw.");
  }
  parsePositiveLamports(request.amountLamports, "amountLamports");
}

function signingFrame(
  request: CloakExecutionRequest,
  signingKind: "sign_transaction" | "sign_message",
  payloadBase64: string,
  purpose: string,
): CloakSigningRequestFrame {
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 120_000);
  return {
    type: "sign-request",
    id: randomUUID(),
    requestId: request.requestId,
    signingKind,
    walletPublicKey: requiredString(request.walletPublicAddress, "walletPublicAddress"),
    network: "mainnet-beta",
    actionKind: request.actionKind === "full_withdraw" ? "full_withdraw" : "deposit",
    amountLamports: parsePositiveLamports(request.amountLamports, "amountLamports").toString(),
    mintAddress: request.mintAddress ?? NATIVE_SOL_MINT,
    programId: CLOAK_PROGRAM_ID,
    draftFingerprint: requiredString(request.approvedDraftFingerprint, "approvedDraftFingerprint"),
    purpose,
    payloadBase64,
    timestamp: now.toISOString(),
    expiresAt: expiresAt.toISOString(),
  };
}

function serializeTransactionForSigning(transaction: unknown): string {
  const serializable = transaction as {
    serialize: (options?: { requireAllSignatures?: boolean; verifySignatures?: boolean }) => Buffer | Uint8Array;
  };
  const bytes = serializable.serialize({ requireAllSignatures: false, verifySignatures: false });
  return Buffer.from(bytes).toString("base64");
}

function deserializeSignedTransaction(signedBase64: string, original: unknown, web3: Web3Module): unknown {
  const bytes = Buffer.from(signedBase64, "base64");
  if (original && typeof original === "object" && "version" in original) {
    return web3.VersionedTransaction.deserialize(Uint8Array.from(bytes));
  }
  return web3.Transaction.from(bytes);
}

function requiredString(value: string | undefined, field: string): string {
  if (!value || value.trim().length === 0) {
    throw new Error(`${field} is required.`);
  }
  return value;
}

function parsePositiveLamports(value: string | number | undefined, field: string): bigint {
  if (typeof value === "number") {
    if (!Number.isSafeInteger(value) || value <= 0) {
      throw new Error(`${field} must be a positive integer.`);
    }
    return BigInt(value);
  }
  if (typeof value === "string" && /^[0-9]+$/.test(value) && BigInt(value) > 0n) {
    return BigInt(value);
  }
  throw new Error(`${field} must be a positive integer string.`);
}

function resultFrame(responseValue: CloakBridgeResponse): CloakExecutionResultFrame {
  return { type: "result", response: responseValue };
}

function requiredOutputUtxo(result: CloakRuntimeResult): unknown {
  const output = result.outputUtxos?.[0];
  if (!output) {
    throw new Error("Cloak SDK did not return an output state.");
  }
  return output;
}

function commitmentPrefix(value: bigint | undefined): string | undefined {
  if (value === undefined) {
    return undefined;
  }
  const hex = value.toString(16).padStart(64, "0");
  return hex.slice(0, 12);
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

function safeErrorMessage(error: unknown, sdk: CloakRuntimeModule): string {
  try {
    const parsed = typeof sdk.parseError === "function" ? sdk.parseError(error) : undefined;
    if (parsed?.message) {
      return parsed.message;
    }
  } catch {
    // Fall through to local normalization.
  }
  const message = error instanceof Error ? error.message : "Cloak execution failed.";
  return message.slice(0, 500);
}
