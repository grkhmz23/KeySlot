# Release Evidence Matrix

Phase R1 tracks the current validation evidence for the integrated app. Status values are intentionally conservative: `passed`, `mock-passed`, `source-checked`, `manual-pending`, `live-pending`, or `blocked`.

| Feature | Status | Last validation command | Smoke mode | Evidence path | Remaining blocker | Next action |
| --- | --- | --- | --- | --- | --- | --- |
| App launch | passed | `xcodebuild build -scheme GORKH` plus Debug app open | manual | `docs/qa/release-candidate-smoke.md` | Full navigation screenshot pass still pending | Capture safe screenshots on QA machine |
| Wallet Overview | source-checked | `xcodebuild test -scheme GORKH -only-testing:GORKHTests` | unit/manual | `docs/qa/wallet-visual-regression-checklist.md` | Screenshot pass pending | Complete manual visual checklist |
| Portfolio | source-checked | `xcodebuild test -scheme GORKH -only-testing:GORKHTests` | unit/manual | `docs/qa/wallet-release-readiness.md` | Live wallet data coverage pending | Manual Portfolio screenshot smoke |
| PUSD Treasury | source-checked | `xcodebuild test -scheme GORKH -only-testing:GORKHTests` | unit/manual | `docs/qa/pusd-wallet-smoke.md` | Real balance/send smoke pending | Run tiny controlled PUSD smoke if available |
| Send approvals | source-checked | `xcodebuild test -scheme GORKH -only-testing:GORKHTests` | unit/manual | `docs/qa/shield-review-approval-regression.md` | Funded approval smoke pending | Validate SOL/SPL approval cards on devnet or controlled mainnet |
| Swap approvals | source-checked | `xcodebuild test -scheme GORKH -only-testing:GORKHTests` | unit/manual | `docs/qa/shield-review-approval-regression.md` | Tiny swap smoke pending | Run manual tiny swap only with explicit approval |
| Private / Cloak | live-pending | `xcodebuild test -scheme GORKH -only-testing:GORKHTests` | manual/live | `docs/qa/cloak-private-payment-smoke.md` | Tiny mainnet Cloak flow not run | Run controlled Cloak smoke separately |
| Security | source-checked | shared scheme secret scan | unit/source | `docs/qa/release-candidate-smoke.md` | Manual UI review pending | Confirm warning visibility in app |
| Activity | source-checked | `xcodebuild test -scheme GORKH -only-testing:GORKHTests` | unit/manual | `docs/qa/cross-module-regression-smoke.md` | Manual timeline verification pending | Validate Agent/Shield/Studio events in app |
| Agent Chat | source-checked | `xcodebuild test -scheme GORKH -only-testing:GORKHTests` | unit/mock | `docs/qa/agent-orchestrator-interactive-qa.md` | Interactive desktop QA pending | Run manual prompt matrix |
| Zerion Executor | blocked | `docs/qa/zerion-agent-e2e-smoke.md` | manual/live | `docs/qa/zerion-agent-e2e-smoke.md` | CLI/API/policy/token setup not confirmed locally | Configure separate Zerion wallet and rerun |
| Hosted AI | mock-passed | `scripts/agent-hosted-ai-smoke.sh --mock` | mock | `docs/qa/agent-hosted-ai-smoke.md` | Remote endpoint not configured unless env is present | Run remote smoke with local env only |
| Transaction Studio | mock-passed | `scripts/transaction-studio-smoke.sh` | mock/read-only | `docs/qa/transaction-studio-smoke.md` | Live public fixture smoke optional | Run read-only live smoke with public fixtures |
| Shield Review | source-checked | `xcodebuild test -scheme GORKH -only-testing:GORKHTests` | unit/manual | `docs/qa/shield-review-approval-regression.md` | Live approval UI smoke pending | Validate exact/summary handoff in app |
| Developer Workstation | passed | `cargo install --git https://github.com/solana-foundation/anchor avm --force`, `avm install latest`, `anchor --version`, `scripts/workstation-localnet-smoke.sh --full-localnet`, `scripts/workstation-program-ops-smoke.sh --authority-preview --cluster devnet --program-id 11111111111111111111111111111111`, `scripts/workstation-program-ops-smoke.sh --localnet-sample`, and manual funded devnet deploy/program show | local/live/manual-gated | `docs/qa/developer-workstation-localnet-smoke.md`, `docs/qa/developer-workstation-devnet-smoke.md` | Anchor CLI `1.0.2` is active and Rust/Cargo `1.95.0` are active; `avm use latest` still panics locally, but full localnet sample deploy succeeded, Program Ops wrapper localnet deploy succeeded, and follow-up devnet deploy succeeded with program id `9jZcQzNhUkXpEdyUGN4xsTnJ1N2xdaSWwkQiTDQtHncV` | Keep AVM runtime panic documented; continue to block mainnet program ops and unverified binary installs |
| RPC Fast | source-checked | shared scheme secret scan | source/manual | `docs/qa/rpcfast-wallet-smoke.md` | Real token read-path smoke pending | Run read-only RPC Fast smoke locally |
| Secret hygiene | passed | `git ls-files` and secret grep | source | `docs/qa/release-candidate-smoke.md` | Must be rerun before every push | Repeat before release tag |

## Release Decision Notes

- The current RC evidence pack is sufficient to move to the next implementation module only after build/tests and mock smokes pass.
- It is not a signed production release attestation.
- Live transaction, hosted endpoint, and visual screenshot items remain intentionally marked as pending unless explicit evidence is added.
