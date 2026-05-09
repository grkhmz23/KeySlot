import type { PublicKey, Transaction, VersionedTransaction } from "@solana/web3.js";

export class ReadOnlyWallet {
  readonly publicKey: PublicKey;

  constructor(publicKey: PublicKey) {
    this.publicKey = publicKey;
  }

  async signTransaction<T extends Transaction | VersionedTransaction>(_transaction: T): Promise<T> {
    throw new Error("MarginFi read-only wallet cannot sign transactions.");
  }

  async signAllTransactions<T extends Transaction | VersionedTransaction>(_transactions: T[]): Promise<T[]> {
    throw new Error("MarginFi read-only wallet cannot sign transactions.");
  }

  async signMessage(_message: Uint8Array): Promise<Uint8Array> {
    throw new Error("MarginFi read-only wallet cannot sign messages.");
  }
}
