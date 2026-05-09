import { type CloakBridgeRequest, type CloakBridgeResponse } from "../contracts.ts";
import { validateEnvironment } from "../environment.ts";
import { loadSdkValidation } from "../sdk.ts";
import { response } from "./response.ts";

export async function envCheck(request: unknown): Promise<CloakBridgeResponse> {
  const parsed = request as Partial<CloakBridgeRequest>;
  const environmentValidation = validateEnvironment(parsed);
  const sdkValidation = await loadSdkValidation();
  const hasSuspiciousEnv = environmentValidation.suspiciousEnvVarNames.length > 0;

  return response("env-check", {
    request: parsed,
    status: hasSuspiciousEnv ? "rejected" : "ok",
    errorCategory: hasSuspiciousEnv ? "forbidden-field" : "none",
    message: hasSuspiciousEnv
      ? "Environment rejected: wallet secret-like environment variable names are present. Values were not read or printed."
      : "Environment check passed. RPC URL is redacted and SDK transaction calls are not enabled.",
    environmentValidation,
    sdkValidation,
  });
}
