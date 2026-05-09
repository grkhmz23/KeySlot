const FORBIDDEN_FIELD_TOKENS = [
  "privatekey",
  "secretkey",
  "seedphrase",
  "seed phrase",
  "mnemonic",
  "walletjson",
  "wallet json",
  "signingseed",
  "transactionpayload",
  "serializedtransaction",
  "unsignedtransaction",
  "instructionpayload",
];

export const SUSPICIOUS_SECRET_ENV_NAMES = [
  "PRIVATE_KEY",
  "SECRET_KEY",
  "SEED_PHRASE",
  "MNEMONIC",
  "WALLET_JSON",
  "SIGNING_SEED",
  "MARGINFI_PRIVATE_KEY",
  "MARGINFI_SECRET_KEY",
] as const;

export function hasForbiddenField(key: string): boolean {
  const normalized = key.replace(/[_\-\s]/g, "").toLowerCase();
  return FORBIDDEN_FIELD_TOKENS.some((token) => normalized.includes(token.replace(/[_\-\s]/g, "")));
}

export function validateNoForbiddenFields(value: unknown): void {
  walk(value, []);
}

function walk(value: unknown, path: string[]): void {
  if (Array.isArray(value)) {
    value.forEach((item, index) => walk(item, [...path, String(index)]));
    return;
  }

  if (!value || typeof value !== "object") {
    return;
  }

  for (const [key, nested] of Object.entries(value as Record<string, unknown>)) {
    if (hasForbiddenField(key)) {
      throw new Error(`Forbidden field rejected: ${[...path, key].join(".")}`);
    }
    walk(nested, [...path, key]);
  }
}

export function redactedRpcStatus(rpcUrl?: string): { status: "missing" | "present-redacted"; redacted?: string } {
  if (!rpcUrl) {
    return { status: "missing" };
  }
  return { status: "present-redacted", redacted: "RPC URL configured (redacted)" };
}

export function suspiciousEnvNames(env: NodeJS.ProcessEnv = process.env): string[] {
  return SUSPICIOUS_SECRET_ENV_NAMES.filter((name) => env[name] !== undefined);
}

export function redactStderr(value: string): string {
  if (!value) {
    return "";
  }
  const lowered = value.toLowerCase();
  if (FORBIDDEN_FIELD_TOKENS.some((token) => lowered.includes(token))) {
    return "[redacted marginfi helper stderr]";
  }
  return value.slice(0, 500);
}
