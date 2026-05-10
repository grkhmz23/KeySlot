# Zerion Agent Video Script

Target length: 3 to 5 minutes.

## 1. Problem

"Wallet automation is useful, but normal agent designs are too risky when they can touch a primary wallet directly. GORKH separates intent, policy, review, and execution."

Show:

- GORKH Wallet overview.
- Agent top-level section.
- Safety banner.

## 2. GORKH Agent Overview

"The Agent can summarize, explain, and draft. It cannot sign, trade directly from chat, or use the GORKH main wallet."

Show:

- Agent Chat.
- Zerion Executor.
- Policy Center.
- Proposals.
- Audit.

## 3. Zerion Policy Setup

"The execution wallet is a separate tiny-funded Zerion wallet. Zerion policy and token setup happen manually, then GORKH reads the status."

Show:

- CLI installed.
- API key redacted.
- Agent token status redacted.
- Scoped policy status.
- Node.js 20+ status.

## 4. Agent Request

User prompt:

`zerion swap 1 USDC to ETH on base`

Narration:

"The chat creates a proposal. It does not execute. The deterministic policy engine still decides whether this can proceed."

Show:

- Intent card.
- Proposal card.
- Policy decision.

## 5. Review And Approval

"The review screen shows the separate wallet, chain, amount, policy, local cap, and redacted command preview. The user must type the exact phrase before execution."

Show:

- Zerion tiny swap review.
- Redacted command preview.
- Exact confirmation phrase.
- Any blockers if setup is incomplete.

## 6. Zerion Execution Layer

"After approval, GORKH calls the fixed Zerion CLI swap command. There is no arbitrary terminal input and no GORKH main-wallet signer involved."

Show:

- Execution result.
- Transaction hash/signature if a live demo is performed.
- Audit event.

## 7. Why This Matters

"This is an agent operator model that keeps user funds behind separate wallet boundaries, scoped policy, tiny local caps, explicit approval, and auditability."

Close with:

- Policy/token cleanup reminder.
- Repo and docs paths.
- Note that the live transaction claim requires a recorded transaction hash/signature.
