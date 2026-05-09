import { type CloakBridgeRequest, type CloakBridgeResponse } from "../contracts.ts";
import { response } from "./response.ts";

export function health(request: unknown): CloakBridgeResponse {
  return response("health", {
    request: request as Partial<CloakBridgeRequest>,
    status: "ok",
    message: "Cloak bridge contract helper is available. Transaction execution is locked.",
  });
}
