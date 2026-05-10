# Cross-Module Regression Smoke

Phase R1 validates that major app modules still work together after Wallet, Agent, Transaction Studio, and Shield Review integration. These scenarios are approval-based and must not execute from Agent Chat or Transaction Studio.

## Global Expectations

- Agent Chat creates proposals, summaries, and handoffs only.
- Wallet approval flows own signing and submission.
- Transaction Studio is review-only.
- Shield Review is review-only.
- Hosted AI is advisory only.
- Zerion uses the separate policy-scoped agent wallet lane.
- Watch-only wallets remain analysis-only.

## Scenario Matrix

| Scenario | Expected path | Expected evidence | Execution state |
| --- | --- | --- | --- |
| Agent prepares swap -> Wallet Swap handoff -> Shield Review visible | Agent Chat classifies `prepareSwap`, creates Wallet proposal, opens Wallet Swap review, Shield Review card appears before approval | Proposal card, Wallet Swap route/review, Shield Review summary, Activity event | No chat-side execution |
| Agent sends summary to Transaction Studio | Agent uses read-only explanation path and creates Studio handoff with safe summary | Studio opens summary/explanation without raw secret data | Review-only |
| Shield Review opens Transaction Studio exact handoff | SOL/SPL/swap/Orca approval with transient payload opens Studio exact decode | Studio shows source flow, `Exact transaction`, decoded timeline, no persistence | Review-only |
| Shield Review opens Transaction Studio summary-only handoff | Cloak/Zerion summary-only approval opens Studio explanation | Studio shows source flow, `Summary only`, exact decode unavailable | Review-only |
| Transaction Studio sends safe summary to Agent | Studio handoff excludes raw transaction payload and includes parsed actions/risk flags | Agent receives read-only explanation request | No execution |
| Portfolio PnL/Yield visible from Agent | Agent prompts `why is my PnL partial?` and `find safer yield for USDC` call read-only tools | PnL/Yield result cards with unavailable/partial states where needed | Read-only |
| Activity records Agent/Shield/Studio events | Run proposal/handoff/review flows and inspect Activity | User-facing Activity rows plus technical details behind disclosure | Safe audit only |
| Zerion missing prerequisites block execution | Missing CLI/API/policy/token produces blocked Zerion state | Zerion Executor shows clear blocked reason and redacted status | Blocked |
| Hosted AI unavailable uses local safe mode | Clear hosted endpoint env and send Agent prompt | Agent displays Local Safe Mode/fallback state and deterministic result | No backend dependency |

## Manual Steps

1. Launch the app from a clean Debug build.
2. Open Agent and submit `prepare a swap of 0.1 SOL to USDC`.
3. Confirm the proposal says review is required and has no execution button.
4. Open Wallet Swap from the handoff and confirm Shield Review is visible before approval.
5. Use Shield Review's Studio handoff button and confirm Transaction Studio opens exact or summary mode honestly.
6. From Transaction Studio, send a safe summary back to Agent and confirm no raw payload is attached.
7. Submit `find safer yield for USDC` and confirm the result is read-only.
8. Submit `why is my PnL partial?` and confirm the explanation cites incomplete cost basis/history as applicable.
9. Open Activity and confirm Agent/Shield/Studio events are present with safe summaries only.
10. Open Zerion Executor without local setup and confirm missing CLI/API/policy/token states block live execution.
11. Run hosted AI mock smoke and confirm local fallback remains available if remote endpoint is missing.

## Pass Criteria

- No module introduces a new execution path.
- Agent proposals always require destination review.
- Shield Review and Transaction Studio never sign or broadcast.
- Raw transaction/message payloads are transient where used and are not stored by default.
- No secrets, API keys, agent tokens, raw audit JSON, or private wallet data appear in UI, docs, logs, or screenshots.

## Deferred Live Checks

- Real Wallet send/swap smoke.
- Cloak tiny mainnet smoke.
- Zerion tiny transaction smoke.
- Hosted AI remote endpoint smoke.
- RPC Fast token-backed read-path smoke.
