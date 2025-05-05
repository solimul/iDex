// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {LPool} from "./LPool.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {console} from "../lib/forge-std/src/console.sol";


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
    



    modifier requireCheck (
        uint256 amountIn,
        address tokenIn,
        address tokenOut
        ) {
         if (amountIn <=0 ) revert INSUFFICIENT_SWAP_AMOUNT();
        if (tokenIn == tokenOut) revert NEEDS_DIFFERENT_TOKEN();
        bool validToken = (tokenIn == i_usdc && tokenOut == i_eth)
                        || (tokenIn == i_eth && tokenOut == i_usdc); 
        if (!validToken) revert TOKENS_NEED_TO_BE_EITHER_USDC_OR_ETH();
        _;
    }

    function enforceInvariant(address tokenOut, uint256 amountOut) public view {
        console.log("Invariant: ", invariant, lPool.getInvariant(), invariant * 999 / 1000);
        if (lPool.getInvariant() < invariant * 999 / 1000) {
            revert INVARIANT_BROKEN(IERC20(tokenOut).balanceOf(address(lPool)), amountOut);
        }
    }

    function calculateOutAmount (
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) public view returns (uint256) {
        uint256 amountOut;
        if (tokenIn == i_usdc && tokenOut == i_eth) {
            amountOut = (amountIn * lPool.getETHPoolAmount()) / (lPool.getUSDCPoolAmount() + amountIn);
        } else if (tokenIn == i_eth && tokenOut == i_usdc) {
            amountOut = (amountIn * lPool.getUSDCPoolAmount()) / (lPool.getETHPoolAmount() + amountIn);
        }
        return amountOut;
    }

    function checkInsufficientLiquidity (
        address tokenOut,
        uint256 amountOut
    ) public view {
        if (IERC20(tokenOut).balanceOf(address (lPool)) < amountOut) 
            revert INSUFFICIENT_LIQUIDITY(IERC20(tokenOut).balanceOf(address (lPool)), amountOut);
    }

    


    // function swap  (
    //     uint256 amountIn,
    //     uint256 slippagePrecentage,
    //     address tokenIn,
    //     address tokenOut
    // ) private requireCheck (amountIn, tokenIn, tokenOut) {
    //     address swapper = address (lPool);
    //     console.log("Swapper: ", swapper, lPool.getUSDCAmount(), lPool.getETHAmount());

    //     checkInsuffientBalance (tokenIn, amountIn, swapper);
    //     enforceSlippageRequirement (amountIn, slippagePrecentage, tokenIn, tokenOut);
    //     // Transfer the tokens  
    //     // from the swapper to the contract
    //     //IERC20 (tokenIn).transferFrom (swapper, address (this), amountIn);
    //     lPool.transferToken (tokenIn, amountIn);
    //     uint256 amountOut = calculateOutAmount (amountIn, tokenIn, tokenOut);
    //     checkInsufficientLiquidity (tokenOut, amountOut);
    //     // Transfer the tokens from the contract to the swapper
    //     IERC20(tokenOut).transfer(swapper, amountOut);
    //     lPool.updateLPool(tokenOut, amountIn, amountOut);
    //     enforceInvariant (tokenOut, amountOut);
    //     emit Swapped (amountIn, tokenIn, amountOut, tokenOut);
    // }

    // function swapTokens (
    //     uint256 amountIn,
    //     uint256 slippagePrecentage,
    //     string memory tokenInString,
    //     string memory tokenOutString
    // ) public  {
    //     bool validToken = (keccak256(abi.encodePacked(tokenInString)) == keccak256(abi.encodePacked("USDC")) && 
    //                     keccak256(abi.encodePacked(tokenOutString)) == keccak256(abi.encodePacked("ETH"))) ||
    //                     (keccak256(abi.encodePacked(tokenInString)) == keccak256(abi.encodePacked("ETH")) && 
    //                     keccak256(abi.encodePacked(tokenOutString)) == keccak256(abi.encodePacked("USDC")));
    //     if (!validToken)
    //         revert TOKENS_NEED_TO_BE_EITHER_USDC_OR_ETH();
        

    //     address tokenIn = tokenMap[tokenInString];
    //     address tokenOut = tokenMap[tokenOutString];

    //     if (tokenIn == address(0) || tokenOut == address(0)) {
    //         revert TOKENS_NEED_TO_BE_EITHER_USDC_OR_ETH();
    //     }
    //     swap (amountIn, slippagePrecentage, tokenIn, tokenOut);
    // }

    function fundContract (
        address sender
    ) public {
        lPool.fundContract(sender);
    }

}