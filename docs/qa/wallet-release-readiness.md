# Wallet Release Readiness

Phase W3 validates the Wallet production shell with safe seeded/demo data and documents the remaining manual release checks. It does not add protocol integrations or execution paths.

## Seeded Demo Strategy

- Use `WalletDemoState.releaseQA` for deterministic UI/test coverage.
- Demo wallets are public watch-only addresses only.
- Demo balances are marked `mock-display-only`.
- Demo state is disabled by default and has execution disabled.
- No local environment values, wallet recovery material, or funded signing accounts are included.

## Screens Checked

The W3 source/test pass covers the Wallet navigation order and screen identifiers for:

- Overview
- Portfolio
- Send
- Swap
- Private
- Security
- Activity
- Receive

The visible local app launch from W2 confirmed the default dark graphite shell, sane window size, inspector presence, and no-wallet setup state. W3 keeps the remaining full-screen screenshot pass as manual follow-up because local focus/accessibility limitations prevented reliable automated navigation screenshots.

## Build And Test Commands

Run before a release candidate:

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -scheme GORKH -project apps/macos/GORKH/GORKH.xcodeproj build
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -scheme GORKH -project apps/macos/GORKH/GORKH.xcodeproj test -only-testing:GORKHTests
git diff --check
git ls-files '*xcuserdata*' '*.xcuserstate' '.gorkh-devnet-smoke/*'
```

## Manual Smoke Steps

1. Launch the built macOS app and confirm the window opens at 1360x860 or a similar sane size.
2. Check navigation order: Overview, Portfolio, Send, Swap, Private, Security, Activity.
3. Open Receive and confirm only the public address, optional amount, and optional note are copied.
4. Confirm watch-only wallets show Overview, Portfolio, and Activity only.
5. Confirm missing RPC Fast token state is degraded without showing a token value.
6. Confirm mainnet warning copy is visible before real execution surfaces.
7. Confirm Activity is the primary user-facing label and technical audit details are hidden behind disclosure.
8. Confirm PnL copy describes estimates and incomplete data rather than official accounting.

## Real-World Validation Still Required

These checks require a controlled real wallet or owned position and were not run automatically:

- Cloak tiny mainnet deposit/withdraw/scan.
- Orca harvest with an owned LP position.
- PUSD balance/send smoke.
- Jupiter tiny swap if desired.
- RPC Fast token read-path smoke.

Do not run mainnet smoke automatically. Use small amounts, explicit user approval, LocalAuthentication, simulation where required, and the mainnet confirmation phrase.

## Agent/Zerion Demo Validation

Agent/Zerion status:

- A1 Agent + Zerion Executor foundation: implemented.
- A2 Zerion tiny swap proposal/review/execution flow: implemented, live transaction not automatically run.
- A3 Agent Chat + policy-gated wallet operator: implemented.
- A4 Hosted Agent chat: implemented with local safe fallback.
- A5 Hosted Agent API contract/mock smoke: implemented.
- A6 Hosted Agent remote smoke/failure-mode QA: implemented, remote endpoint smoke pending unless `GORKH_AGENT_API_BASE_URL` is configured locally.
- A7 Demo pack: runbook, policy templates, video script, submission summary, and E2E smoke checklist.
- A8 Rehearsal: blocked on local setup because Zerion CLI was not resolved in PATH and `ZERION_API_KEY` was missing. No live transaction was run.

Before hackathon submission, collect:

- Zerion live tiny transaction hash/signature, if performed.
- Policy setup screenshot/checklist with secrets redacted.
- Agent/Zerion status screenshot showing CLI, API key, policy, and token redacted states.
- Proposal review screenshot showing separate Zerion wallet, scoped policy, local cap, and redacted command preview.
- Agent audit screenshot showing redacted result.
- Confirmation that no keys, agent tokens, wallet files, or local environment values are committed.

Do not claim a live Zerion transaction until the transaction hash/signature is recorded.

## Secret Hygiene

Before release, inspect shared schemes, docs, scripts, helper configs, and package files for secret-like values:

```sh
rg -n "RPCFAST|GORKH_RPCFAST|JUPITER|API_KEY|PRIVATE_KEY|SECRET_KEY|MNEMONIC|SEED|WALLET_JSON" apps/macos/GORKH/GORKH.xcodeproj/xcshareddata docs scripts
```

Expected result:

- Environment variable names may appear in docs/config references.
- No token values, local `.env` values, recovery text, wallet files, or signing material are committed.
- No Xcode user state is committed.

## Release Decision

The Wallet can move to a signed release candidate only after build/tests pass, the visual checklist is completed on a clean machine, and all known release-blocking layout or copy issues are fixed.
