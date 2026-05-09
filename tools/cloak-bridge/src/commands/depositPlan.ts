import { calculateFeeQuote, type CloakBridgeRequest, type CloakBridgeResponse } from "../contracts.ts";
import { response } from "./response.ts";

export function depositPlan(request: unknown): CloakBridgeResponse {
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
    return response("deposit-plan", {
      request: parsed,
      actionKind: "deposit",
      status: "locked",
      errorCategory: "locked-in-phase-2-2",
      message: "Deposit plan created. No transaction payload is returned in Phase 2.2.",
      feeQuote,
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
