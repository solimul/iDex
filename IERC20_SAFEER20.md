# 📘 ERC20 & SafeERC20 – Complete Public Method Reference

This document summarizes all public functions available in **IERC20** and **SafeERC20** from OpenZeppelin. Use this as a reference when developing contracts that handle token transfers, approvals, and interactions securely.

---

## 🔹 IERC20 (Interface)

Defines the **core ERC-20 standard** for fungible tokens.

### ✅ Functions

- `function totalSupply() external view returns (uint256);`  
  ➤ Returns total number of tokens in existence.

- `function balanceOf(address account) external view returns (uint256);`  
  ➤ Returns the token balance of a given address.

- `function transfer(address to, uint256 amount) external returns (bool);`  
  ➤ Transfers `amount` tokens from the caller to the address `to`.

- `function allowance(address owner, address spender) external view returns (uint256);`  
  ➤ Shows how much `spender` is allowed to spend from `owner`'s balance.

- `function approve(address spender, uint256 amount) external returns (bool);`  
  ➤ Grants permission to `spender` to spend up to `amount` tokens.

- `function transferFrom(address from, address to, uint256 amount) external returns (bool);`  
  ➤ Transfers `amount` tokens from `from` to `to` using allowance.

---

## 🔹 SafeERC20 (Library)

Provides **secure wrappers** around the core ERC20 methods to protect against non-standard token behavior (e.g., missing return values).

> All functions are used like: `token.safeTransfer(...)` after applying `using SafeERC20 for IERC20;`

### ✅ Functions

- `function safeTransfer(IERC20 token, address to, uint256 value) external;`  
  ➤ Safely transfers `value` tokens to `to`.

- `function safeTransferFrom(IERC20 token, address from, address to, uint256 value) external;`  
  ➤ Safely transfers `value` tokens from `from` to `to` using allowance.

- `function safeApprove(IERC20 token, address spender, uint256 value) external;`  
  ➤ Safely approves `spender` to spend `value` tokens. May reset to zero first.

- `function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) external;`  
  ➤ Safely increases the current allowance by `value`.

- `function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) external;`  
  ➤ Safely decreases the current allowance by `value`.

---

## ✅ Summary Table

| Category     | Function                    | Description                                  |
|--------------|-----------------------------|----------------------------------------------|
| `IERC20`     | `totalSupply()`             | Total minted tokens                          |
|              | `balanceOf()`               | Check balance                                |
|              | `transfer()`                | Transfer from caller                         |
|              | `transferFrom()`            | Transfer using allowance                     |
|              | `approve()`                 | Grant spending allowance                     |
|              | `allowance()`               | View allowance remaining                     |
| `SafeERC20`  | `safeTransfer()`            | Safe wrapper for transfer                    |
|              | `safeTransferFrom()`        | Safe wrapper for transferFrom                |
|              | `safeApprove()`             | Safe approve (resets if needed)              |
|              | `safeIncreaseAllowance()`   | Increment allowance securely                 |
|              | `safeDecreaseAllowance()`   | Decrement allowance securely                 |

---

🧠 **Tip**: Always prefer `SafeERC20` over raw `IERC20` methods in production code — especially when interacting with third-party tokens.

🛠️ `IERC20` defines the *interface*, `SafeERC20` ensures *safety*.
