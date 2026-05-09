export const RPCFAST_MAINNET_HTTP_URL = "https://solana-rpc.rpcfast.com/";
export const PUBLIC_MAINNET_HTTP_URL = "https://api.mainnet-beta.solana.com";

export type CloakRPCProvider = "rpcfast" | "fallback";
export type CloakRPCTokenStatus = "present" | "missing";

export type CloakRPCConfiguration = {
  endpoint: string;
  provider: CloakRPCProvider;
  host: string;
  tokenStatus: CloakRPCTokenStatus;
  httpHeaders?: Record<string, string>;
  message: string;
};

export function resolveCloakRPCConfiguration(
  requestedUrl?: string,
  env: NodeJS.ProcessEnv = process.env,
): CloakRPCConfiguration {
  if (requestedUrl && /^https:\/\/.+/.test(requestedUrl)) {
    const host = safeHost(requestedUrl);
    return {
      endpoint: requestedUrl,
      provider: "fallback",
      host,
      tokenStatus: "missing",
      message: `Using approved request RPC host ${host}.`,
    };
  }

  const token = rpcFastMainnetToken(env);
  if (token) {
    return {
      endpoint: RPCFAST_MAINNET_HTTP_URL,
      provider: "rpcfast",
      host: safeHost(RPCFAST_MAINNET_HTTP_URL),
      tokenStatus: "present",
      httpHeaders: { "X-Token": token },
      message: "Using RPC Fast mainnet endpoint with X-Token header.",
    };
  }

  if (env.SOLANA_RPC_URL && /^https:\/\/.+/.test(env.SOLANA_RPC_URL)) {
    const host = safeHost(env.SOLANA_RPC_URL);
    return {
      endpoint: env.SOLANA_RPC_URL,
      provider: "fallback",
      host,
      tokenStatus: "missing",
      message: `RPC Fast token missing; using SOLANA_RPC_URL host ${host}.`,
    };
  }

  return {
    endpoint: PUBLIC_MAINNET_HTTP_URL,
    provider: "fallback",
    host: safeHost(PUBLIC_MAINNET_HTTP_URL),
    tokenStatus: "missing",
    message: "RPC Fast token missing; using fallback public mainnet RPC.",
  };
}

export function rpcFastMainnetToken(env: NodeJS.ProcessEnv = process.env): string | undefined {
  const preferred = env.GORKH_RPCFAST_MAINNET_TOKEN?.trim();
  if (preferred) {
    return preferred;
  }
  const fallback = env.RPCFAST_MAINNET_TOKEN?.trim();
  return fallback || undefined;
}

export function safeHost(value: string): string {
  try {
    return new URL(value).host;
  } catch {
    return "unavailable";
  }
}
