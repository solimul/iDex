// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {console} from "../lib/forge-std/src/console.sol";

/// @dev Interface to be implemented by any contract wishing to receive a reentrant callback
interface IReentrancyCallback {
    function reenter() external;
}

/// @title MockERC20 with Optional Reentrancy Injection
/// @dev This mock token behaves like a standard ERC20 token, but can optionally invoke a reentrant callback
contract MockERC20 is ERC20 {
    // Flag to enable/disable reentrancy behavior
    bool public enableReentrancy;

    // Address to call back into if reentrancy is enabled
    address public reentrancyTarget;

    /// @notice Creates a mock ERC20 token
    /// @param name Token name
    /// @param symbol Token symbol
    constructor(string memory name, string memory symbol)
        ERC20(name, symbol)
    {}

    /// @notice Mints tokens to a specified address
    /// @dev For testing only; unrestricted minting
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @notice Enables reentrancy attack behavior
    /// @param _target The address that will receive the reentrant callback (must implement `reenter()`)
    function enableReentrancyAttack(address _target) external {
        enableReentrancy = true;
        reentrancyTarget = _target;
    }

    /// @notice Disables reentrancy attack behavior
    function disableReentrancyAttack() external {
        enableReentrancy = false;
        reentrancyTarget = address(0);
    }

    /// @notice Overrides ERC20 `transferFrom` to optionally perform a reentrant callback
    /// @dev If `enableReentrancy` is true, calls `reenter()` on the `reentrancyTarget`
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);

        // Inject reentrant behavior if enabled
        if (enableReentrancy && reentrancyTarget != address(0)) {
            // console.log("Reentrancy attack triggered from %s to %s", from, to);
            IReentrancyCallback(reentrancyTarget).reenter();
        }

        return true;
    }
}
