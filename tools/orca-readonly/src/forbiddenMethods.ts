export const ALLOWED_SDK_METHODS = [
  "fetchPositionsForOwner",
  "harvestPositionInstructions",
  "setWhirlpoolsConfig",
] as const;

export const FORBIDDEN_SDK_METHODS = [
  "increaseLiquidity",
  "decreaseLiquidity",
  "collectFees",
  "collectRewards",
  "closePosition",
  "openPosition",
  "createPosition",
  "createSplashPool",
  "createConcentratedLiquidityPool",
  "openFullRangePosition",
  "openConcentratedPosition",
  "harvestAllPositionFees",
  "harvestPosition",
  "updateFeesAndRewards",
  "increaseLiquidityInstructions",
  "openFullRangePositionInstructions",
  "openPositionInstructions",
  "openPositionInstructionsWithTickBounds",
  "transactionBuilder",
  "buildTransaction",
  "buildAndSendTransaction",
  "sendTransaction",
  "signTransaction",
  "tx-sender",
  "setDefaultFunder",
  "setPayerFromBytes",
] as const;

export function isForbiddenSdkMethodName(name: string): boolean {
  return FORBIDDEN_SDK_METHODS.includes(name as (typeof FORBIDDEN_SDK_METHODS)[number]);
}
