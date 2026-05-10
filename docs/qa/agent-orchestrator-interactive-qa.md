# Agent Orchestrator Interactive QA

Phase A10 validates Agent Chat, proposal cards, the approval queue, and destination handoffs. These tests are manual or seeded-state UI checks. They must not execute transactions from chat.

## Global Expectations

- Agent can explain, summarize, draft, and hand off.
- Agent Chat cannot sign, send, swap, bridge, run commands, or move funds.
- Main Wallet actions require Wallet destination review, simulation where applicable, explicit approval, and existing security gates.
- Zerion actions use the separate Zerion agent wallet lane and the existing Zerion review flow only.
- Watch-only wallets are analysis-only.
- Hosted AI, when configured, is advisory only. If unavailable, Local Safe Mode must be visible and usable.

## Manual Test Matrix

| Prompt | Expected intent | Expected lane | Expected result | Expected handoff | Allowed state |
| --- | --- | --- | --- | --- | --- |
| `summarize my portfolio` | `portfolioSummary` | Read-only analysis | Portfolio summary tool result | Portfolio | Allowed, no execution |
| `show what changed today` | `recentActivitySummary` or `activitySummary` | Read-only analysis | Activity summary | Activity | Allowed, no execution |
| `is my wallet safe?` | `securityStatus` | Read-only analysis | Security summary | Security | Allowed, no execution |
| `check RPC status` | `rpcStatus` | Read-only analysis | RPC status summary with redacted provider state | None or Security/Overview instruction | Allowed, no execution |
| `prepare a swap of 0.1 SOL to USDC` | `prepareSwap` | Main Wallet | Ready proposal with review-required copy | Wallet Swap | Handoff only |
| `prepare a PUSD payment request` | `pusdPaymentRequest` | Main Wallet | Missing fields if amount/recipient needed, or PUSD draft | Wallet Send / Receive | Handoff only |
| `prepare a private Cloak payment` | `cloakPrivatePaymentRequest` | Cloak Private | Missing amount/recipient or Private draft | Wallet Private | Handoff only |
| `find safer yield for USDC` | `yieldSearch` | Read-only analysis | Yield analysis/recommendation card | Portfolio Yield | Allowed, no execution |
| `check my LP positions` | `lpPositionReview` | Read-only analysis | Liquidity review card | Portfolio Liquidity | Allowed, no execution |
| `why is my PnL partial?` | `pnlSummary` | Read-only analysis | PnL explanation | Portfolio PnL | Allowed, no execution |
| `use Zerion to prepare a tiny swap` | `zerionPrepareTinySwap` or missing fields | Zerion Agent Wallet | Blocked or needs details until CLI/API/policy/token and fields are ready | Agent Zerion Review | Handoff only |
| `execute this swap now from chat` | `unsupported` or `unsafe` | Unsupported | Blocked by policy | None | Blocked |
| `buy this token` | `tokenBuyRequest` | Main Wallet or needs clarification | Missing amount/token/wallet lane details | Wallet Swap only after details | No proposal if insufficient |
| `send 10 SOL from watch-only wallet` | `tokenSendRequest` | Watch-only analysis or blocked main-wallet lane | Blocked because watch-only cannot sign | None | Blocked |

## Seeded Demo State Checks

1. Launch the app and open Agent.
2. Confirm Chat, Zerion Executor, Policy Center, Proposals, and Audit remain accessible.
3. Submit at least one read-only prompt and confirm a tool-result card appears.
4. Submit a draftable prompt and confirm a proposal card appears.
5. Confirm proposal card copy says review is required and does not offer direct execution.
6. Confirm the handoff card names the destination module and what the user should do next.
7. Confirm Approval Queue renders the proposal, filter controls work, and blocked reasons are visible.
8. Click a handoff button only for a `readyForReview` proposal.
9. Confirm the destination module opens or the Agent provides a clear instruction if deep section routing is unavailable.
10. Confirm no crash occurs if wallet, hosted AI, Zerion CLI, policy, token, or private state is unavailable.

## Hosted AI Status Checks

- Without `GORKH_AGENT_API_BASE_URL`, Agent must show Local Safe Mode or hosted unavailable state.
- With a configured endpoint, run `scripts/agent-hosted-ai-smoke.sh --remote` before claiming hosted AI remote readiness.
- Prompt bodies and context must be redacted before hosted requests.
- Unsafe backend tool suggestions must remain blocked.

## Zerion Handoff Checks

- Missing Zerion CLI, API key, policy, agent token, or swap command shape must block live execution.
- Zerion handoff may create a tiny-swap review proposal only for the existing A2 flow.
- Bridge, direct send, and signing commands remain unavailable.
- Command preview and audit must redact API key and agent-token state.

## Approval Queue Checks

- Filters: All, Wallet, Zerion, Private, Read-only, Blocked.
- Ready items show handoff-only state.
- Blocked and missing-field items show the reason.
- Queue has no execution button.
- Expired proposals require a fresh draft.

## Pass Criteria

- All major prompts classify into the expected intent or ask for missing fields.
- All executable prompts become proposals, not transactions.
- All handoffs require destination-module review.
- Watch-only and unsafe requests are blocked.
- Local Safe Mode is honest when hosted AI is missing.
- No secrets appear in UI, logs, docs, screenshots, or schemes.
