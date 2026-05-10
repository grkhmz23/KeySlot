# Release Candidate Smoke

Phase R1 is an integrated release-candidate smoke and evidence pass. It validates that the current app is internally consistent before the next major module begins. It does not add protocol integrations, execution paths, raw broadcast, or signing from review tools.

## Session Result

- Source tree started clean at `6339856 chore: harden Shield Review approval handoffs`.
- This evidence pack was prepared from source, docs, tests, and safe mock smoke commands.
- Debug app launch was performed after a successful build; macOS reported a `GORKH` window.
- Live funded flows were not run in this pass.
- Manual desktop screenshot and full navigation coverage remain pending unless explicitly recorded below.

## App Launch

Expected checks:

- App builds with the shared `GORKH` scheme.
- Debug app opens without crashing.
- Top-level navigation includes Wallet, Agent, and Transaction Studio.
- Window uses the production dark graphite shell and remains movable/resizable.
- Empty/no-wallet state is clear and does not expose secrets.

R1 evidence:

- Build command: `xcodebuild build -scheme GORKH`.
- Launch inspection: Debug `GORKH.app` opened from DerivedData and System Events returned a `GORKH` window.
- Remaining blocker: full visual navigation and screenshot evidence require manual macOS focus/accessibility access.

## Wallet

Expected checks:

- Wallet opens to Overview.
- Navigation remains Overview, Portfolio, Send, Swap, Private, Security, Activity.
- Receive panel shows public address only.
- Locked and watch-only states block execution.
- Mainnet warnings, simulation requirements, and approval gates remain visible.

Evidence:

- Unit/source checks cover Wallet navigation and release QA demo state.
- Visual checklist path: `docs/qa/wallet-visual-regression-checklist.md`.

## Portfolio

Expected checks:

- Portfolio Summary, Assets, DeFi, Performance, and History remain accessible.
- PUSD, Stake/LST, Lending, Liquidity, Yield, and PnL panels show loaded, partial, or unavailable states honestly.
- Portfolio values are estimates where applicable and do not double-count LP/yield positions.

Evidence:

- Existing portfolio, yield, liquidity, and PnL tests cover model safety and unavailable states.
- Manual UI smoke remains required for final screenshot evidence.

## PUSD

Expected checks:

- PUSD Treasury status is visible from Portfolio and Agent summaries.
- PUSD yield remains unavailable unless a real source is connected.
- PUSD payment drafts require Wallet review and approval.

Evidence:

- PUSD smoke doc: `docs/qa/pusd-wallet-smoke.md`.
- Agent handoff checks are listed in cross-module smoke.

## Send

Expected checks:

- SOL and SPL send approval screens show Shield Review where transaction data is available.
- Wallet remains the owner of approval, signing, and send gates.
- Watch-only and locked-wallet send attempts are blocked.

Evidence:

- Shield Review regression doc: `docs/qa/shield-review-approval-regression.md`.

## Swap

Expected checks:

- Jupiter quote freshness, fingerprint, simulation, approval, and mainnet phrase gates remain active.
- Shield Review appears in swap approval and can hand off exact in-memory payloads to Transaction Studio when available.
- Agent can draft a swap proposal but cannot execute it from chat.

Evidence:

- Cross-module scenario: Agent prepares swap -> Wallet Swap handoff -> Shield Review visible.

## Private / Cloak

Expected checks:

- Cloak private-state warnings remain visible.
- Cloak deposit/fullWithdraw approval uses Shield Review summary or exact payload only when safe transaction data is already available.
- No private state, viewing key, nullifier, proof input, or vault secret is exposed.

Evidence:

- Cloak QA docs remain the source for live tiny mainnet validation.
- R1 does not claim a live Cloak smoke.

## Security

Expected checks:

- Security strip shows wallet lock, LocalAuthentication, backup, mainnet guard, signing guard, Agent signer disabled, and RPC status.
- No approval guard is weakened.
- No shared scheme contains secret environment values.

Evidence:

- Shared scheme secret scan is required before commit.

## Activity

Expected checks:

- Activity remains the user-facing label.
- Technical audit details remain behind disclosure.
- Agent, Shield Review, and Transaction Studio events record safe summaries only.

Evidence:

- Cross-module smoke covers Activity entries for Agent/Shield/Studio flows.

## Agent

Expected checks:

- Agent Chat understands full-app intents and local safe mode.
- Agent creates proposals and handoffs only.
- Agent cannot sign, send, swap, bridge, or run arbitrary commands from chat.
- Approval Queue has no execution button.

Evidence:

- Interactive QA doc: `docs/qa/agent-orchestrator-interactive-qa.md`.
- Full-app smoke doc: `docs/qa/agent-full-app-orchestrator-smoke.md`.

## Zerion

Expected checks:

- Zerion uses a separate tiny-funded wallet lane.
- Missing CLI/API/policy/token states block execution clearly.
- Tiny swap flow remains the only Zerion execution lane.
- No bridge, direct send, or signing command is enabled.

Evidence:

- Demo pack docs remain under `docs/demo`.
- E2E status doc: `docs/qa/zerion-agent-e2e-smoke.md`.
- R1 does not claim a live Zerion transaction.

## Hosted AI

Expected checks:

- Hosted AI is advisory only.
- Missing endpoint falls back to Local Safe Mode.
- Unsafe backend tool suggestions are blocked.
- No wallet secrets, raw payloads, API keys, or agent tokens are sent.

Evidence:

- Mock smoke command: `scripts/agent-hosted-ai-smoke.sh --mock`.
- Remote smoke remains pending unless `GORKH_AGENT_API_BASE_URL` is configured locally and results are recorded.

## Transaction Studio

Expected checks:

- Transaction Studio remains Decode -> Simulate -> Explain -> Risk Review -> Handoff.
- Studio cannot sign, broadcast, request airdrop, create bundles, or run arbitrary RPC commands.
- Studio history stores safe summaries only.
- Shield Review handoffs use transient in-memory payloads or honest summary-only state.

Evidence:

- Local smoke command: `scripts/transaction-studio-smoke.sh`.
- Studio docs: `docs/qa/transaction-studio-smoke.md`.

## Shield Review

Expected checks:

- Approval screens show review summaries where transaction data is available.
- Exact Studio decode is available only for transient in-memory payloads.
- Summary-only state is honest for Cloak/Zerion when raw transaction data is unavailable.
- Existing approval gates remain.

Evidence:

- Approval regression doc: `docs/qa/shield-review-approval-regression.md`.

## RPC Fast

Expected checks:

- RPC provider status is visible.
- Missing token state is degraded and redacted.
- No RPC token value is committed or shown.

Evidence:

- RPC Fast smoke doc: `docs/qa/rpcfast-wallet-smoke.md`.

## Secret Hygiene

Required scans:

```sh
git ls-files '*xcuserdata*' '*.xcuserstate' '.gorkh-devnet-smoke/*'
rg -n "RPCFAST|GORKH_RPCFAST|JUPITER|API_KEY|PRIVATE_KEY|SECRET_KEY|MNEMONIC|SEED|WALLET_JSON" apps/macos/GORKH/GORKH.xcodeproj/xcshareddata
rg -n "ZERION_API_KEY=|PRIVATE_KEY=|SECRET_KEY=|DEEPSEEK_API_KEY=|GORKH_AGENT_API_KEY=|WALLET_JSON=" docs scripts
```

Expected:

- Environment variable names may appear in docs/scripts.
- No real values, local `.env` files, wallet files, recovery text, or signing material are committed.

## Known Pending Live Smokes

- Clean-machine visual screenshot pass.
- Cloak tiny mainnet deposit/withdraw/scan.
- Jupiter tiny swap.
- PUSD balance/send smoke.
- Orca harvest with an owned LP position.
- Zerion tiny transaction with tx hash/signature.
- Hosted AI remote endpoint smoke.
- RPC Fast token read-path smoke.

Do not claim release-ready production behavior for these items until evidence is recorded.
