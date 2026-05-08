#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
SWIFTC="$(xcrun --find swiftc)"
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
BINARY_PATH="$(mktemp "${TMPDIR:-/tmp}/gorkh-live-devnet-spl-smoke.XXXXXX")"
MODULE_CACHE_PATH="$(mktemp -d "${TMPDIR:-/tmp}/gorkh-live-devnet-spl-modules.XXXXXX")"
TARGET_ARCH="$(uname -m)"

cleanup() {
  rm -f "$BINARY_PATH"
  rm -rf "$MODULE_CACHE_PATH"
}
trap cleanup EXIT

echo "GORKH live devnet SPL token smoke"
echo "Source: $ROOT_DIR/apps/macos/GORKH/GORKH/Core"
echo "Network: devnet only"
echo "This script uses the gitignored throwaway devnet wallet state and never prints signing material."
echo

rm -f "$BINARY_PATH"
"$SWIFTC" \
  -sdk "$SDKROOT" \
  -target "$TARGET_ARCH-apple-macos26.3" \
  -module-cache-path "$MODULE_CACHE_PATH" \
  -o "$BINARY_PATH" \
  "$ROOT_DIR/apps/macos/GORKH/GORKH/Core/Security/Redaction.swift" \
  "$ROOT_DIR/apps/macos/GORKH/GORKH/Core/Solana/SolanaAddressValidator.swift" \
  "$ROOT_DIR/apps/macos/GORKH/GORKH/Core/Solana/SolanaKeypair.swift" \
  "$ROOT_DIR/apps/macos/GORKH/GORKH/Core/Solana/SolanaNetwork.swift" \
  "$ROOT_DIR/apps/macos/GORKH/GORKH/Core/Solana/ProgramDerivedAddress.swift" \
  "$ROOT_DIR/apps/macos/GORKH/GORKH/Core/Solana/SplTokenModels.swift" \
  "$ROOT_DIR/apps/macos/GORKH/GORKH/Core/Solana/SplTokenParser.swift" \
  "$ROOT_DIR/apps/macos/GORKH/GORKH/Core/Solana/TokenAmountFormatter.swift" \
  "$ROOT_DIR/apps/macos/GORKH/GORKH/Core/Solana/AssociatedTokenAccount.swift" \
  "$ROOT_DIR/apps/macos/GORKH/GORKH/Core/Solana/SplTokenInstructionBuilder.swift" \
  "$ROOT_DIR/apps/macos/GORKH/GORKH/Core/Solana/SolanaRPCClient.swift" \
  "$ROOT_DIR/apps/macos/GORKH/GORKH/Core/Solana/SolanaTransactionBuilder.swift" \
  "$ROOT_DIR/apps/macos/GORKH/GORKH/Core/Wallet/AuditLog.swift" \
  "$ROOT_DIR/apps/macos/GORKH/GORKH/Core/Wallet/WalletModels.swift" \
  "$ROOT_DIR/apps/macos/GORKH/GORKH/Core/Wallet/WalletVault.swift" \
  "$ROOT_DIR/scripts/LiveDevnetSplSmoke.swift"

GORKH_REPO_ROOT="$ROOT_DIR" "$BINARY_PATH" "$@"
