# 🦄 Minimal DEX — Constant Product AMM

This project implements a **Minimal Decentralized Exchange (DEX)** with a Uniswap v1-style **Constant Product Automated Market Maker (AMM)** using Solidity. It supports swaps between **ETH** and **DAI** with slippage protection, invariant enforcement, and modular contract design.

---

## 🔧 Contracts Overview

### 🧱 `AMM.sol`
Implements the core AMM logic:

- Maintains ETH and DAI reserves via an internal `LPool`
- Enforces `x * y = k` invariant
- Supports token swaps with slippage protection
- Emits `Swapped` events

### 💧 `LPool.sol`
A liquidity pool that stores:

- Internal reserves of ETH and DAI
- Getter and update functions for managing reserves
- Invariant calculation for post-swap validation

### 🪙 `MinimalDex.sol`
A user-facing router that:

- Deploys and interacts with the `AMM` contract
- Offers a `swapTokens()` function using human-friendly string input
- Handles slippage and token mapping behind the scenes

---

## 🔐 Security Features

- ✅ Token validation (`DAI` or `ETH` only)
- ✅ Invariant enforcement post-swap
- ✅ Slippage percentage check to protect against front-running
- ✅ Balance and liquidity checks before swaps

---

## 🔄 Swap Flow

1. User calls `swapTokens()` with:
   - `amountIn` (token quantity to swap)
   - `slippagePercent` (tolerated price change)
   - `tokenInString` ("DAI" or "ETH")
   - `tokenOutString` ("ETH" or "DAI")

2. `AMM` calculates expected output
3. Slippage tolerance is applied
4. `AMM.swap(...)` is executed if safe

---

## 🔢 Constants

- Initial reserves:
  - `DAI_RESERVE = 150000 ether`
  - `ETH_RESERVE = 100 ether`
- Initial price: `1 ETH = 1500 DAI`

---

## 🧪 Testing Ideas

| Test | Description |
|------|-------------|
| ✅ Swap DAI → ETH with 1% slippage |
| ✅ Swap ETH → DAI with 2% slippage |
| ✅ Revert if tokens are not DAI/ETH |
| ✅ Revert if amountIn is 0 |
| ✅ Revert if output below slippage tolerance |
| ✅ Revert if invariant breaks |

---

## 🛠 How to Use (in Scripts)

```solidity
// Example:
dex.swapTokens(1000 ether, 2, "DAI", "ETH");
