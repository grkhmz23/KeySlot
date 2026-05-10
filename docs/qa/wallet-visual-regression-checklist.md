# Wallet Visual Regression Checklist

Phase W2 is a production Wallet QA pass. It does not add new protocol integrations or execution paths.

## Session Result

- Build launched a local Debug `GORKH.app` from Xcode DerivedData.
- The app opened as a movable, resizable macOS window with the expected dark graphite product shell.
- Temporary screenshots were captured under `/tmp` only and were not added to the repository.
- The visible launch state was the local no-wallet/setup state plus the Wallet status inspector. A stale pre-W1 process was found during QA, quit, and relaunched before continuing.
- Full per-section screenshot coverage was not completed in this session because the local machine focus/accessibility state prevented reliable automated navigation screenshots. Use the manual checklist below before release.

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

Do not pass W2 release QA unless:

- Build and `GORKHTests` pass.
- The checklist above has been reviewed on a clean local app launch.
- No obvious clipped text, overlapping controls, unreadable contrast, or stale Audit primary label is present.
- No new execution path or protocol integration was added.
