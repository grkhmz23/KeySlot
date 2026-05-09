import type { CloakBridgeRequest, CloakEnvironmentValidation } from "./contracts.ts";
import { resolveCloakRPCConfiguration } from "./rpc.ts";

export const SUSPICIOUS_SECRET_ENV_NAMES = [
  "PRIVATE_KEY",
  "SECRET_KEY",
  "SEED_PHRASE",
  "MNEMONIC",
  "WALLET_JSON",
  "CLOAK_VIEWING_KEY",
  "ZERION_TOKEN",
] as const;

export function validateEnvironment(
  request: Partial<CloakBridgeRequest>,
  env: NodeJS.ProcessEnv = process.env,
): CloakEnvironmentValidation {
  const suspiciousEnvVarNames = SUSPICIOUS_SECRET_ENV_NAMES.filter((name) => {
    const value = env[name];
    return value !== undefined && value.length > 0;
  });
  const hasRpcUrl = Boolean(env.SOLANA_RPC_URL && env.SOLANA_RPC_URL.length > 0);
  const requestedNetwork = request.network;
  const rpc = resolveCloakRPCConfiguration(undefined, env);

  return {
    solanaRpcUrlStatus: hasRpcUrl ? "present-redacted" : "missing",
    rpcUrlRedacted: hasRpcUrl ? "SOLANA_RPC_URL configured (redacted)" : undefined,
    rpcProvider: rpc.provider,
    rpcHost: rpc.host,
    rpcFastTokenStatus: rpc.tokenStatus,
    rpcMessage: rpc.message,
    requestedNetwork,
    networkSupportedForFutureExecution: requestedNetwork === "mainnet-beta",
    helperMode: "dry-run-non-executing",
    executionCommandsLocked: true,
    keypairPathRequired: false,
    walletSecretEnvAccepted: false,
    suspiciousEnvVarNames,
  };
}
