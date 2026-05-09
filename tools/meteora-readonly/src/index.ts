import {
  ALLOWED_COMMANDS,
  type MeteoraReadOnlyCommand,
  type MeteoraReadOnlyRequest,
  type MeteoraReadOnlyResponse,
  response,
} from "./contracts.ts";
import { fetchPositionsReadOnly, sdkValidation } from "./readOnlyClient.ts";
import { redactedRpcStatus, suspiciousEnvNames, validateNoForbiddenFields } from "./redaction.ts";

export async function handleCommand(
  command: MeteoraReadOnlyCommand,
  request: unknown = {},
): Promise<MeteoraReadOnlyResponse> {
  validateNoForbiddenFields(request);
  if (!ALLOWED_COMMANDS.includes(command)) {
    return response("health", {
      status: "rejected",
      errorCategory: "invalid-request",
      message: "Unsupported Meteora read-only helper command.",
    });
  }

  const typedRequest = request as MeteoraReadOnlyRequest;
  switch (command) {
    case "health":
      return health(typedRequest);
    case "env-check":
      return envCheck(typedRequest);
    case "positions":
      return positions(typedRequest);
  }
}

async function health(request: MeteoraReadOnlyRequest): Promise<MeteoraReadOnlyResponse> {
  const sdk = await sdkValidation();
  return response("health", {
    requestId: request.requestId,
    status: sdk.sdkImportOk && sdk.readOnlyMethodAvailable ? "loaded" : "unavailable",
    errorCategory: sdk.sdkImportOk && sdk.readOnlyMethodAvailable ? "none" : "sdk-unavailable",
    message: sdk.sdkImportOk && sdk.readOnlyMethodAvailable
      ? "Meteora DLMM SDK read-only position method is available."
      : "Meteora DLMM SDK read-only position method is unavailable.",
    sdkValidation: sdk,
  });
}

async function envCheck(request: MeteoraReadOnlyRequest): Promise<MeteoraReadOnlyResponse> {
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
    status: environmentValidation.networkSupported ? "loaded" : "unavailable",
    errorCategory: environmentValidation.networkSupported ? "none" : "unsupported-network",
    message: environmentValidation.networkSupported
      ? "Meteora read-only helper environment is valid."
      : "Meteora read-only helper supports mainnet-beta only.",
    environmentValidation,
    sdkValidation: await sdkValidation(),
  });
}

async function positions(request: MeteoraReadOnlyRequest): Promise<MeteoraReadOnlyResponse> {
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
  const command = process.argv[2] as MeteoraReadOnlyCommand | undefined;
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

function writeAndExit(result: MeteoraReadOnlyResponse, exitCode: number): void {
  process.stdout.write(`${JSON.stringify(result)}\n`);
  process.exit(exitCode);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    writeAndExit(response("health", {
      status: "rejected",
      errorCategory: "forbidden-field",
      message: error instanceof Error ? error.message : "Meteora helper rejected the request.",
    }), 1);
  });
}
