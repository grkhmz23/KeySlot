import {
  ALLOWED_COMMANDS,
  NATIVE_SOL_MINT,
  type CloakBridgeCommand,
  type CloakBridgeResponse,
} from "./contracts.ts";
import { depositPlan } from "./commands/depositPlan.ts";
import { envCheck } from "./commands/envCheck.ts";
import { health } from "./commands/health.ts";
import { response } from "./commands/response.ts";
import { validateNoForbiddenFields } from "./redaction.ts";

export function handleCommand(command: CloakBridgeCommand, request: unknown = {}): CloakBridgeResponse {
  validateNoForbiddenFields(request);

  if (!ALLOWED_COMMANDS.includes(command)) {
    return response(command, {
      request: request as Record<string, never>,
      status: "locked",
      errorCategory: "locked-in-phase-2-2",
      message: "Cloak transaction execution commands are locked in Phase 2.2.",
    });
  }

  switch (command) {
    case "health":
      return health(request);
    case "env-check":
      return envCheck(request);
    case "deposit-plan":
      return depositPlan(request);
    default:
      return response(command, {
        request: request as Record<string, never>,
        status: "rejected",
        errorCategory: "unsupported-command",
        message: "Unsupported Cloak bridge command.",
      });
  }
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
