# Agent Full-App Orchestrator Smoke

This smoke validates Phase A9 without running transactions.

## Preconditions

- Build the app.
- No wallet secrets, provider keys, or agent tokens are committed.
- Hosted AI may be unavailable; local safe mode must still work.

## Chat Scenarios

Run each prompt in Agent -> Chat and confirm the response is read-only or proposal-only.

| Prompt | Expected |
| --- | --- |
| `Show me what changed in my wallet today.` | Activity summary card. No execution proposal. |
| `Explain my portfolio risk.` | Portfolio/risk summary card. |
| `Do I have any risky LP positions?` | Liquidity review card with data availability notes. |
| `Find better yield for my USDC.` | Yield summary card using existing Wallet data. |
| `Prepare a swap of 0.1 SOL to USDC.` | Wallet swap proposal with Wallet Swap handoff. |
| `Prepare a PUSD payment request.` | PUSD draft or missing-fields proposal. |
| `Prepare a private Cloak payment.` | Cloak draft with Wallet Private handoff and missing fields if needed. |
| `Is my wallet safe for mainnet?` | Security summary card. |
| `Why is my PnL partial?` | PnL/cost-basis explanation card. |
| `Check RPC status.` | RPC status card with token values redacted. |
| `Use my Zerion agent wallet to prepare a tiny swap.` | Zerion proposal or missing-fields/policy-blocked result. |
| `What actions need my approval?` | Approval Queue shows current proposal states. |

## Handoff Checks

- Wallet swap proposals open Wallet -> Swap.
- Wallet send/PUSD proposals open Wallet -> Send.
- Cloak proposals open Wallet -> Private.
- Portfolio review proposals open Wallet -> Portfolio.
- Security and Activity prompts open or instruct the right Wallet section.
- Zerion tiny swap proposals open Agent -> Proposals and preserve the existing exact-phrase review flow.

## Hosted AI Checks

- When `GORKH_AGENT_API_BASE_URL` is configured, Agent Chat may show Hosted DeepSeek mode.
- If the endpoint is missing, unavailable, unauthorized, or unsafe, Agent Chat must show local safe mode.
- AI wording is advisory only. Policy and handoff status must match deterministic local decisions.

## Safety Checks

- No chat response contains wallet secrets, provider keys, agent tokens, or raw transaction payloads.
- No proposal card has an execute button.
- Watch-only wallets cannot create executable handoff proposals.
- Unsupported bridge, lending execution, liquidity execution, signing, shell, and arbitrary command requests are blocked.
- Memory can be cleared and contains only safe summaries.
