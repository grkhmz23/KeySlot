import { CLOAK_PROGRAM_ID, type CloakBridgeCommand, type CloakBridgeRequest, type CloakBridgeResponse } from "../contracts.ts";
import { randomUUID } from "node:crypto";

export function response(
  command: CloakBridgeCommand,
  options: {
    request: Partial<CloakBridgeRequest>;
    actionKind?: CloakBridgeResponse["actionKind"];
    status: CloakBridgeResponse["status"];
    errorCategory?: CloakBridgeResponse["errorCategory"];
    message: string;
    feeQuote?: CloakBridgeResponse["feeQuote"];
  },
): CloakBridgeResponse {
  return {
    id: randomUUID(),
    requestId: options.request.requestId,
    command,
    actionKind: options.actionKind ?? options.request.actionKind,
    status: options.status,
    errorCategory: options.errorCategory ?? "none",
    message: options.message,
    programId: CLOAK_PROGRAM_ID,
    feeQuote: options.feeQuote,
    timestamp: new Date().toISOString(),
  };
}
