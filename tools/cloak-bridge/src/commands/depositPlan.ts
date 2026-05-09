import {
  buildDepositSignerRequestSummary,
  calculateFeeQuote,
  type CloakBridgeRequest,
  type CloakBridgeResponse,
} from "../contracts.ts";
import { loadFeeValidation, loadSdkValidation, nextRequiredGates } from "../sdk.ts";
import { response } from "./response.ts";

export async function depositPlan(request: unknown): Promise<CloakBridgeResponse> {
  const parsed = request as CloakBridgeRequest;
  if (parsed.amountLamports === undefined) {
    return response("deposit-plan", {
      request: parsed,
      status: "rejected",
      errorCategory: "invalid-request",
      message: "deposit-plan requires amountLamports.",
    });
  }

  try {
    const feeQuote = calculateFeeQuote(parsed.amountLamports);
    const sdkValidation = await loadSdkValidation();
    const feeValidation = await loadFeeValidation();
    return response("deposit-plan", {
      request: parsed,
      actionKind: "deposit",
      status: "locked",
      errorCategory: "locked-in-phase-2-3",
      message: "Deposit plan created with SDK import validation and locked signer preview. No transaction payload is returned in Phase 2.4.",
      feeQuote,
      sdkValidation,
      feeValidation,
      signerRequestSummary: buildDepositSignerRequestSummary(parsed, feeQuote),
      nextRequiredGates: nextRequiredGates(),
    });
  } catch (error) {
    return response("deposit-plan", {
      request: parsed,
      actionKind: "deposit",
      status: "rejected",
      errorCategory: "invalid-request",
      message: error instanceof Error ? error.message : "Invalid deposit-plan request.",
    });
  }
}
