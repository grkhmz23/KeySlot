# GORKH Private Vault v0.1 - Smoke Test Checklist

**Test Date:** ___________  
**Tester:** ___________  
**Build:** ___________  
**Platform:** macOS ___________

## Pre-Test Setup

- [ ] Fresh GORKH installation or clean wallet state
- [ ] No existing Private Vault wallets
- [ ] Test recovery phrase prepared: `abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about`
- [ ] Test passphrase prepared: `TestVault2026!`
- [ ] Backup of any existing wallets (if testing on production device)

## 1. Private Vault Creation

### 1.1 Create with Generated Phrase

- [ ] Navigate to wallet creation screen (shown when no wallets exist)
- [ ] Locate "Create GORKH Private Vault" panel
- [ ] Security explanation is displayed with warning icon
- [ ] Enter wallet label (or use default "GORKH Private Vault")
- [ ] Select derivation path (or use default)
- [ ] Click "Generate Recovery Phrase"
- [ ] System generates and displays 12-word recovery phrase
- [ ] Recovery phrase is displayed clearly in RecoveryPhraseView
- [ ] Warning message is displayed: "GORKH Private Vault is a software-secured wallet protected by a recovery phrase and a vault passphrase. You need both to recover this wallet. It is not a hardware wallet, and GORKH cannot recover your secrets."
- [ ] Check "I wrote this recovery phrase down" checkbox
- [ ] Enter vault passphrase: `TestVault2026!`
- [ ] Confirm vault passphrase: `TestVault2026!`
- [ ] Click "Preview Address"
- [ ] Derived public address is displayed
- [ ] Check "I understand both recovery phrase and vault passphrase are required" checkbox
- [ ] Click "Continue to Confirmation"
- [ ] Confirm random words from recovery phrase
- [ ] Wallet is created successfully
- [ ] Public address is displayed
- [ ] Wallet appears in wallet list with "GORKH Private Vault" badge
- [ ] Badge shows lock.shield.fill icon in warning color
- [ ] Wallet overview shows "Protected by recovery phrase + vault passphrase" text
- [ ] Wallet can be selected and is unlocked

**Expected Result:** Private Vault created, unlocked, and ready to use with proper UI badges.

### 1.2 Empty Passphrase Rejection

- [ ] Attempt to create Private Vault
- [ ] Enter recovery phrase
- [ ] Leave vault passphrase empty
- [ ] Attempt to proceed
- [ ] Error message displayed: "GORKH Private Vault requires a non-empty vault passphrase"
- [ ] Wallet is NOT created

**Expected Result:** Empty passphrase is rejected with clear error message.

### 1.3 Passphrase Confirmation Mismatch

- [ ] Attempt to create Private Vault
- [ ] Enter recovery phrase
- [ ] Enter vault passphrase: `TestVault2026!`
- [ ] Enter different confirmation: `TestVault2026`
- [ ] Attempt to proceed
- [ ] Error message displayed about confirmation mismatch
- [ ] Wallet is NOT created

**Expected Result:** Mismatched confirmation is rejected.

## 2. Private Vault Restoration

### 2.1 Restore with Correct Phrase and Passphrase

- [ ] Delete the Private Vault wallet (if exists)
- [ ] Navigate to wallet restoration screen
- [ ] Select "Restore GORKH Private Vault"
- [ ] Enter recovery phrase: `abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about`
- [ ] Enter vault passphrase: `TestVault2026!`
- [ ] System derives and displays the public address
- [ ] Public address matches the original wallet
- [ ] Confirm restoration
- [ ] Wallet is restored successfully
- [ ] Wallet appears in wallet list
- [ ] Wallet can be unlocked

**Expected Result:** Wallet restored with matching public address.

### 2.2 Restore with Wrong Passphrase

- [ ] Delete the Private Vault wallet
- [ ] Navigate to wallet restoration screen
- [ ] Select "Restore GORKH Private Vault"
- [ ] Enter same recovery phrase
- [ ] Enter DIFFERENT vault passphrase: `WrongPassphrase123`
- [ ] System derives and displays a public address
- [ ] Public address is DIFFERENT from the original wallet
- [ ] System does NOT show an error (this is by design)

**Expected Result:** Different passphrase derives different address (no error shown).

### 2.3 Restore with Phrase Only (No Passphrase)

- [ ] Attempt to restore Private Vault
- [ ] Enter recovery phrase
- [ ] Leave vault passphrase empty
- [ ] Attempt to proceed
- [ ] Error message displayed: "GORKH Private Vault requires a non-empty vault passphrase"
- [ ] Wallet is NOT restored

**Expected Result:** Empty passphrase is rejected.

## 3. Derivation Consistency

### 3.1 Same Phrase + Same Passphrase = Same Address

- [ ] Create Private Vault with phrase A and passphrase B
- [ ] Note the public address
- [ ] Delete the wallet
- [ ] Restore with same phrase A and same passphrase B
- [ ] Public address matches exactly

**Expected Result:** Consistent derivation.

### 3.2 Same Phrase + Different Passphrase = Different Address

- [ ] Create Private Vault with phrase A and passphrase B
- [ ] Note the public address (Address 1)
- [ ] Delete the wallet
- [ ] Create Private Vault with same phrase A but passphrase C
- [ ] Note the public address (Address 2)
- [ ] Address 1 ≠ Address 2

**Expected Result:** Different passphrases derive different addresses.

### 3.3 Standard Wallet vs Private Vault

- [ ] Create standard recovery wallet with phrase A (no passphrase)
- [ ] Note the public address (Standard Address)
- [ ] Delete the wallet
- [ ] Create Private Vault with same phrase A and passphrase B
- [ ] Note the public address (Private Vault Address)
- [ ] Standard Address ≠ Private Vault Address

**Expected Result:** Standard wallet and Private Vault have different addresses.

## 4. Security - Audit Logs

### 4.1 Audit Log Inspection

- [ ] Create a Private Vault
- [ ] Open audit log viewer (if available) or export audit logs
- [ ] Search for the wallet creation event
- [ ] Verify audit log contains:
  - [ ] Wallet ID
  - [ ] Public address
  - [ ] Wallet kind: `gorkhPrivateVault`
  - [ ] Derivation path
  - [ ] Timestamp
- [ ] Verify audit log does NOT contain:
  - [ ] Recovery phrase or any word from it
  - [ ] Vault passphrase
  - [ ] Private key or seed
  - [ ] Any base64/hex string longer than 44 characters (potential key material)

**Expected Result:** Audit logs contain safe metadata only, no secrets.

### 4.2 Wallet Metadata Inspection

- [ ] Create a Private Vault
- [ ] Locate wallet metadata file (Application Support directory)
- [ ] Open metadata file in text editor
- [ ] Verify metadata contains:
  - [ ] Wallet ID
  - [ ] Public address
  - [ ] Wallet origin: `gorkh_private_vault`
  - [ ] Profile kind: `gorkh_private_vault`
  - [ ] Derivation path
  - [ ] Created date
- [ ] Verify metadata does NOT contain:
  - [ ] Recovery phrase
  - [ ] Vault passphrase
  - [ ] Private key or seed

**Expected Result:** Metadata contains safe fields only.

## 5. Signing Behavior

### 5.1 Private Vault Signing Flow

- [ ] Create and fund a Private Vault wallet (devnet)
- [ ] Unlock the wallet
- [ ] Draft a SOL transfer transaction
- [ ] Proceed to signing review screen
- [ ] Verify "GORKH Private Vault" badge or indicator is shown
- [ ] Verify simulation runs successfully
- [ ] Approve the transaction
- [ ] LocalAuthentication prompt appears (if enabled)
- [ ] Transaction is signed and sent
- [ ] Transaction signature is displayed
- [ ] Verify transaction on Solana Explorer

**Expected Result:** Private Vault signing works through standard approval flow.

### 5.2 Mainnet Signing Protection

- [ ] Create and fund a Private Vault wallet (mainnet-beta)
- [ ] Unlock the wallet
- [ ] Draft a mainnet SOL transfer
- [ ] Proceed to signing review
- [ ] Mainnet confirmation phrase is required
- [ ] Enter exact phrase: "I understand this is a real mainnet transaction."
- [ ] Transaction can be approved and sent

**Expected Result:** Mainnet protection applies to Private Vault.

### 5.3 Locked Wallet Cannot Sign

- [ ] Create a Private Vault
- [ ] Lock the wallet
- [ ] Attempt to draft a transaction
- [ ] Signing is blocked
- [ ] Error message indicates wallet must be unlocked

**Expected Result:** Locked Private Vault cannot sign.

## 6. Agent Safety

### 6.1 Agent Intent Detection

- [ ] Open Agent chat
- [ ] Type: "create a private vault"
- [ ] Agent recognizes the intent
- [ ] Agent routes to Wallet UI (does not attempt to create directly)
- [ ] Agent does NOT ask for recovery phrase or passphrase in chat

**Expected Result:** Agent routes to UI, does not collect secrets.

### 6.2 Agent Redaction

- [ ] Open Agent chat
- [ ] Type a recovery phrase: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
- [ ] Agent detects seed phrase pattern
- [ ] Agent redacts or refuses to process
- [ ] Agent instructs user to use secure Wallet screen

**Expected Result:** Agent redacts seed phrases typed in chat.

### 6.3 Agent Cannot Sign with Private Vault

- [ ] Create a Private Vault
- [ ] Open Agent chat
- [ ] Request Agent to send SOL from the Private Vault
- [ ] Agent refuses or routes to Wallet UI
- [ ] Agent does NOT sign transactions directly

**Expected Result:** Agent cannot sign with Private Vault.

## 7. Watch-Only Wallet Boundary

### 7.1 Watch-Only Cannot Become Private Vault

- [ ] Add a watch-only wallet
- [ ] Verify wallet is marked as watch-only
- [ ] Verify wallet cannot sign
- [ ] Verify wallet profile kind is `watchOnly`, not `gorkhPrivateVault`
- [ ] Attempt to use watch-only wallet for signing
- [ ] Signing is blocked

**Expected Result:** Watch-only wallets remain non-signing.

## 8. Standard Wallet Unchanged

### 8.1 Standard Wallet Creation

- [ ] Create a standard wallet (not Private Vault)
- [ ] Wallet is created successfully
- [ ] Wallet origin is `legacy_local`, not `gorkh_private_vault`
- [ ] Wallet can sign transactions
- [ ] No passphrase was required

**Expected Result:** Standard wallet creation unaffected.

### 8.2 Standard Recovery Wallet

- [ ] Create a recovery wallet (not Private Vault)
- [ ] Enter recovery phrase only (no passphrase)
- [ ] Wallet is created successfully
- [ ] Wallet profile kind is `recovery_derived`, not `gorkh_private_vault`
- [ ] Wallet can sign transactions

**Expected Result:** Standard recovery wallet unaffected.

## 9. Edge Cases

### 9.1 Passphrase with Special Characters

- [ ] Create Private Vault with passphrase: `Test!@#$%^&*()_+-=[]{}|;':",.<>?`
- [ ] Wallet is created successfully
- [ ] Delete and restore with same passphrase
- [ ] Public address matches

**Expected Result:** Special characters in passphrase work correctly.

### 9.2 Passphrase with Unicode

- [ ] Create Private Vault with passphrase: `パスワード🔐密码`
- [ ] Wallet is created successfully
- [ ] Delete and restore with same passphrase
- [ ] Public address matches

**Expected Result:** Unicode in passphrase works correctly.

### 9.3 Passphrase with Whitespace

- [ ] Create Private Vault with passphrase: `my vault passphrase` (single spaces)
- [ ] Note the public address
- [ ] Delete the wallet
- [ ] Attempt to restore with: `my  vault  passphrase` (double spaces)
- [ ] Public address is DIFFERENT

**Expected Result:** Whitespace matters in passphrase.

### 9.4 Very Long Passphrase

- [ ] Create Private Vault with 100+ character passphrase
- [ ] Wallet is created successfully
- [ ] Delete and restore with same passphrase
- [ ] Public address matches

**Expected Result:** Long passphrases work correctly.

## 10. Backup and Recovery

### 10.1 Backup Instructions

- [ ] Create a Private Vault
- [ ] Backup instructions are displayed or accessible
- [ ] Instructions clearly state:
  - [ ] Backup recovery phrase separately
  - [ ] Backup vault passphrase separately
  - [ ] Do not store both together
  - [ ] Test recovery before relying on backups

**Expected Result:** Clear backup instructions provided.

### 10.2 Recovery Testing

- [ ] Create a Private Vault with small test amount
- [ ] Backup recovery phrase and passphrase
- [ ] Delete the wallet
- [ ] Restore using backups
- [ ] Public address matches
- [ ] Wallet can sign transactions

**Expected Result:** Recovery process works as documented.

## 11. Performance

### 11.1 Derivation Performance

- [ ] Create a Private Vault
- [ ] Derivation completes in < 2 seconds
- [ ] UI remains responsive

**Expected Result:** Acceptable performance.

### 11.2 Restoration Performance

- [ ] Restore a Private Vault
- [ ] Restoration completes in < 2 seconds
- [ ] UI remains responsive

**Expected Result:** Acceptable performance.

## 12. Unit Tests

### 12.1 Run Unit Tests

- [ ] Run `PrivateVaultDerivationTests`
- [ ] All tests pass
- [ ] Run `PrivateVaultSecurityTests`
- [ ] All tests pass

**Expected Result:** All unit tests pass.

## Test Summary

**Total Tests:** ___________  
**Passed:** ___________  
**Failed:** ___________  
**Blocked:** ___________  

**Critical Issues Found:**

**Non-Critical Issues Found:**

**Notes:**

**Sign-off:**

Tester: ___________ Date: ___________  
Reviewer: ___________ Date: ___________
