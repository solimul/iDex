// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {console} from "../lib/forge-std/src/console.sol";
interface IReentrancyCallback {
    function reenter() external;
}

contract MockERC20 is ERC20 {
    bool public enableReentrancy;
    address public reentrancyTarget;

    constructor(string memory name, string memory symbol)
        ERC20(name, symbol)
    {}

    function mint (address to, uint256 amount) external {
        _mint(to, amount);
    }

    function enableReentrancyAttack(address _target) external {
        enableReentrancy = true;
        reentrancyTarget = _target;
    }

    function disableReentrancyAttack() external {
        enableReentrancy = false;
        reentrancyTarget = address(0);
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);

        // Inject reentrant behavior if enabled
        if (enableReentrancy && reentrancyTarget != address(0)) {
            //console.log ("Reentrancy attack triggered from %s to %s", from, to);
            IReentrancyCallback(reentrancyTarget).reenter();
        }

        return true;
    }
}