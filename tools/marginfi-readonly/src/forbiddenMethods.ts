export const ALLOWED_SDK_METHODS = [
  "MarginfiClient.fetch",
  "getConfig",
  "getMarginfiAccountsForAuthority",
  "getMultipleMarginfiAccounts",
  "getAllMarginfiAccountAddresses",
  "getBankByPk",
  "getBankByMint",
  "getBankByTokenSymbol",
  "getOraclePriceByBank",
  "Bank.fromBuffer",
  "Bank.decodeBankRaw",
  "MarginfiAccountWrapper.fetch",
  "MarginfiAccountWrapper.fromAccountDataRaw",
  "Balance.computeQuantityUi",
  "Balance.computeUsdValue",
  "Balance.getUsdValueWithPriceBias",
] as const;

export const FORBIDDEN_SDK_METHODS = [
  "createMarginfiAccount",
  "makeCreateMarginfiAccountIx",
  "deposit",
  "borrow",
  "repay",
  "withdraw",
  "liquidate",
  "repayWithCollateral",
  "loop",
  "simulateLoop",
  "makeLoopTx",
  "makeDepositIx",
  "makeBorrowIx",
  "makeRepayIx",
  "makeWithdrawIx",
  "makeWithdrawAllTx",
  "makeLendingAccountLiquidateIx",
  "flashLoan",
  "buildFlashLoanTx",
  "processTransaction",
  "makeTransferAccountAuthorityIx",
  "makeBeginFlashLoanIx",
  "makeEndFlashLoanIx",
] as const;

export function isForbiddenSdkMethodName(value: string): boolean {
  return FORBIDDEN_SDK_METHODS.some((method) => method.toLowerCase() === value.toLowerCase());
}
