# GORKH Private Vault v0.1

GORKH Private Vault is a software-secured wallet type that derives Solana keypairs from a recovery phrase combined with a required vault passphrase. It provides an additional layer of protection by requiring both the recovery phrase and the vault passphrase for wallet restoration.

## Overview

GORKH Private Vault uses BIP39 passphrase-based derivation to create a distinct wallet from the same recovery phrase. The same recovery phrase with different vault passphrases will derive completely different wallet addresses.

**Important:** This is NOT a hardware wallet. It is a software wallet with passphrase-based key derivation. GORKH cannot recover your secrets if you lose either the recovery phrase or the vault passphrase.

## Architecture

### Derivation Flow

```
Recovery Phrase (BIP39 Mnemonic)
    +
Vault Passphrase (User-provided)
    ↓
BIP39 Seed (PBKDF2-HMAC-SHA512)
    ↓
SLIP-0010 Ed25519 Derivation
    ↓
Solana Keypair (32-byte seed)
    ↓
Public Address
```

### Key Components

1. **WalletOrigin.gorkhPrivateVault**: New wallet origin type for Private Vault wallets
2. **WalletProfileKind.gorkhPrivateVault**: New profile kind with signing capability
3. **SolanaDerivationService**: Extended with passphrase-aware derivation methods
4. **WalletManager**: New methods for Private Vault creation and restoration
5. **PrivateVaultError**: Validation errors for empty passphrase and confirmation mismatch

### Storage

- **Recovery Phrase**: Never stored. User must backup securely.
- **Vault Passphrase**: Never stored. User must remember or backup securely.
- **Derived Seed**: Stored in Keychain using existing `KeychainWalletVault`
- **Wallet Metadata**: Stored in Application Support (public address, derivation path, wallet kind)

## Security Model

### What It Protects Against

1. **Unauthorized Recovery**: An attacker with only the recovery phrase cannot restore the wallet without the vault passphrase
2. **Phrase Compromise**: If the recovery phrase is compromised but the passphrase remains secret, the wallet cannot be restored
3. **Distinct Addresses**: Same phrase with different passphrases creates completely different wallets, providing plausible deniability

### What It Does NOT Protect Against

1. **Keyloggers**: If both the phrase and passphrase are captured during entry, the wallet can be compromised
2. **Malware**: Malicious software with system access can extract the derived seed from Keychain
3. **Physical Access**: An unlocked wallet on an unlocked Mac can be accessed
4. **Forgotten Passphrase**: GORKH cannot recover a forgotten vault passphrase
5. **Social Engineering**: Users can be tricked into revealing both secrets

### Threat Model

**Attacker Capabilities:**
- May obtain the recovery phrase through various means (phishing, shoulder surfing, insecure backup)
- May attempt brute-force attacks on the passphrase
- May have physical access to the device when locked
- May deploy malware or keyloggers

**Security Boundaries:**
- Recovery phrase + vault passphrase are required for restoration
- Derived seed is protected by macOS Keychain
- Signing requires wallet unlock + optional LocalAuthentication
- Mainnet transactions require explicit confirmation phrases
- No secrets in logs, audit events, UserDefaults, or UI state

**Out of Scope:**
- Hardware wallet security (this is software-based)
- Multi-party computation (MPC)
- Social recovery or guardians
- On-chain vault programs
- Autonomous signing or Agent execution

## User Experience

### Creating a Private Vault

**UI Location:** Wallet → Create GORKH Private Vault (shown when no wallets exist)

**Flow:**
1. User opens the "Create GORKH Private Vault" panel
2. Security explanation is displayed prominently
3. User enters a wallet label (optional, defaults to "GORKH Private Vault")
4. User selects derivation path (defaults to `m/44'/501'/0'/0'`)
5. User clicks "Generate Recovery Phrase"
6. System displays the 12-word recovery phrase
7. User must acknowledge they wrote down the phrase
8. User enters a vault passphrase (non-empty required)
9. User confirms the vault passphrase (must match)
10. User clicks "Preview Address" to see the derived public address
11. User must acknowledge they understand both phrase and passphrase are required
12. User proceeds to confirmation screen
13. User confirms random words from the recovery phrase
14. System creates the wallet and stores the seed in Keychain
15. Sensitive state is cleared from memory

**Warning Displayed:**
> "GORKH Private Vault is a software-secured wallet protected by a recovery phrase and a vault passphrase. You need both to recover this wallet. It is not a hardware wallet, and GORKH cannot recover your secrets."

**UI Components:**
- `PrivateVaultCreateView.swift`: Main creation flow
- `RecoveryPhraseView.swift`: Secure phrase display (reused)
- `RecoveryPhraseConfirmationView.swift`: Phrase verification (reused)
- `DerivationPathPicker.swift`: Path selection (reused)

### Restoring a Private Vault

**UI Location:** Wallet → Restore GORKH Private Vault (shown when no wallets exist)

**Flow:**
1. User opens the "Restore GORKH Private Vault" panel
2. Security explanation is displayed prominently
3. User enters a wallet label (optional, defaults to "Restored Private Vault")
4. User enters the recovery phrase in a secure field
5. User enters the vault passphrase in a secure field
6. User selects derivation path (defaults to `m/44'/501'/0'/0'`)
7. User clicks "Preview Address" to see the derived public address
8. System validates the mnemonic format
9. System derives and displays the public address
10. User must acknowledge this is the correct address
11. User clicks "Restore Private Vault"
12. System saves the wallet and stores the seed in Keychain
13. Sensitive state is cleared from memory

**Important:** Wrong passphrase will derive a different address, not an error. This is by design (plausible deniability).

**UI Components:**
- `PrivateVaultRestoreView.swift`: Main restoration flow
- `DerivationPathPicker.swift`: Path selection (reused)

**Agent Behavior:**
- Agent detects "restore private vault" intents
- Agent routes to Wallet UI with handoff message
- Agent does NOT process mnemonic or passphrase text
- If user types secrets into chat, Agent redacts and refuses
- Agent instructs user to use the secure Wallet screen

### Signing Behavior

Private Vault signing follows the same approval stack as standard wallets:

1. Draft/proposal creation
2. Policy check
3. Simulation (where applicable)
4. Shield Review
5. Explicit approval
6. LocalAuthentication (if enabled)
7. Native signing

**Additional Safeguards:**
- Private Vault badge shown on signing review screens
- Mainnet signing requires exact confirmation phrase
- Agent cannot sign with Private Vault wallets
- Developer Workstation cannot use Private Vault for program operations
- Zerion cannot use Private Vault wallets
- Cloak execution uses separate approval flow

## Implementation Details

### Derivation

```swift
// Standard wallet (no passphrase)
let standardKeypair = try derivationService.deriveKeypair(
    mnemonic: mnemonic,
    path: .defaultSolana
)

// Private Vault (with passphrase)
let privateVaultKeypair = try derivationService.deriveKeypair(
    mnemonic: mnemonic,
    vaultPassphrase: vaultPassphrase,
    path: .defaultSolana
)

// These will have DIFFERENT public addresses
```

### Validation

- Empty passphrase is rejected for Private Vault creation/restoration
- Passphrase confirmation must match during creation
- Mnemonic format validation remains strict (BIP39 English wordlist)
- Wrong passphrase derives a different address (not an error)

### Audit Logging

Audit logs record:
- Wallet creation/restoration events
- Wallet kind: `gorkhPrivateVault`
- Public address
- Derivation path
- Timestamp
- Result (success/failure)

Audit logs NEVER record:
- Recovery phrase or any word from it
- Vault passphrase
- Private key or seed
- Raw secret material

### Agent Safety

The Agent may detect intents like:
- "create private vault"
- "restore private vault"
- "send from private vault"

The Agent:
- Routes/handoffs to the Wallet UI
- Does NOT collect, process, store, or send mnemonic/passphrase text
- Redacts seed phrase or passphrase if user types it into chat
- Instructs user to use the secure Wallet screen

## Testing

### Unit Tests

**PrivateVaultDerivationTests.swift:**
- Same mnemonic + same passphrase → same address
- Same mnemonic + different passphrase → different address
- Mnemonic without passphrase ≠ Private Vault address
- Empty passphrase = standard derivation (BIP39 behavior)
- Standard wallet derivation unchanged
- Different derivation paths work correctly
- Passphrase case sensitivity
- Special characters and Unicode in passphrases
- Invalid mnemonic handling

**PrivateVaultSecurityTests.swift:**
- Audit logs do not contain mnemonic
- Audit logs do not contain passphrase
- Audit logs do not contain private keys
- Wallet profile metadata contains no secrets
- Serialization does not leak secrets
- Empty passphrase is rejected for Private Vault
- Watch-only wallets cannot become Private Vaults
- Standard wallet creation unaffected

### Manual QA Checklist

See `docs/qa/private-vault-smoke.md` for detailed smoke test procedures.

## Backup Instructions

### What to Backup

1. **Recovery Phrase**: 12 or 24 words in exact order
2. **Vault Passphrase**: Exact passphrase including case, spaces, special characters
3. **Derivation Path**: Usually `m/44'/501'/0'/0'` (default Solana)
4. **Public Address**: For verification after restoration

### Backup Methods

**Recommended:**
- Write recovery phrase on paper, store in secure location
- Write vault passphrase separately, store in different secure location
- Consider using a password manager for the vault passphrase
- Test restoration on a separate device before relying on backups

**NOT Recommended:**
- Storing both phrase and passphrase together
- Digital photos of recovery phrase
- Cloud storage without encryption
- Email or messaging apps
- Shared documents

### Recovery Testing

1. Create a Private Vault with small test amount
2. Backup recovery phrase and vault passphrase
3. Delete the wallet from GORKH
4. Restore using backups
5. Verify the public address matches
6. Only then use for significant funds

## Comparison with Other Wallet Types

| Feature | Standard Wallet | Recovery Wallet | Private Vault | Watch-Only |
|---------|----------------|-----------------|---------------|------------|
| Signing | ✅ | ✅ | ✅ | ❌ |
| Recovery Phrase | ❌ | ✅ | ✅ | ❌ |
| Vault Passphrase | ❌ | ❌ | ✅ (Required) | ❌ |
| Keychain Storage | ✅ | ✅ | ✅ | ❌ |
| LocalAuth Support | ✅ | ✅ | ✅ | ❌ |
| Mainnet Protection | ✅ | ✅ | ✅ | N/A |
| Agent Signing | ❌ | ❌ | ❌ | ❌ |

## Future Enhancements (Out of Scope for v0.1)

- Hardware wallet integration
- Multi-signature support
- Social recovery mechanisms
- On-chain vault programs
- Biometric-only unlock
- Time-locked recovery
- Passphrase strength meter
- Passphrase hints (with security warnings)

## References

- BIP39: Mnemonic code for generating deterministic keys
- SLIP-0010: Universal private key derivation from master private key
- Solana derivation path: `m/44'/501'/0'/0'`
- GORKH Wallet Architecture: `docs/architecture/rpcfast-wallet-infrastructure.md`
- GORKH Security Policy: `apps/macos/GORKH/GORKH/Core/Wallet/WalletSecurityPolicy.swift`

## Version History

- **v0.1** (2026-05-13): Initial implementation
  - BIP39 passphrase-based derivation
  - Create and restore Private Vault
  - Keychain-backed storage
  - Audit log redaction
  - Comprehensive test coverage
  - Agent redaction support
