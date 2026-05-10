# Agent Policy Wallet Operator Smoke

Use this checklist to validate Phase A3 without executing from chat.

## Preconditions

- Build the macOS app.
- Open the Agent section.
- Zerion setup is optional for classifier and Wallet handoff testing.
- Do not paste API keys, agent tokens, recovery text, private keys, wallet files, or raw transaction payloads into chat.

## Chat Smoke

1. Open `Agent -> Chat`.
2. Enter `summarize my portfolio`.
3. Confirm a read-only tool result appears.
4. Confirm no proposal is created.
5. Confirm the audit timeline records message received, intent classified, and read-only analysis.

## Main Wallet Swap Draft

1. Enter `swap 100 USDC to SOL`.
2. Confirm the intent is `Token swap request`.
3. Confirm the proposal lane is `Main Wallet`.
4. Confirm the card says destination approval is required.
5. Click `Open Swap Review`.
6. Confirm the app navigates to Wallet -> Swap.
7. Do not approve or submit any transaction as part of this chat smoke.

## PUSD Draft

1. Enter `send 10 PUSD to 11111111111111111111111111111111`.
2. Confirm a PUSD payment draft appears.
3. Confirm the handoff target is Wallet -> Send.
4. Confirm no signing occurs from Agent.

## Cloak Draft

1. Enter `prepare a private Cloak payment`.
2. Confirm missing amount and recipient are requested.
3. Enter a complete request with amount and recipient.
4. Confirm the handoff target is Wallet -> Private.
5. Do not run a Cloak transaction from chat.

## LP / Yield Analysis

1. Enter `check my LP pools and find better positions`.
2. Confirm a read-only LP review result appears.
3. Enter `find safer yield for USDC`.
4. Confirm yield output uses existing Wallet analytics and states unavailable data honestly.
5. Confirm no LP, lending, staking, or yield execution action appears.

## Zerion Tiny Swap Handoff

1. Enter `zerion swap 1 USDC to ETH on base`.
2. If CLI/API/token/swap shape are missing, confirm the proposal is blocked with explicit reasons.
3. If all Zerion prerequisites are configured, confirm the proposal can hand off to Agent -> Proposals.
4. Confirm execution still requires the existing Zerion review screen and exact confirmation phrase.
5. Do not run a live transaction from chat.

## Unsupported and Unsafe Requests

1. Enter `bridge 5 USDC`.
2. Confirm it is blocked as unsupported.
3. Enter `run /bin/sh`.
4. Confirm it is blocked as unsafe.
5. Confirm no command runner is invoked.

## Expected Result

- Agent Chat exists.
- Requests are classified deterministically.
- Read-only requests produce tool result cards.
- Executable requests produce proposal cards.
- Destination handoff opens the correct module.
- Chat never executes, signs, or calls arbitrary commands.
- Audit contains redacted Agent events only.
