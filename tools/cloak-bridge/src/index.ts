import {
  ALLOWED_COMMANDS,
  EXECUTION_COMMANDS,
  NATIVE_SOL_MINT,
  type CloakBridgeCommand,
  type CloakBridgeResponse,
  type CloakSigningRequestFrame,
  type CloakSigningResponseFrame,
} from "./contracts.ts";
import { depositPlan } from "./commands/depositPlan.ts";
import { envCheck } from "./commands/envCheck.ts";
import { executeCloakCommand } from "./commands/execute.ts";
import { health } from "./commands/health.ts";
import { response } from "./commands/response.ts";
import { scan } from "./commands/scan.ts";
import { validateNoForbiddenFields } from "./redaction.ts";

export async function handleCommand(command: CloakBridgeCommand, request: unknown = {}): Promise<CloakBridgeResponse> {
  validateNoForbiddenFields(request);

  if (!ALLOWED_COMMANDS.includes(command)) {
    return response(command, {
      request: request as Record<string, never>,
      status: "locked",
      errorCategory: "locked-in-phase-2-3",
      message: "Cloak transaction execution and signer commands are locked in Phase 2.4.",
    });
  }

  switch (command) {
    case "health":
      return await health(request);
    case "env-check":
      return await envCheck(request);
    case "deposit-plan":
      return await depositPlan(request);
    case "scan":
      return await scan(request);
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

async function readFirstLine(): Promise<{ firstLine: string; nextLine: () => Promise<string> }> {
  const readline = await import("node:readline");
  const rl = readline.createInterface({ input: process.stdin, crlfDelay: Infinity });
  const iterator = rl[Symbol.asyncIterator]();
  const first = await iterator.next();
  if (first.done || typeof first.value !== "string") {
    rl.close();
    throw new Error("Expected initial JSON request frame.");
  }
  return {
    firstLine: first.value,
    nextLine: async () => {
      const next = await iterator.next();
      if (next.done || typeof next.value !== "string") {
        throw new Error("Expected signer response frame.");
      }
      return next.value;
    },
  };
}

async function main(): Promise<void> {
  const command = process.argv[2] as CloakBridgeCommand | undefined;
  if (!command) {
    writeAndExit(response("health", {
      request: {},
      status: "rejected",
      errorCategory: "invalid-request",
      message: "Usage: node src/index.ts <health|env-check|deposit-plan|scan>",
    }), 2);
    return;
  }

  if (EXECUTION_COMMANDS.includes(command)) {
    await mainInteractive(command);
    return;
  }

  const body = await readStdin();
  const request = body.length > 0 ? JSON.parse(body) : {};
  const result = await handleCommand(command, request);
  const exitCode = result.status === "rejected" || result.status === "error" ? 1 : 0;
  writeAndExit(result, exitCode);
}

async function mainInteractive(command: CloakBridgeCommand): Promise<void> {
  const { firstLine, nextLine } = await readFirstLine();
  const request = JSON.parse(firstLine);
  validateNoForbiddenFieldsForExecution(request);
  const result = await executeCloakCommand(command, request, async (frame: CloakSigningRequestFrame): Promise<CloakSigningResponseFrame> => {
    process.stdout.write(`${JSON.stringify(frame)}\n`);
    const responseLine = await nextLine();
    const parsed = JSON.parse(responseLine) as CloakSigningResponseFrame;
    if (parsed.type !== "sign-response" || parsed.id !== frame.id) {
      throw new Error("Invalid signer response frame.");
    }
    return parsed;
  });
  process.stdout.write(`${JSON.stringify(result)}\n`);
  process.exit(result.response.status === "ok" ? 0 : 1);
}

function validateNoForbiddenFieldsForExecution(request: unknown): void {
  if (request !== null && typeof request === "object") {
    const shallowCopy = { ...(request as Record<string, unknown>) };
    delete shallowCopy.spendStateBase64;
    validateNoForbiddenFields(shallowCopy);
    return;
  }
  validateNoForbiddenFields(request);
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
