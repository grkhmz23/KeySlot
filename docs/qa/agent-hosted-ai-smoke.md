# Agent Hosted AI Smoke

This smoke validates the A4 hosted Agent Chat boundary. It does not execute transactions.

## Setup

The hosted endpoint is optional for local development:

```sh
export GORKH_AGENT_API_BASE_URL=https://your-gorkh-agent.example
```

If app-to-backend authentication is required, set it only in the local shell:

```sh
export GORKH_AGENT_API_KEY=...
```

Do not put endpoint secrets in Xcode schemes, docs, screenshots, or logs.

## Local Safe Mode

1. Launch GORKH without `GORKH_AGENT_API_BASE_URL`.
2. Open Agent -> Chat.
3. Confirm the AI status shows Local Safe Mode.
4. Ask `summarize my portfolio`.
5. Confirm the deterministic local summary appears.
6. Confirm no crash and no proposal execution.

## Hosted Mode

1. Launch GORKH from a shell with `GORKH_AGENT_API_BASE_URL`.
2. Open Agent -> Chat.
3. Ask `find safer yield for USDC`.
4. Confirm the hosted response is shown if the endpoint is reachable.
5. Confirm the local Yield analysis card still uses existing Wallet data.
6. Confirm any proposal remains a draft or handoff only.

## Redaction Block

1. Enter a message containing a forbidden secret-like field.
2. Confirm the hosted request is blocked.
3. Confirm Agent falls back to local policy handling.
4. Confirm the audit timeline records a redaction block without storing the secret text.

## Tool Boundary

Use a hosted test response that suggests a blocked tool such as `executeSwap` or `sendTransaction`.

Expected:

- the tool suggestion is blocked,
- the AI status is degraded,
- the audit timeline records the blocked tool,
- no Wallet, Zerion, or Cloak execution starts.

## Proposal Safety

1. Ask `buy this token for 0.1 SOL`.
2. Confirm the classifier asks for the missing token.
3. Ask `swap 1 USDC to SOL`.
4. Confirm a Wallet handoff proposal is created.
5. Confirm the button opens Wallet -> Swap, where existing quote, simulation, approval, signing, and audit gates apply.

## Zerion Safety

1. Ask `zerion swap 1 USDC to ETH on base`.
2. Confirm the proposal routes to the existing A2 Zerion tiny-swap review.
3. Confirm bridge, send, signing, and arbitrary command requests remain blocked.

## Hygiene

Run:

```sh
rg -n "GORKH_AGENT_API_KEY|GORKH_AGENT_API_BASE_URL" apps/macos/GORKH/GORKH.xcodeproj/xcshareddata docs scripts
```

Expected:

- env var names may appear in docs,
- no secret values appear,
- shared Xcode schemes contain no environment variables.

