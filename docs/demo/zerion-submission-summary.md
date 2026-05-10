# Zerion Submission Summary

## What Was Built

GORKH adds a top-level Agent section that can understand wallet and DeFi intents, create policy-gated proposals, and hand off a tiny Zerion swap to a guarded review flow. The Agent does not execute directly from chat.

The Zerion path uses:

- deterministic intent classification,
- local policy checks,
- separate Zerion wallet status,
- scoped policy status,
- redacted agent token status,
- fixed Zerion CLI command building,
- explicit review and confirmation,
- safe audit timeline.

## How Zerion CLI Is Used

GORKH extends Zerion CLI as the execution layer for one tiny same-chain swap flow. The app detects CLI and Node.js status, checks policy/token readiness, validates swap help shape, and builds a fixed argument array for the tiny swap command after approval.

GORKH does not pass its main-wallet signer, recovery text, wallet files, Keychain signer material, or Cloak private state to Zerion.

## Scoped Policy Model

The demo requires:

- separate tiny-funded Zerion wallet,
- chain-scoped policy,
- short expiry,
- deny transfers where supported,
- deny approvals where supported,
- optional allowlist where supported,
- redacted agent token status.

Agent tokens are treated as spending power and should be revoked after the demo.

## Real Transaction Requirement

The live hackathon demo should execute one tiny same-chain swap only after:

- CLI status is loaded,
- API key status is redacted and present,
- policy/token status is loaded,
- swap help shape is validated,
- proposal is below the local tiny cap,
- exact confirmation phrase is entered,
- the transaction hash/signature can be recorded.

Do not claim a live transaction until the transaction hash/signature exists.

## Current Rehearsal Evidence

Latest A8 rehearsal status, 2026-05-10:

- Node.js is installed locally.
- Zerion CLI was not resolved in PATH.
- `ZERION_API_KEY` was missing in the shell environment.
- Separate Zerion wallet, scoped policy, and agent token were not verified.
- No live transaction was executed.
- Transaction hash/signature remains pending.

Submission claim status: do not claim live transaction execution until the CLI/API/wallet/policy/token prerequisites are configured and a transaction hash/signature is recorded.

## Code Modules Involved

- `GORKH/Core/Agent/AgentIntentClassifier.swift`
- `GORKH/Core/Agent/AgentPolicyEngine.swift`
- `GORKH/Core/Agent/AgentProposalFactory.swift`
- `GORKH/Core/Zerion/ZerionStatusService.swift`
- `GORKH/Core/Zerion/ZerionSwapCommandBuilder.swift`
- `GORKH/Core/Zerion/ZerionExecutionPolicy.swift`
- `GORKH/Core/Zerion/ZerionExecutionService.swift`
- `GORKH/Modules/Agent/AgentChatView.swift`
- `GORKH/Modules/Agent/ZerionExecutorView.swift`
- `GORKH/Modules/Agent/ZerionExecutionReviewView.swift`

## Safety Boundaries

- Chat creates proposals only.
- GORKH main-wallet access is disabled for Zerion.
- Watch-only wallets are analysis-only.
- Hosted AI responses are advisory only.
- Backend/model responses cannot approve execution.
- No arbitrary terminal command input is accepted.
- Bridge, send, signing, recurring automation, and main-wallet execution remain blocked.

## Judge Reproduction

1. Build and run GORKH.
2. Install Zerion CLI and Node.js 20+.
3. Set the Zerion API key in the local terminal only.
4. Create a separate tiny-funded Zerion wallet.
5. Create a scoped policy and agent token manually.
6. Open Agent -> Zerion Executor and refresh status.
7. Open Agent -> Chat and request a tiny Zerion swap.
8. Review the proposal in Agent -> Proposals.
9. Enter the exact confirmation phrase.
10. Execute the tiny swap and record the transaction hash/signature.
11. Revoke the agent token after the demo.
