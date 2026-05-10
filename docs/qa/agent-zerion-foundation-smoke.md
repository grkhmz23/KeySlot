# Agent Zerion Foundation Smoke

Phase A1 smoke validates Agent and Zerion readiness only. It must not execute trades, signing, transfers, policy creation, token creation, or wallet import.

## Preconditions

- Node.js 20+ installed if you want to use the Zerion CLI.
- Zerion CLI installed manually:

```sh
npm install -g zerion-cli
```

or initialized manually:

```sh
npx -y zerion-cli init -y --browser
```

- `ZERION_API_KEY` may be set in the local terminal environment only.
- Do not add `ZERION_API_KEY` or agent tokens to Xcode schemes.
- Do not use a GORKH wallet recovery phrase, private key, wallet file, or signing seed with Zerion.

## App Smoke

1. Launch GORKH.
2. Open Agent from the top-level sidebar.
3. Confirm sections are visible: Overview, Zerion Executor, Policy Center, Proposals, Audit.
4. Confirm the safety banner says the Agent cannot directly sign, execute, trade, or use the main wallet without explicit approval.
5. Open Zerion Executor.
6. Click Refresh Read-Only Status.
7. Confirm CLI status is installed, missing, unavailable, or error without exposing secrets.
8. Confirm API key status is Present, Missing, or Malformed without displaying the key.
9. Confirm agent token status never displays token material.
10. Open Policy Center and confirm existing policy/token status is read-only.
11. Open Proposals and confirm every proposal is draft-only.
12. Open Audit and confirm only safe summaries are shown.

## Manual Zerion Setup

Create the Zerion wallet, policy, and token manually outside GORKH. Recommended policy shape for future A2 testing:

- tiny-funded separate wallet,
- narrow chain list,
- short expiry,
- deny transfers unless the A2 scenario explicitly needs one,
- deny approvals unless explicitly needed,
- allowlist only the target protocol/recipient for the tiny transaction.

Agent tokens are spending power. Treat them like API keys and rotate immediately if exposed.

## Forbidden During A1

Do not run from GORKH:

- Zerion trading commands
- Zerion signing commands
- wallet create/import/fund/backup/delete/sync
- agent policy/token creation or revocation
- arbitrary terminal commands

## Validation Commands

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -scheme GORKH -project apps/macos/GORKH/GORKH.xcodeproj build
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -scheme GORKH -project apps/macos/GORKH/GORKH.xcodeproj test -only-testing:GORKHTests
git diff --check
git ls-files '*xcuserdata*' '*.xcuserstate' '.gorkh-devnet-smoke/*'
```

Secret hygiene:

```sh
rg -n "ZERION_API_KEY|agent token|WALLET_PRIVATE_KEY|EVM_PRIVATE_KEY|SOLANA_PRIVATE_KEY|TEMPO_PRIVATE_KEY" apps/macos/GORKH/GORKH.xcodeproj/xcshareddata docs scripts
```

Expected:

- environment variable names may appear in docs/tests/config references,
- no API key values are committed,
- no agent token values are committed,
- no GORKH wallet secrets are referenced by Zerion code.

## A2 Gate

Do not proceed to a real tiny transaction until the CLI, API key, policy, token, and separate wallet status are visible and verified in GORKH.
