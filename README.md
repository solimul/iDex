# IDex

IDex is a lightweight decentralized exchange (DEX) written in Solidity. It implements a constant-product AMM for ETH–USDC swaps, with modular contracts for liquidity provisioning, LP tokenization, and swap fee handling to support pool growth and protocol rewards. The system is thoroughly guarded against reentrancy and access control attack vectors.

## Features

- Constant-product AMM for ETH–USDC swaps (`x * y = k`).
- Liquidity pool creation with deposits, withdrawals, and share tracking.
- LP tokens to represent depositor ownership in the pool.
- Reward accrual from swap fee and distribution to liquidity providers.
- Configurable parameters (fees, minimum liquidity) via `NetworkConfig`.
- Efficient math utilities (Babylonian method for square root).
- Modular design separating pool logic, liquidity, rewards, and configuration.
- Foundry-based testing; deployment and verification automated via `Makefile`.

## Structure

- `IDex.sol` — main entry point and DEX interface.  
- `Pool.sol` — swap execution and pool accounting.  
- `LiquidityProvision.sol` — deposits, withdrawals, LP share management.  
- `ProtocolReward.sol` — protocol fee accrual and distribution.  
- `NetworkConfig.sol` — deployment parameters.  
- `BabylonianLib.sol` — math helper functions.  
- `Shared.sol` — shared types and structures.  
- `MinimalDex.t.sol` — Foundry test suite.  
- `DeployIDex.s.sol` — deployment script.  
- `deploy_libs.sh` — library deployment and linking.  
- `verify.sh` — Etherscan verification helper.  
- `Makefile` — orchestrates build, deploy, and verify tasks.

## Deployment (Makefile)

The `Makefile` loads `.env` and drives end-to-end flows. Common targets:

- `make all` — runs `deploy`, `libs`, and `verify` in sequence.  
- `make deploy` — deploy contracts using `DeployIDex.s.sol`.  
- `make libs` — deploy/link required libraries via `deploy_libs.sh`.  
- `make verify` — verify deployed contracts on Etherscan via `verify.sh`.  
- `make anvil` — run the full flow against local Anvil (`CHAIN=anvil`).  
- `make sepolia` — run the full flow against Sepolia (`CHAIN=sepolia`).  

### Typical usage

    # 1) Configure .env with your secrets (see below)
    # 2) Local run against Anvil:
    make anvil

    # 3) Testnet run against Sepolia:
    make sepolia

    # Or call targets explicitly with a chosen chain:
    make deploy   CHAIN=anvil
    make libs     CHAIN=sepolia
    make verify   CHAIN=sepolia

The `Makefile` selects per-chain RPC/IDs internally:

- Anvil: `http://127.0.0.1:8545` (chain `31337`)  
- Sepolia: preconfigured RPC (chain `11155111`)  

`deploy_libs.sh` expects: `RPC_URL`, `PRIVATE_KEY`, `ETHERSCAN_API_KEY`.  
`verify.sh` expects: `ETHERSCAN_API_KEY`, `CHAIN_ID`, `DEPLOYMENT_SCRIPT`, `PRIVATE_KEY`, plus the ETH/USDC addresses and contract→library mapping passed from the `Makefile`.  

## .env

The `.env` file stores private keys, RPC endpoints, chain IDs, and API keys required for deployment, testing, and contract verification.  
It is loaded automatically by the `Makefile` and used by helper scripts (`deploy_libs.sh`, `verify.sh`).  

### Example

    # Local Anvil
    ANVIL_PRIVATE_KEY=0xac0974...ff80
    ANVIL_RPC_URL=http://localhost:8545
    ANVIL_CHAIN_ID=31337

    # Sepolia Testnet
    SEPOLIA_PRIVATE_KEY=0xc5a4c4...94e9f
    SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/SjLdkEh...
    SEPOLIA_CHAIN_ID=11155111

    # Etherscan
    ETHERSCAN_API_KEY=TC2ICV8...P7VUIEZ

## Testing

Run tests with Foundry:

    forge test

Covers:

- AMM swaps and invariants.  
- Deposit/withdraw flows and LP accounting.  
- Protocol reward accrual and distribution.  
- Parameter validation and edge cases.  
