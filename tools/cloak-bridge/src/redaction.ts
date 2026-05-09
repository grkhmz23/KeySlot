export const FORBIDDEN_FIELD_TOKENS = [
  "privatekey",
  "secretkey",
  "signingseed",
  "seedphrase",
  "mnemonic",
  "walletjson",
  "wallet_json",
  "utxoprivatekey",
  "utxo_private_key",
  "fullutxo",
  "note",
  "notesecret",
  "viewingkey",
  "nullifier",
  "nullifiersecret",
  "proofinput",
  "serializedtransaction",
  "transactionpayload",
  "transactionbytes",
  "messagebytes",
  "rawtransaction",
  "rawmessage",
  "rawsignerbytes",
] as const;

export function validateNoForbiddenFields(payload: unknown): void {
  walk(payload, []);
}

export function hasForbiddenField(name: string): boolean {
  const normalized = name.toLowerCase().replace(/[\s_-]/g, "");
  return FORBIDDEN_FIELD_TOKENS.some((token) => normalized.includes(token));
}

function walk(value: unknown, path: string[]): void {
  if (Array.isArray(value)) {
    value.forEach((item, index) => walk(item, [...path, String(index)]));
    return;
  }

  if (value !== null && typeof value === "object") {
    for (const [key, child] of Object.entries(value)) {
      if (hasForbiddenField(key)) {
        const location = [...path, key].join(".");
        throw new Error(`forbidden field: ${location}`);
      }
      walk(child, [...path, key]);
    }
  }
}
