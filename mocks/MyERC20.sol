/*
 * SPDX-License-Identifier: MIT
 * Author: Md Solimul Chowdhury
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the “Software”), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

pragma solidity 0.8.30;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {IDex} from "../src/IDex.sol";


/// @dev Interface to be implemented by any contract wishing to receive a reentrant callback
interface IReentrancyCallback {
    function reenter() external;
}

/// @title MyERC20 with Optional Reentrancy Injection
/// @dev This mock token behaves like a standard ERC20 token, but can optionally invoke a reentrant callback
contract MyERC20 is ERC20 {
    error error_OnlyOwnerCanAccessThisFunction (address owner, address sender);
    error error_OnlyFacadeOrOwnerContractCanAccessThisFunction (address owner, address facade, address sender);


    address private immutable iOwner;
    // Flag to enable/disable reentrancy behavior
    bool public enableReentrancy;

    // Address to call back into if reentrancy is enabled
    address public reentrancyTarget;

    IDex private facade;


    modifier onlyOwner () {
    if (msg.sender != iOwner) 
        revert error_OnlyOwnerCanAccessThisFunction (iOwner, msg.sender);
        _;
    }

    modifier onlyOwnerOrFacade () {
        address f = address (facade);
        if (msg.sender !=  iOwner && msg.sender != f) 
            revert error_OnlyFacadeOrOwnerContractCanAccessThisFunction (iOwner, f, msg.sender);
        _;
    }

    /// @notice Creates a mock ERC20 token
    /// @param name Token name
    /// @param symbol Token symbol
    constructor(string memory name, string memory symbol)
        ERC20(name, symbol)
    {
        iOwner = msg.sender;
    }

    /// @notice Mints tokens to a specified address
    /// @dev For testing only; unrestricted minting
    function mint(address to, uint256 amount) external onlyOwnerOrFacade {
        _mint(to, amount);
    }

    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) external onlyOwnerOrFacade{
        _spendAllowance(account, msg.sender, amount); // reduce allowance
        _burn(account, amount);                       // reduce balance & supply
    }

    /// @notice Enables reentrancy attack behavior
    /// @param _target The address that will receive the reentrant callback (must implement `reenter()`)
    function enableReentrancyAttack(address _target) external onlyOwner {
        enableReentrancy = true;
        reentrancyTarget = _target;
    }

    /// @notice Disables reentrancy attack behavior
    function disableReentrancyAttack() external onlyOwner {
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

    function registerContracts (address _idexAddress) external onlyOwner(){
        facade = IDex (payable (_idexAddress));
    }
    
}
