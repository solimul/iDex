// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AMM} from "./AMM.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {LPool} from "./LPool.sol";
import {console} from "../lib/forge-std/src/console.sol";


contract MinimalDex {

    error TOKENS_NEED_TO_BE_EITHER_USDC_OR_ETH();
    error INSUFFICIENT_BALANCE (uint256 balance, uint256 amountIn);
    error INSUFFICIENT_LIQUIDITY(uint256 poolBalance, uint256 requestedOut);

    event Swapped (
        uint256 amountIn,
        address tokenIn,
        uint256 amountOut,
        address tokenOut
    );


    AMM private amm;
    address private immutable i_owner;
    

    constructor (uint256 _usdcAmount, uint256 _ethAmount) {
        amm = new AMM (_usdcAmount, _ethAmount);
        i_owner = msg.sender;
    }

    modifier onlyOwner () {
        require (msg.sender == i_owner, "Not the owner");
        _;
    }

    function getAMM () external view returns (address)  {
        return address(amm);
    }

    function getOwner () external view returns (address) {
        return i_owner;
    }

    modifier checkStrings (string memory tokenInString, string memory tokenOutString) {

       bool validToken = (keccak256(abi.encodePacked(tokenInString)) == keccak256(abi.encodePacked("USDC")) && 
                        keccak256(abi.encodePacked(tokenOutString)) == keccak256(abi.encodePacked("ETH"))) ||
                        (keccak256(abi.encodePacked(tokenInString)) == keccak256(abi.encodePacked("ETH")) && 
                        keccak256(abi.encodePacked(tokenOutString)) == keccak256(abi.encodePacked("USDC")));
        if (!validToken)
            revert TOKENS_NEED_TO_BE_EITHER_USDC_OR_ETH();
        _;
    }


function checkInsuffientBalance (
        address tokenIn,
        uint256 amountIn,
        address swapper
    ) private view {
        if (IERC20 (tokenIn).balanceOf (swapper) < amountIn) 
            revert INSUFFICIENT_BALANCE (IERC20 (tokenIn).balanceOf (swapper), amountIn);
    }

    function enforceSlippageRequirement (
        uint256 amountIn,
        uint256 slippagePrecentage,
        address tokenIn,
        address tokenOut
    ) internal view {
        uint256 expectedOut = amm.calculateOutAmount(amountIn, tokenIn, tokenOut);
        uint256 minAmountOut = (expectedOut * (100 - slippagePrecentage)) / 100;

        // Get the actual output again (redundant, but simulate reality)
        if (expectedOut < minAmountOut) {
            revert INSUFFICIENT_LIQUIDITY(expectedOut, minAmountOut);
        }
    }

    function swap  ( 
        uint256 amountIn,
        uint256 slippagePrecentage,
        string memory tokenInString,
        string memory tokenOutString
       ) public checkStrings(tokenInString, tokenOutString) {
        //amm.swapTokens(amountIn, slippagePrecentage, tokenInString, tokenOutString);
        address tokenIn = amm.getTokenAddress(tokenInString);
        address tokenOut = amm.getTokenAddress(tokenOutString);

        address from = msg.sender;
        address to =  amm.getLPoolAddress();

        checkInsuffientBalance (tokenIn, amountIn, from);
        enforceSlippageRequirement (amountIn, slippagePrecentage, tokenIn, tokenOut);
        // Transfer the tokens  
        // from the swapper to the contract
        IERC20 (tokenIn).transferFrom (from, to, amountIn);
        uint256 amountOut = amm.calculateOutAmount (amountIn, tokenIn, tokenOut);
        amm.checkInsufficientLiquidity (tokenOut, amountOut);
        // Transfer the tokens from the contract to the swapper
        //console.log("to: ", to, IERC20(tokenOut).balanceOf (to));
        IERC20(tokenOut).transferFrom(to, from, amountOut);

        (LPool (amm.getLPoolAddress ())).updateLPool(tokenOut, amountIn, amountOut);
        amm.enforceInvariant(tokenOut, amountOut);
        emit Swapped (amountIn, tokenIn, amountOut, tokenOut);
    }

    function fundContract (address sender) public {
        amm.fundContract(sender);
    }

    function getUSDCContract () external view returns (address) {
        return amm.getUSDCContract();
    }
    function getETHContract () external view returns (address) {
        return amm.getETHContract();
    }

    function getLPoolAddress () external view returns (address) {
        return amm.getLPoolAddress();
    }

    

}