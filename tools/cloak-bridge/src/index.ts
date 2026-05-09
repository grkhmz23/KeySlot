import {
  ALLOWED_COMMANDS,
  CLOAK_PROGRAM_ID,
  NATIVE_SOL_MINT,
  calculateFeeQuote,
  type CloakBridgeCommand,
  type CloakBridgeRequest,
  type CloakBridgeResponse,
} from "./contracts.ts";
import { validateNoForbiddenFields } from "./redaction.ts";

export function handleCommand(command: CloakBridgeCommand, request: unknown = {}): CloakBridgeResponse {
  validateNoForbiddenFields(request);

  if (!ALLOWED_COMMANDS.includes(command)) {
    return response(command, {
      request,
      status: "locked",
      errorCategory: "locked-in-phase-2-1",
      message: "Cloak transaction execution commands are locked in Phase 2.1.",
    });
  }

  switch (command) {
    case "health":
      return response(command, {
        request,
        status: "ok",
        message: "Cloak bridge contract helper is available. Transaction execution is locked.",
      });
    case "env-check":
      return response(command, {
        request,
        status: "ok",
        message: "Environment contract check passed. SDK transaction calls are not enabled.",
      });
    case "deposit-plan":
      return depositPlan(request);
    default:
      return response(command, {
        request,
        status: "rejected",
        errorCategory: "unsupported-command",
        message: "Unsupported Cloak bridge command.",
      });
  }
}

function depositPlan(request: unknown): CloakBridgeResponse {
  const parsed = request as CloakBridgeRequest;
  if (!parsed.amountLamports) {
    return response("deposit-plan", {
      request,
      status: "rejected",
      errorCategory: "invalid-request",
      message: "deposit-plan requires amountLamports.",
    });
  }

  try {
    const feeQuote = calculateFeeQuote(parsed.amountLamports);
    return response("deposit-plan", {
      request,
      actionKind: "deposit",
      status: "locked",
      errorCategory: "locked-in-phase-2-1",
      message: "Deposit plan created. No transaction payload is returned in Phase 2.1.",
      feeQuote,
    });
  } catch (error) {
    return response("deposit-plan", {
      request,
      actionKind: "deposit",
      status: "rejected",
      errorCategory: "invalid-request",
      message: error instanceof Error ? error.message : "Invalid deposit-plan request.",
    });
  }
}

function response(
  command: CloakBridgeCommand,
  options: {
    request: unknown;
    actionKind?: CloakBridgeResponse["actionKind"];
    status: CloakBridgeResponse["status"];
    errorCategory?: CloakBridgeResponse["errorCategory"];
    message: string;
    feeQuote?: CloakBridgeResponse["feeQuote"];
  },
): CloakBridgeResponse {
  const request = options.request as Partial<CloakBridgeRequest>;
  return {
    requestId: request.requestId,
    command,
    actionKind: options.actionKind ?? request.actionKind,
    status: options.status,
    errorCategory: options.errorCategory ?? "none",
    message: options.message,
    programId: CLOAK_PROGRAM_ID,
    feeQuote: options.feeQuote,
    timestamp: new Date().toISOString(),
  };
}

async function readStdin(): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  return Buffer.concat(chunks).toString("utf8").trim();
}

async function main(): Promise<void> {
  const command = process.argv[2] as CloakBridgeCommand | undefined;
  if (!command) {
    writeAndExit(response("health", {
      request: {},
      status: "rejected",
      errorCategory: "invalid-request",
      message: "Usage: node src/index.ts <health|env-check|deposit-plan>",
    }), 2);
    return;
  }

  const body = await readStdin();
  const request = body.length > 0 ? JSON.parse(body) : {};
  const result = handleCommand(command, request);
  const exitCode = result.status === "rejected" || result.status === "error" ? 1 : 0;
  writeAndExit(result, exitCode);
}

function writeAndExit(result: CloakBridgeResponse, exitCode: number): void {
  process.stdout.write(`${JSON.stringify(result)}\n`);
  process.exit(exitCode);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    const result = response("health", {
      request: {},
      status: "rejected",
      errorCategory: "forbidden-field",
      message: error instanceof Error ? error.message : "Cloak bridge helper rejected the request.",
    });
    writeAndExit(result, 1);
  });
}

export { NATIVE_SOL_MINT };
