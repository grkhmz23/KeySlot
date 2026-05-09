# Portfolio PnL Smoke

Use this checklist to verify the Wallet -> Portfolio -> PnL / Performance panel.

## Preconditions

- Launch GORKH locally.
- Select a wallet or watch-only scope.
- Open Wallet -> Portfolio.
- Refresh Portfolio at least once.

## Basic Smoke

1. Open the PnL / Performance panel.
2. Confirm the panel shows:
   - status chip
   - current portfolio value
   - 24h / 7d / 30d / all-time rows
   - realized PnL status
   - unrealized PnL status
   - cost-basis coverage
   - asset performance estimates
   - wallet performance estimates
3. With fewer than two snapshots, confirm timeframe rows show insufficient history.
4. Refresh Portfolio again after a later snapshot exists.
5. Confirm value delta appears only where a previous snapshot is available.
6. Confirm missing price data produces partial/unavailable state, not fabricated values.

## Cost Basis

Manual cost-basis storage is local-only. If entries are absent:

- cost basis should show partial or unavailable state
- realized PnL should be unavailable
- unrealized PnL should be partial when holdings exist

No wallet secrets should appear in cost-basis storage or audit details.

## Swap Hints

If GORKH swap activity exists, the PnL summary may show a swap hint count. This is only a cost-basis hint. It must not be presented as complete accounting.

## Forbidden Behavior

The PnL panel must not:

- request signing
- build transactions
- trigger swap, staking, lending, LP, or yield execution
- send data to cloud AI
- claim tax-grade accounting
- claim official accounting completeness
- display private keys, seed phrases, mnemonics, wallet JSON, signing seed, transaction payloads, or serialized transactions

## Validation Commands

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -scheme GORKH -project apps/macos/GORKH/GORKH.xcodeproj build
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -scheme GORKH -project apps/macos/GORKH/GORKH.xcodeproj test -only-testing:GORKHTests
git diff --check
git ls-files '*xcuserdata*' '*.xcuserstate' '.gorkh-devnet-smoke/*'
```
