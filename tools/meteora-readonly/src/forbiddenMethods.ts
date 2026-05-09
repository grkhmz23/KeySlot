export const ALLOWED_SDK_METHODS = [
  "DLMM.getAllLbPairPositionsByUser",
] as const;

export const FORBIDDEN_SDK_METHODS = [
  "addLiquidity",
  "removeLiquidity",
  "claimFee",
  "claimFees",
  "closePosition",
  "createPosition",
  "initializePosition",
  "initializePositionAndAddLiquidityByStrategy",
  "swap",
  "sendTransaction",
  "signTransaction",
  "buildTransaction",
  "createTransaction",
  "removeLiquidityByRange",
  "claimAllSwapFee",
  "claimLMReward",
] as const;

export function isForbiddenSdkMethodName(name: string): boolean {
  return FORBIDDEN_SDK_METHODS.includes(name as (typeof FORBIDDEN_SDK_METHODS)[number]);
}
