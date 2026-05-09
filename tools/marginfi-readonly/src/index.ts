import {
  ALLOWED_COMMANDS,
  type MarginFiReadOnlyCommand,
  type MarginFiReadOnlyRequest,
  type MarginFiReadOnlyResponse,
  response,
} from "./contracts.ts";
import { fetchPositionsReadOnly, sdkValidation } from "./readOnlyClient.ts";
import { redactedRpcStatus, suspiciousEnvNames, validateNoForbiddenFields } from "./redaction.ts";

export async function handleCommand(
  command: MarginFiReadOnlyCommand,
  request: unknown = {},
): Promise<MarginFiReadOnlyResponse> {
  validateNoForbiddenFields(request);
  if (!ALLOWED_COMMANDS.includes(command)) {
    return response("health", {
      status: "rejected",
      errorCategory: "invalid-request",
      message: "Unsupported MarginFi read-only helper command.",
    });
  }

  const typedRequest = request as MarginFiReadOnlyRequest;
  switch (command) {
    case "health":
      return health(typedRequest);
    case "env-check":
      return envCheck(typedRequest);
    case "positions":
      return positions(typedRequest);
  }
}

async function health(request: MarginFiReadOnlyRequest): Promise<MarginFiReadOnlyResponse> {
  const sdk = await sdkValidation();
  return response("health", {
    requestId: request.requestId,
    status: sdk.sdkImportOk ? "ok" : "unavailable",
    errorCategory: sdk.sdkImportOk ? "none" : "sdk-unavailable",
    message: sdk.sdkImportOk
      ? "MarginFi SDK import is available for read-only commands."
      : "MarginFi SDK import is unavailable.",
    groupId: sdk.groupId,
    sdkValidation: sdk,
  });
}

async function envCheck(request: MarginFiReadOnlyRequest): Promise<MarginFiReadOnlyResponse> {
  const names = suspiciousEnvNames();
  const rpc = redactedRpcStatus(request.rpcUrl ?? process.env.SOLANA_RPC_URL);
  const environmentValidation = {
    network: request.network,
    networkSupported: request.network === "mainnet-beta",
    rpcUrlStatus: rpc.status,
    rpcUrlRedacted: rpc.redacted,
    walletSecretEnvAccepted: false as const,
    suspiciousEnvVarNames: names,
  };

  if (names.length > 0) {
    return response("env-check", {
      requestId: request.requestId,
      status: "rejected",
      errorCategory: "forbidden-field",
      message: "Suspicious wallet secret environment variable names are present. Values were not printed.",
      environmentValidation,
      sdkValidation: await sdkValidation(),
    });
  }

  return response("env-check", {
    requestId: request.requestId,
    status: environmentValidation.networkSupported ? "ok" : "unavailable",
    errorCategory: environmentValidation.networkSupported ? "none" : "unsupported-network",
    message: environmentValidation.networkSupported
      ? "MarginFi read-only helper environment is valid."
      : "MarginFi read-only helper supports mainnet-beta only.",
    environmentValidation,
    sdkValidation: await sdkValidation(),
  });
}

async function positions(request: MarginFiReadOnlyRequest): Promise<MarginFiReadOnlyResponse> {
  const names = suspiciousEnvNames();
  if (names.length > 0) {
    const rpc = redactedRpcStatus(request.rpcUrl ?? process.env.SOLANA_RPC_URL);
    return response("positions", {
      requestId: request.requestId,
      status: "rejected",
      errorCategory: "forbidden-field",
      message: "Suspicious wallet secret environment variable names are present. Values were not printed.",
      environmentValidation: {
        network: request.network,
        networkSupported: request.network === "mainnet-beta",
        rpcUrlStatus: rpc.status,
        rpcUrlRedacted: rpc.redacted,
        walletSecretEnvAccepted: false,
        suspiciousEnvVarNames: names,
      },
      sdkValidation: await sdkValidation(),
    });
  }

  return fetchPositionsReadOnly({
    ...request,
    command: "positions",
    rpcUrl: request.rpcUrl ?? process.env.SOLANA_RPC_URL,
  });
}

async function readStdin(): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  return Buffer.concat(chunks).toString("utf8").trim();
}

async function main(): Promise<void> {
  const command = process.argv[2] as MarginFiReadOnlyCommand | undefined;
  if (!command) {
    writeAndExit(response("health", {
      status: "rejected",
      errorCategory: "invalid-request",
      message: "Usage: node src/index.ts <health|env-check|positions>",
    }), 2);
    return;
  }

  const body = await readStdin();
  const request = body.length > 0 ? JSON.parse(body) : {};
  const result = await handleCommand(command, request);
  writeAndExit(result, result.status === "rejected" || result.status === "error" ? 1 : 0);
}

function writeAndExit(result: MarginFiReadOnlyResponse, exitCode: number): void {
  process.stdout.write(`${JSON.stringify(result)}\n`);
  process.exit(exitCode);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    writeAndExit(response("health", {
      status: "rejected",
      errorCategory: "forbidden-field",
      message: error instanceof Error ? error.message : "MarginFi helper rejected the request.",
    }), 1);
  });
}
