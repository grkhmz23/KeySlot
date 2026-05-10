# Agent Full-App Orchestrator

Phase A9 upgrades Agent Chat into a full-app assistant for Wallet, Portfolio, Private, Activity, Security, RPC, and Zerion. It remains an approval-based orchestrator: chat can understand, summarize, draft, and hand off, but it cannot directly execute or sign.

## Scope

The Agent understands these app areas:

- Wallet overview, receive, send drafts, swap drafts, swap explanation, security, activity, and RPC status.
- Portfolio assets, wallet breakdown, PUSD Treasury, Stake/LST, lending, liquidity, yield, PnL/cost basis, and history.
- Cloak status, deposit/private-payment drafts, scan summaries, and local private-state warnings.
- Zerion CLI status, policy status, proposal status, and tiny-swap preparation through the existing review flow.

## Deterministic Source of Truth

`AgentIntentClassifier` and `AgentFullAppIntentClassifier` run before hosted AI. They extract the intent, amount, token, chain, recipient, missing fields, confidence, and risk flags.

Hosted AI may improve explanation text, clarification questions, and proposal copy. It cannot change:

- execution lane,
- policy decision,
- proposal status,
- approval requirements,
- destination handoff,
- Wallet or Zerion safety boundaries.

## Tool Registry

`AgentToolRegistry` declares allowed local tools. Tools are either read-only or draft-only.

Read-only tools include Wallet, Portfolio, PUSD, Stake/LST, lending, liquidity, yield, PnL, activity, security, RPC, Cloak, and Zerion summaries.

Draft-only tools include Wallet swap/send, PUSD payment, Cloak payment, and Zerion tiny swap drafts.

Execution, signing, shell, secret export, bridge, send, and arbitrary command tools are blocked. Blocked tool names may appear in code and tests only as denylist entries.

## Handoffs

Executable requests follow:

intent -> proposal -> policy check -> destination handoff -> existing review/simulation/approval flow -> audit

Handoff targets include Wallet Send, Wallet Swap, Wallet Private, Portfolio sections, Wallet Security, Wallet Activity, and Agent Zerion Review. A handoff changes UI navigation or shows the destination instruction only; it does not build, sign, or submit a transaction.

## Approval Queue

`AgentApprovalQueue` lists draft, blocked, ready-for-review, and handed-off proposals. It is a tracking view, not an execution surface. Buttons only open the destination review module.

## Context Hydration

`AgentContextHydrator` builds minimized context for local tools and hosted AI. It includes safe summaries only:

- redacted wallet display and network,
- aggregate portfolio values,
- PUSD, lending, liquidity, yield, PnL, activity, security, RPC, Cloak, and Zerion status,
- safety metadata.

It excludes wallet secrets, API keys, agent tokens, Cloak private data, raw audit payloads, and transaction payloads.

## Memory

Agent memory is local and stores recent intents, proposal summaries, handoff targets, and safe tool summaries. It stores no secrets, provider keys, raw transaction payloads, private wallet data, or hidden reasoning. Users can clear memory from Agent Chat.

## Security Invariants

- Agent Chat does not execute transactions.
- Main Wallet remains approval-only.
- Zerion remains a separate policy-scoped wallet lane.
- Watch-only wallets are analysis-only.
- Cloak execution remains inside Wallet -> Private.
- Hosted AI is advisory only.
- No arbitrary command input is accepted.
