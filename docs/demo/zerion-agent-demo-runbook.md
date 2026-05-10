# Zerion Agent Demo Runbook

This runbook prepares a safe GORKH Agent + Zerion demo for the hackathon track. It shows that GORKH can create an Agent proposal, validate a scoped Zerion policy, require explicit review, and execute a tiny same-chain swap through Zerion CLI from a separate Zerion wallet.

The demo must not use the GORKH main wallet, native signer, Keychain signer, recovery text, wallet files, or Cloak private state.

## Architecture Overview

- Agent Chat classifies the request and creates a proposal.
- Zerion Executor checks CLI, Node.js, API key status, wallet status, policy status, token status, and swap command shape.
- Policy validation runs locally in GORKH before the review can proceed.
- Zerion CLI is the execution layer for the separate Zerion wallet.
- GORKH main-wallet access stays disabled.
- Activity and Agent audit show redacted status, proposal, approval, command, and result summaries only.

## Required Local Setup

1. Install Node.js 20 or later.
2. Install Zerion CLI:

```sh
npm install -g zerion-cli
```

3. Set the Zerion API key only in the local terminal session:

```sh
read -s ZERION_API_KEY
export ZERION_API_KEY
```

4. Create a separate Zerion wallet manually with the CLI or the official Zerion setup flow.
5. Fund that Zerion wallet with only a tiny demo amount on Solana or Base.
6. Create a scoped policy for the selected chain.
7. Create an agent token bound to that wallet and policy.
8. Open GORKH -> Agent -> Zerion Executor.
9. Refresh status and confirm:
   - CLI is installed,
   - Node.js is version 20 or later,
   - API key status is redacted,
   - a separate wallet is visible,
   - a scoped policy is visible,
   - agent token status is redacted,
   - swap command help is validated.

## Demo Flow

1. Open GORKH -> Agent -> Chat.
2. Ask: `zerion swap 1 USDC to ETH on base` or use the Solana tiny swap path when available.
3. Confirm Agent creates a proposal rather than executing from chat.
4. Open the proposal in Agent -> Proposals.
5. Inspect the Zerion review:
   - separate Zerion wallet,
   - not GORKH main wallet,
   - chain,
   - amount,
   - tokens,
   - policy,
   - local tiny cap,
   - redacted command preview.
6. Type the exact confirmation phrase shown in the app.
7. Execute only after every blocker is gone.
8. Capture the transaction hash/signature returned by Zerion.
9. Open Agent -> Audit and confirm the timeline contains redacted proposal, approval, command, and result summaries.

## Cleanup

1. Revoke the agent token after the demo.
2. Confirm the policy is expired or revoked when no longer needed.
3. Remove the local API key from the terminal session.
4. Keep the demo wallet tiny-funded only.
5. Do not commit screenshots or logs containing tokens, private material, or local environment values.

## Evidence To Record

- CLI/version status screenshot.
- Policy/token status screenshot with secrets redacted.
- Proposal review screenshot.
- Transaction hash/signature after a real approved demo transaction.
- Agent audit screenshot showing redacted result.

Do not claim a live transaction in the submission until the transaction hash/signature is recorded.
