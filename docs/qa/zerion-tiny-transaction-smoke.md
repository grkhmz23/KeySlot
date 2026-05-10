# Zerion Tiny Transaction Smoke

Phase A2 supports one real, same-chain, tiny Zerion swap from a separate Zerion wallet. It does not use the GORKH wallet signer.

## Hard Rules

- Do not use the GORKH main wallet.
- Do not paste private keys, seed phrases, wallet JSON, API keys, or agent tokens into the app, docs, screenshots, or logs.
- Do not add `ZERION_API_KEY` or agent tokens to Xcode schemes.
- Do not run bridge, send, sign-message, or sign-typed-data.
- Do not run recurring automation or DCA loops.

## Manual Setup

1. Install Node.js 20 or later.
2. Install Zerion CLI:
   `npm install -g zerion-cli`
3. Export the API key locally:
   `export ZERION_API_KEY=...`
4. Create a separate Zerion wallet manually in terminal.
5. Fund it with only a tiny amount for the selected chain.
6. Create a scoped policy manually:
   - chain restricted to `solana` or `base`,
   - expiry 24h or 7d,
   - deny transfers if possible,
   - deny approvals if possible,
   - allowlist if possible.
7. Create an agent token bound to that wallet and policy.
8. Open GORKH -> Agent -> Zerion Executor.
9. Refresh read/status.
10. Confirm API key, token, policy, wallet, Node.js, and swap help status are visible without secrets.

## Tiny Swap Smoke

Preferred:

- Solana: `SOL -> USDC`, tiny amount.

Fallback:

- Base: `USDC -> ETH`, tiny amount.

Steps:

1. Open Agent -> Proposals.
2. Draft a Solana or Base tiny swap.
3. Select Review.
4. Confirm the review shows:
   - separate Zerion wallet,
   - not GORKH main wallet,
   - policy status,
   - API key/token redacted status,
   - local cap result,
   - redacted command preview.
5. If USD value is unavailable, acknowledge unknown value only for intentionally tiny amounts.
6. Type exactly:
   `I understand this uses a separate Zerion wallet and executes a real onchain transaction.`
7. Execute only if all blockers are gone.
8. Record the returned transaction hash/signature and chain.

## Expected Locked States

Execution must stay blocked when:

- Zerion CLI is missing,
- Node.js is missing or below version 20,
- swap help is missing or ambiguous,
- `ZERION_API_KEY` is missing or malformed,
- agent token is missing,
- policy is missing,
- policy chain does not match,
- proposal is stale,
- amount exceeds the local tiny cap,
- exact phrase is not entered,
- fingerprint changes.

## Post-Smoke Checks

Run:

```bash
xcodebuild -scheme GORKH -project apps/macos/GORKH/GORKH.xcodeproj test -only-testing:GORKHTests
git diff --check
```

Confirm the final audit timeline contains only redacted status, approval, execution, and result summaries.
