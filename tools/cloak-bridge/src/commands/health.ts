import { type CloakBridgeRequest, type CloakBridgeResponse } from "../contracts.ts";
import { loadFeeValidation, loadSdkValidation } from "../sdk.ts";
import { response } from "./response.ts";

export async function health(request: unknown): Promise<CloakBridgeResponse> {
  const sdkValidation = await loadSdkValidation();
  const feeValidation = await loadFeeValidation();

  return response("health", {
    request: request as Partial<CloakBridgeRequest>,
    status: "ok",
    message: "Cloak bridge helper is available. SDK import validation is non-executing and transaction execution is locked.",
    sdkValidation,
    feeValidation,
  });
}
