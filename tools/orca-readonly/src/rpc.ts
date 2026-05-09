import type { OrcaReadOnlyRequest } from "./contracts.ts";

const RPCFAST_MAINNET_HOST = "solana-rpc.rpcfast.com";
const RPCFAST_TOKEN_ENV_NAMES = ["GORKH_RPCFAST_MAINNET_TOKEN", "RPCFAST_MAINNET_TOKEN"] as const;

export function rpcHeadersForUrl(rpcUrl?: string, env: NodeJS.ProcessEnv = process.env): Record<string, string> | undefined {
  if (!rpcUrl) {
    return undefined;
  }
  if (!isRpcFastMainnetUrl(rpcUrl)) {
    return undefined;
  }
  const token = rpcFastToken(env);
  return token ? { "X-Token": token } : undefined;
}

export function createRpcWithOptionalHeaders(
  kit: { createSolanaRpc?: (url: string, config?: { headers?: Record<string, string> }) => unknown },
  request: OrcaReadOnlyRequest,
): unknown {
  if (!kit.createSolanaRpc || !request.rpcUrl) {
    throw new Error("Solana Kit RPC factory is unavailable.");
  }
  const headers = rpcHeadersForUrl(request.rpcUrl);
  return headers
    ? kit.createSolanaRpc(request.rpcUrl, { headers })
    : kit.createSolanaRpc(request.rpcUrl);
}

export function redactedRpcFastStatus(rpcUrl?: string, env: NodeJS.ProcessEnv = process.env): {
  rpcProvider: "rpcfast" | "custom" | "missing";
  tokenStatus: "present" | "missing" | "not-required";
} {
  if (!rpcUrl) {
    return { rpcProvider: "missing", tokenStatus: "missing" };
  }
  if (!isRpcFastMainnetUrl(rpcUrl)) {
    return { rpcProvider: "custom", tokenStatus: "not-required" };
  }
  return {
    rpcProvider: "rpcfast",
    tokenStatus: rpcFastToken(env) ? "present" : "missing",
  };
}

function isRpcFastMainnetUrl(rpcUrl: string): boolean {
  try {
    return new URL(rpcUrl).host === RPCFAST_MAINNET_HOST;
  } catch {
    return false;
  }
}

function rpcFastToken(env: NodeJS.ProcessEnv): string | undefined {
  for (const name of RPCFAST_TOKEN_ENV_NAMES) {
    const value = env[name]?.trim();
    if (value) {
      return value;
    }
  }
  return undefined;
}
