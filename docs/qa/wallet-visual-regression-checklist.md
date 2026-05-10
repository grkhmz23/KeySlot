# Wallet Visual Regression Checklist

Phase W2/W3 is a production Wallet QA pass. It does not add new protocol integrations or execution paths.

## Session Result

- Build launched a local Debug `GORKH.app` from Xcode DerivedData.
- The app opened as a movable, resizable macOS window with the expected dark graphite product shell.
- Temporary screenshots were captured under `/tmp` only and were not added to the repository.
- The visible launch state was the local no-wallet/setup state plus the Wallet status inspector. A stale pre-W1 process was found during QA, quit, and relaunched before continuing.
- Full per-section screenshot coverage was not completed in this session because the local machine focus/accessibility state prevented reliable automated navigation screenshots. Use the manual checklist below before release.
- W3 rebuilt and opened the Debug app again. System Events reported a `GORKH` window, but desktop focus stayed on another app during screenshot capture, so no W3 screenshot was committed.

## W3 Seeded Demo-State Coverage

W3 adds an inert release-QA demo state in app code for tests and future preview wiring. It is disabled by default, contains public watch-only addresses only, uses `mock-display-only` balances, and has `allowsExecution = false`.

Use this state only to validate layout density, labels, empty states, and section visibility. It must not be presented as live portfolio data, must not bypass lock/approval gates, and must not be used for any transaction flow.

Seeded-state validation targets:

- Overview: primary cards and status strip can render with non-empty summary data.
- Portfolio: Summary, Assets & Wallets, DeFi, Performance, and History can be checked without live balances.
- Send/Receive: receive copy controls remain address-only; send stays gated by wallet state.
- Swap: quote/review empty state remains visible without creating a route.
- Private/Cloak: local-only private-state warnings remain visible.
- Security: lock, backup, mainnet guard, signing guard, and RPC status remain visible.
- Activity: user-facing Activity label remains primary; technical details stay behind disclosure.

Manual follow-up is still required for a fully signed desktop release candidate because local macOS focus/accessibility restrictions prevented reliable automated screenshots across every navigation segment.

## Manual Screenshot Set

Capture screenshots with no secrets, no recovery phrase, no private key material, and no token/API environment values visible.

1. Default app launch
   - Window opens at a sane size.
   - Window is movable and resizable.
   - Wallet shell uses the native dark graphite style.
   - Sidebar and inspector do not overlap content.

2. Wallet Overview
   - Navigation order is Overview, Portfolio, Send, Swap, Private, Security, Activity.
   - Overview cards answer what is owned, what it is worth, what is safe to do, security state, and recent activity.
   - Primary actions wrap cleanly at narrower widths.

3. Portfolio
   - Summary, Assets & Wallets, DeFi, Performance, and History sections are visible.
   - PUSD, Stake/LST, Lending, Liquidity, Yield, and PnL remain accessible.
   - Values are clearly marked as estimates where applicable.
   - Long lists scroll inside the Wallet content area without clipping.

4. Send
   - Receive panel is visible above send controls.
   - Receive address copy and payment note copy are address-only and show no secrets.
   - Locked wallet state disables execution paths.
   - Mainnet warnings and simulation requirements remain visible when applicable.

5. Swap quote state
   - Quote freshness, route review, simulation, approval, and mainnet warning copy remain visible.
   - No new swap execution path is present.

6. Private / Cloak
   - Mainnet-only real transaction warning is visible.
   - Local-only private state warning is visible.
   - Scan/live-validation status is honest.
   - Partial withdraw remains locked unless explicitly implemented in a later phase.

7. Security
   - Security strip shows lock, auto-lock, LocalAuthentication, backup, mainnet guard, signing guard, Agent signer disabled, and RPC status.
   - No critical warning is hidden behind non-obvious UI.

8. Activity
   - User-facing label is Activity.
   - Rows show category, status, timestamp, wallet/network, and signature when available.
   - Technical audit details remain available behind disclosure.
   - There is no primary `Audit` label in the main navigation.

9. Locked wallet state
   - Send/private execution is blocked until unlock.
   - Copy clearly states approval/signing requirements.

10. Watch-only wallet state
    - Navigation is limited to Overview, Portfolio, Activity.
    - Send, Swap, Private, and Security execution surfaces are not available.

11. Missing RPC token state
    - RPC Fast token status is missing/degraded without printing a token.
    - Endpoint host is safe to show.

12. Mainnet warning state
    - Mainnet phrase protection is visible before real execution.
    - User-facing copy says mainnet transactions are real.

13. Portfolio edge states
    - Price unavailable.
    - Portfolio empty.
    - PnL insufficient history.
    - Yield unavailable.
    - Lending/LP partial data.

14. Agent Chat
    - Guardrail banner says Agent can prepare/review but cannot move funds from chat.
    - Chat timeline, intent cards, tool-result cards, and proposal cards render without clipping.
    - Hosted AI unavailable state shows Local Safe Mode honestly when no endpoint is configured.
    - No proposal card offers direct execution.

15. Agent Approval Queue
    - Draft, blocked, ready-for-review, and handed-off states are visually distinct.
    - Filters for Wallet, Zerion, Private, read-only, and blocked items are usable.
    - Blocked reasons are visible.
    - Queue items provide handoff buttons only.

16. Zerion Executor
    - Separate Zerion wallet copy is visible.
    - CLI, API key, policy, and agent-token states are redacted.
    - Missing prerequisites block live execution.
    - Bridge, direct send, and signing commands are not available.

17. Transaction Studio
    - Decode, Simulate, Risk Review, Explanation, and History remain accessible.
    - Persistent review-only banner is visible.
    - Input empty state explains that Studio does not sign or broadcast.
    - Unknown instruction and simulation-unavailable states are honest.

18. Shield Review Card
    - Approval screens show action summary, programs, signers/writable counts, simulation status, unknown instruction count, and risk flags.
    - Payload mode is visible: Exact transaction, Summary only, or Unavailable.
    - Approval copy says review is required where applicable.
    - Existing approval gates remain visible below/around the card.

19. Studio Handoff Exact Mode
    - Opening from SOL/SPL/swap/Orca approval with a transient payload shows exact decode in Transaction Studio.
    - Source flow and payload mode are visible.
    - Exact payload is not saved to Studio history by default.

20. Studio Handoff Summary-Only Mode
    - Opening from Cloak/Zerion or unavailable raw payload shows a summary-only explanation.
    - The UI states exact decode is unavailable and does not fake raw transaction details.
    - Review-only banner remains visible.

21. Hosted AI Local Safe Mode
    - Agent status shows hosted endpoint missing/unavailable without crashing.
    - Redaction/no-secrets indicator is visible.
    - Local deterministic classifier still handles core prompts.

## Scheme And Secret Hygiene

Before release, verify:

```sh
rg -n "RPCFAST|GORKH_RPCFAST|JUPITER|API_KEY|PRIVATE_KEY|SECRET_KEY|MNEMONIC|SEED|WALLET_JSON" apps/macos/GORKH/GORKH.xcodeproj/xcshareddata
git ls-files '*xcuserdata*' '*.xcuserstate' '.gorkh-devnet-smoke/*'
```

Expected:

- No secret environment values in shared schemes.
- No Xcode user state committed.
- No `.env` file committed.

## Release Gate

Do not pass Wallet release QA unless:

- Build and `GORKHTests` pass.
- The checklist above has been reviewed on a clean local app launch.
- No obvious clipped text, overlapping controls, unreadable contrast, or stale Audit primary label is present.
- No new execution path or protocol integration was added.
