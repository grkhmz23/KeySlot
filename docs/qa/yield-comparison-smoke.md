# Yield Comparison Smoke

This smoke verifies the Wallet -> Portfolio -> Yield panel. It is read-only.

## Preconditions

- Build the app.
- Open Wallet -> Portfolio.
- Refresh the portfolio for the desired scope.
- No wallet funds are required for empty/unavailable-state smoke.

## Expected UI

The Yield panel should show:

- status chip,
- read-only analytics chip,
- execution locked chip,
- yield exposure,
- held source count,
- APY/APR available count,
- unavailable source count,
- protocol cards for LST, lending, LP, and PUSD sources.

The panel must not request wallet unlock, LocalAuthentication, signing, or transaction review.

## Source Checks

LST:

- JitoSOL, mSOL, bSOL, and bbSOL appear in comparison when on mainnet scope.
- If held, the holding amount and estimated USD value are shown when available.
- APY/TVL/exchange rate remain unavailable until a safe source is connected.

Lending:

- Kamino supply APY appears when read-only reserve data includes it.
- MarginFi shows partial or unavailable when helper data does not include rates.
- Borrow/health context remains informational and read-only.

LP:

- Meteora, Orca, and Raydium positions appear through existing LP summaries.
- If APY/APR is unavailable, the row says so.
- Existing Orca harvest remains separate from this panel.

PUSD:

- PUSD appears as a stablecoin treasury asset.
- The yield row says PUSD yield is not active in GORKH.

## Snapshot and Audit

After portfolio refresh, audit should include a yield refresh or unavailable-source event and a yield snapshot event. Details should contain only counts, status, labels, and sources.

## Forbidden Behavior

The smoke fails if the Yield panel:

- asks for signing,
- builds a transaction,
- sends a transaction,
- adds a new execution action,
- shows fabricated APY/APR,
- includes private keys, seed phrases, wallet JSON, transaction payloads, or instruction payloads in UI, audit, or snapshots.

## Validation Commands

```bash
xcodebuild -scheme GORKH -project apps/macos/GORKH/GORKH.xcodeproj build
xcodebuild -scheme GORKH -project apps/macos/GORKH/GORKH.xcodeproj test -only-testing:GORKHTests
git diff --check
git ls-files '*xcuserdata*' '*.xcuserstate' '.gorkh-devnet-smoke/*'
```
