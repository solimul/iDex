# 🧮 Minimal DEX (Decentralized Exchange)

This project implements a **minimal Automated Market Maker (AMM)**-based DEX using Solidity. It facilitates token swaps between ETH and USDC with a constant-product formula. The purpose is to provide a modular and extensible foundation for learning and experimenting with DEX internals, smart contract interactions, and reentrancy protection.

> ⚠️ **Note:** This project was developed as part of my personal effort to learn **Blockchain Programming using Solidity**. It is intended for educational and experimental purposes. While care has been taken to enforce correctness and security principles, it is **not intended for production use** without thorough auditing and extension.


---

## 📌 Key Features

- **ETH ⇄ USDC token swaps**
- **Constant-product AMM** (`x * y = k`) pricing
- **Support for both local (Anvil) and testnet (Sepolia) environments**
- **Reentrancy protection**
- **Pool reserve enforcement and access control**
- **Modular architecture: swap logic separated from liquidity and configuration**
- **MyERC20 support for unit tests**
- **Full test suite using Foundry**

---

## ❗ Key Constraints & Design Decisions

- Supports only **USDC (6 decimals)** and **ETH (18 decimals)** — matching native units
- No decimal normalization — input values must match token precision
- Designed for clarity: no router contracts, slippage math, or fees included (yet)
- Reserve updates are restricted to the DEX contract
- Custom error types (e.g., `UNSUPPORTED_OUT_TOKEN`, `INSUFFICIENT_LIQUIDITY`) for clear failure handling
- Safe against reentrancy exploits through well-structured call ordering

---

## 🗂 File Overview

### 📄 `MinimalDex.sol`
- Main entry point for user interactions
- Performs validations and orchestrates swaps
- Interfaces with `AMM` for price/output logic and `LPool` for reserve control

### 📄 `AMM.sol`
- Handles all core **price and amountOut calculations**
- Maintains the constant-product invariant during swaps
- Calls `updateReserves` on `LPool` after each trade

### 📄 `LPool.sol`
- Stores ETH and USDC **reserves**
- Enforces **ownership control** on reserve updates
- Throws on underflows or unauthorized access
- Contains view methods to expose reserve states

### 📄 `MyERC20.sol`
- Minimal ERC20 token with `mint()` and `enableReentrancyAttack()` for testability
- Used to simulate ETH and USDC locally in Anvil-based tests

### 📄 `NetworkConfig.sol`
- Determines correct token addresses based on network
- Automatically uses **Mock tokens on Anvil** and **real tokens on Sepolia**
- Centralized config for all network-specific parameters

### 📄 `ReentrantAttack.sol`
- A deliberately malicious contract used to verify **reentrancy safety**
- Executes a nested call back to the DEX during `transferFrom`

### 📄 `MinimalDex.t.sol`
- Foundry-based test suite for validating DEX behavior
- Includes:
  - Positive and negative swap scenarios
  - Reentrancy attack protection checks
  - Balance and reserve updates
- Uses a helper contract (`TestSetup`) to simulate multiple actors and approval logic

### 📄 `DeployMinimalDex.s.sol`
- Script to deploy the DEX on Sepolia (or other EVM networks)
- Uses Foundry's `forge script` deployment flow with verification support

---

## 🧪 Testing

Run all unit tests locally:
```bash
forge test
```

Run a specific test:
```bash
forge test --mt testUserHasInsufficientETHExpectRevert
```

Check gas usage:
```bash
forge test --gas-report
```

---

## 🚀 Deployment

Deploy to Sepolia:
```bash
forge script script/DeployMinimalDex.s.sol \
  --rpc-url $SEPOLIA_RPC \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

---

## 🔐 Security Considerations

- **Reentrancy protection** is ensured by the ordering of state updates and external calls
- **Custom errors** used for clearer debugging and gas optimization
- This implementation omits fees, slippage, and external routers for simplicity, but can be extended

---

## 🧠 Future Work

- Support for additional token pairs
- Fee mechanics and liquidity provisioning
- Frontend integration
- Formal verification
- Gas optimazation
