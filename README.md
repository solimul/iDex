# 🧮 Minimal DEX (Decentralized Exchange)

This project implements a **minimal Automated Market Maker (AMM)**-based DEX using Solidity. It supports token swaps between ETH (WETH) and USDC, using a simplified constant-product formula. The goal is to provide a clear and testable foundation for deeper experimentation with DEX design.

---

## 📌 Key Features

- **ETH ⇄ USDC swapping**
- **Constant-product (x * y = k) AMM formula**
- **MockERC20-based testing for Anvil**
- **Support for both Anvil (local) and Sepolia (testnet)**
- **Pool reserve tracking**
- **Unit tests with foundry/forge**

---

## ❗ Key Constraints & Design Decisions

- Only **USDC (6 decimals)** and **WETH (18 decimals)** are supported
- Token units (amounts and reserves) are stored and compared in **raw units**
- No scaling of reserves is done — instead, inputs must match native decimals
- DEX fails gracefully with custom errors like `UNSUPPORTED_OUT_TOKEN`
- Test logic simulates both **user and pool roles** (via `mintApproveToken` and `approveDexToPullFrom`)
- Ownership is enforced where appropriate via `onlyOwner` modifiers (or similar)
- Reserve update logic is only accessible to trusted (e.g., DEX) contracts

---

## 🗂 File Descriptions

### 📄 `MinimalDex.sol`
- Main contract that acts as the entry point to the DEX
- Delegates price calculation and pool updates to `AMM` and `LPool`
- Exposes the `swap(...)` interface used by users

### 📄 `AMM.sol`
- Implements the **core AMM logic**
- Calculates `amountOut` based on input, reserves, and constant-product formula
- Calls `updateLPool` to modify reserves after each swap

### 📄 `LPool.sol`
- Manages **token reserves** (`s_reserveETH`, `s_reserveUSDC`)
- Implements access control and validation for reserve updates
- Verifies that token inputs and outputs are within allowable bounds

### 📄 `NetworkConfig.sol`
- Provides token address configuration for **Anvil vs Sepolia**
- Automatically uses mock tokens on Anvil and real token addresses on Sepolia

### 📄 `MockERC20.sol`
- Simple ERC20 implementation with a public `mint(...)` method
- Used for local Anvil-based testing

### 📄 `MinimalDex.t.sol`
- Foundry-based unit test suite for the DEX
- Includes positive and negative test cases:
  - Insufficient liquidity
  - Insufficient user balance
  - Correct reserve updates
- Uses helper contract (`TestSetup`) to simulate user roles and interactions

### 📄 `DeployMinimalDex.s.sol`
- Deployment script used to broadcast the DEX contracts to Sepolia or other supported networks
- Uses `forge script` for deterministic deployments

---

## 🧪 Testing

Run tests locally using Foundry:
```bash
forge test

Run specific test:

forge test --mt testSwapUSDC2ETHExpectRevertOnReserveUSDCExceed

Test gas usage:

forge test --gas-report

🏗 Deployment
Deploy to Sepolia:
forge script script/DeployMinimalDex.s.sol --rpc-url $SEPOLIA_RPC --private-key $PRIVATE_KEY --broadcast --verify
