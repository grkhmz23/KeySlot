import { type CloakBridgeRequest, type CloakBridgeResponse } from "../contracts.ts";
import { response } from "./response.ts";

export function envCheck(request: unknown): CloakBridgeResponse {
  return response("env-check", {
    request: request as Partial<CloakBridgeRequest>,
    status: "ok",
    message: "Environment contract check passed. SDK transaction calls are not enabled.",
  });
}
