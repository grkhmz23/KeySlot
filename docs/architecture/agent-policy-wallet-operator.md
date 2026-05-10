# Agent Policy Wallet Operator

Phase A3 adds a deterministic Agent chat/operator layer for Wallet and Zerion workflows. The Agent can classify requests, summarize existing wallet data, create proposal cards, and hand the user to the correct destination module. It does not execute transactions from chat.

Phase A4 adds a hosted AI explanation layer backed by DeepSeek through GORKH's hosted endpoint. The hosted model is advisory only: deterministic classification, local policy, proposal creation, and destination approval remain authoritative.

## Source Guidance

The local Zerion documentation in `/Users/gorkhmazbeydullayev/Downloads/zerion-docs.md` was reviewed for the A3 boundary. It confirms JSON-first CLI behavior, `ZERION_API_KEY`, manual wallet and policy setup, agent-token spending power, policy flags, and the distinction between read/status commands and trading commands. A3 does not add new Zerion command families; executable Zerion swap intents are routed to the existing A2 tiny-swap review flow.

## Execution Lanes

Main GORKH Wallet:

- Allowed: observe, summarize, draft swap/send/payment/private-payment intent, and hand off.
- Not allowed: chat signing, instant execution, or bypassing Wallet approval.
- Destination approval remains Wallet Send, Wallet Swap, or Wallet Private.

Zerion Agent Wallet:

- Allowed: create a tiny same-chain swap proposal when the user explicitly asks for the Zerion or policy wallet lane.
- Not allowed: arbitrary CLI arguments, bridge/send/sign commands, or GORKH main-wallet access.
- Destination approval remains Agent -> Proposals -> Zerion review.

Watch-only wallets:

- Allowed: analyze, summarize, compare yield, review LP positions, and explain risk.
- Not allowed: executable handoff proposals.

Cloak Private:

- Allowed: prepare private-payment draft and route to Wallet -> Private.
- Not allowed: private payment execution from chat.

## Deterministic Classifier

`AgentIntentClassifier` maps plain-language requests to local intent types:

- Wallet overview, receive address, prepare send, prepare swap, swap explanation, security status, activity summary, and RPC status
- Portfolio assets, wallets, PUSD Treasury, Stake/LST, lending, liquidity, yield, PnL/cost basis, and history
- Cloak status, deposit/private-payment drafts, scan summary, and private-state explanation
- Zerion status, policy summary, tiny-swap preparation, and proposal status
- portfolio summary
- risk summary
- token buy request
- token swap request
- token send request
- PUSD payment request
- Cloak private payment request
- yield search
- LP position review
- PnL summary
- recent activity summary
- Zerion tiny swap request
- unsupported
- unsafe

The classifier extracts amount, source asset, target asset, chain, recipient, confidence, missing fields, and risk flags. Low-confidence or incomplete executable requests become missing-field proposals, not executable requests.

Hosted AI may improve the explanation or wording after this classifier runs, but it cannot override the local classification or approve execution.

Phase A9 adds `AgentFullAppIntentClassifier`, `AgentToolRegistry`, `AgentToolExecutor`, `AgentApprovalQueue`, and `AgentHandoffCoordinator`. These components make Agent Chat a full-app orchestrator while preserving the same policy boundary: read-only tools return summaries, draft tools create proposal cards, and all executable flows continue through the destination module.

## Policy Engine

`AgentPolicyEngine` enforces local rules before a proposal can become reviewable:

- main wallet execution is disabled in Agent,
- destination approval is required for executable Wallet handoffs,
- watch-only wallets cannot execute,
- Zerion requires CLI, redacted API key, redacted agent token, and validated swap command shape,
- high notional Zerion requests are blocked by the local tiny cap,
- unsupported execution categories are blocked,
- unsafe secret or command-access requests are blocked.

The policy decision is stored with every proposal and shown in chat.

## Proposal and Handoff

`AgentProposalFactory` creates safe local proposal records. Proposal destinations are:

- Wallet -> Swap,
- Wallet -> Send,
- Wallet -> Private,
- Wallet -> Portfolio sections,
- Wallet -> Security,
- Wallet -> Activity,
- Agent -> Zerion review,
- none for blocked/unsupported requests.

The handoff changes UI navigation only. It does not build, sign, submit, or confirm a transaction.

The approval queue lists draft, blocked, ready-for-review, and handed-off proposals. It is not an execution surface.

## Hosted AI Boundary

Agent Chat can call GORKH Hosted Agent API when `GORKH_AGENT_API_BASE_URL` is configured. The app does not contain a model-provider secret and users do not supply one. Optional app-to-backend authentication uses `GORKH_AGENT_API_KEY` from the local process environment only.

Before a hosted request, GORKH builds a minimized context from safe Wallet summaries and blocks forbidden fields. Phase A5 validates the explicit `/v1/agent/chat` request contract before sending and sanitizes the response before it reaches proposal logic. The hosted response can suggest copy, missing fields, and local tool names. Tool suggestions outside the allowlist are blocked and audited. Backend approval claims are ignored.

If the hosted endpoint is unavailable, Agent Chat shows Local Safe Mode and continues using deterministic local classification, policy, and handoff behavior.

## Read-Only DeFi Analysis

`AgentDeFiOpportunityAnalyzer` reuses existing Wallet data:

- Portfolio aggregate summary,
- Yield/APY summary,
- Lending and Liquidity summaries,
- PnL summary,
- local activity events.

It uses cautious language such as candidate, review, reported APY, higher risk, and data unavailable. It does not recommend guaranteed outcomes or create execution paths.

## Memory and Audit

Agent memory is in-memory only and stores safe summaries of recent intents, proposals, handoff targets, and local tool results. It stores no keys, tokens, raw transaction payloads, private wallet data, or wallet secrets. Users can clear memory from Agent Chat.

Audit events include:

- chat message received,
- intent classified,
- policy decision made,
- proposal created,
- proposal blocked,
- proposal handed off,
- read-only analysis performed,
- unsupported request blocked,
- unsafe request blocked.

Audit details are redacted before storage.

## Security Invariants

- Chat does not execute transactions.
- Main Wallet remains approval-only.
- Zerion uses a separate policy-scoped agent wallet.
- Watch-only wallets remain analysis-only.
- Cloak execution remains inside Wallet -> Private.
- No arbitrary command input is accepted.
- No GORKH wallet secret is exposed to Zerion or Agent memory.
