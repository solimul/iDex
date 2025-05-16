// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {LPool} from "./LPool.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";


/**
 * @title AMM
 * @author Md Solimul Chowdhury
 * @notice This contract is an Automated Market Maker (AMM) for ETH and USDC.
 * @dev It allows users to deposit and withdraw ETH and USDC, and provides functions to get the reserves of each token.
 */

contract AMM {
    error INSUFFICIENT_SWAP_AMOUNT();
    error NEEDS_DIFFERENT_TOKEN ();
    error TOKENS_NEED_TO_BE_EITHER_USDC_OR_ETH();
    error INSUFFICIENT_BALANCE (uint256 balance, uint256 amountIn);
    error INSUFFICIENT_LIQUIDITY(uint256 poolBalance, uint256 requestedOut);
    error INVARIANT_BROKEN(uint256 poolBalance, uint256 requestedOut);
    error UNSUPPORTED_OUT_TOKEN();
    error UNSUPPORTED_IN_TOKEN_DECIMALS(uint8 decimalsIn);
    error UNSUPPORTED_OUT_TOKEN_DECIMALS(uint8 decimalsOut);

    event Swapped (
        uint256 amountIn,
        address tokenIn,
        uint256 amountOut,
        address tokenOut
    );

    // 1ETH = 1500 USDC
    // 1 USDC = 0.00066667 ETH



    LPool private lPool;
    address private immutable i_owner;
    address private immutable i_usdc;
    address private immutable i_eth;

    uint256 private immutable invariant;

    mapping (string => address) private tokenMap;

    constructor (uint256 USDC_RESERVE, uint256 ETH_RESERVE) {
        lPool = new LPool( ETH_RESERVE, USDC_RESERVE );
        i_usdc = lPool.getUSDCContract ();
        i_eth = lPool.getETHContract ();
        invariant = USDC_RESERVE * ETH_RESERVE;
        tokenMap["USDC"] = i_usdc;
        tokenMap["ETH"] = i_eth;
    }

    modifier validCoins (address tokenOut){
        require(tokenOut == i_usdc || tokenOut == i_eth, UNSUPPORTED_OUT_TOKEN ());

        // Infer tokenIn based on tokenOut
        address tokenIn = tokenOut == i_usdc ? i_eth : i_usdc;

        uint8 decimalsIn  = IERC20Metadata(tokenIn).decimals();
        uint8 decimalsOut = IERC20Metadata(tokenOut).decimals();
        require(decimalsIn == 6 || decimalsIn == 18, UNSUPPORTED_IN_TOKEN_DECIMALS (decimalsIn));
        require(decimalsOut == 6 || decimalsOut == 18, UNSUPPORTED_OUT_TOKEN_DECIMALS (decimalsOut));
        _;
    }


    function getLPoolAddress () external view returns (address) {
        return address(lPool);
    }
    function getUSDCContract () external view returns (address) {
        return i_usdc;
    }
    function getETHContract () external view returns (address) {
        return i_eth;
    }
 


    function getAMMAddress () external view returns (address) {
        return address(this);
    }

    function getTokenAddress (string memory tokenString) external view returns (address) {
        address tokenAddress = tokenMap[tokenString];
        if (tokenAddress == address(0)) {
            revert TOKENS_NEED_TO_BE_EITHER_USDC_OR_ETH();
        }
        return tokenAddress;
    }


    function enforceInvariant(address tokenOut, uint256 amountOut) public view {
        console.log("Invariant: ", invariant, lPool.getInvariant(), invariant * 999 / 1000);
        if (lPool.getInvariant() < invariant * 999 / 1000) {
            revert INVARIANT_BROKEN(IERC20(tokenOut).balanceOf(address(lPool)), amountOut);
        }
    }

    function calculateOutAmount(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) public view validCoins(tokenOut) returns (uint256) {
        uint256 reserveIn;
        uint256 reserveOut;

        if (tokenIn == i_usdc && tokenOut == i_eth) {
            reserveIn = lPool.getUSDCPoolAmount();
            reserveOut = lPool.getETHPoolAmount();
        } else if (tokenIn == i_eth && tokenOut == i_usdc) {
            reserveIn = lPool.getETHPoolAmount();
            reserveOut = lPool.getUSDCPoolAmount();
        } else {
            revert("Unsupported token pair");
        }

        return (amountIn * reserveOut) / (reserveIn + amountIn);
    }

    function checkInsufficientLiquidity (
        address tokenOut,
        uint256 amountOut
    ) public view {
        if (IERC20(tokenOut).balanceOf(address (lPool)) < amountOut) 
            revert INSUFFICIENT_LIQUIDITY(IERC20(tokenOut).balanceOf(address (lPool)), amountOut);
    }

    function fundContract (
        address sender
    ) public {
        lPool.fundContract(sender);
    }

}