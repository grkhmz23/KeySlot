# GORKH MarginFi Read-Only Helper

This helper is an isolated boundary for official MarginFi SDK read-only calls.

Supported commands:

- `health`
- `env-check`
- `positions`

The helper accepts only public wallet addresses, network/cluster, request IDs, and an optional RPC URL. It must never receive wallet private keys, seed phrases, mnemonics, signing seed bytes, wallet JSON, serialized transactions, or instruction payloads.

Execution methods are not implemented. The helper uses a public-key-only wallet stub whose signing methods throw if the SDK attempts to call them.
