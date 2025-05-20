// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AMM} from "./AMM.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {LPool} from "./LPool.sol";
import {console} from "../lib/forge-std/src/console.sol";


contract MinimalDex {

    error ONLY_ETH_USDC_SWAPS_ARE_ALLOWED();
    error INSUFFICIENT_BALANCE (uint256 balance, uint256 amountIn);
    error INSUFFICIENT_LIQUIDITY(uint256 poolBalance, uint256 requestedOut);
    error UNABLE_TO_SWAP_WITH_SAME_PAIRS_OF_TOKENS ();
    error TRANSFER_FAILED (string token, address from, address to, uint256 amount);

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
        if (keccak256(abi.encodePacked(tokenInString)) == keccak256(abi.encodePacked(tokenOutString))) 
            revert UNABLE_TO_SWAP_WITH_SAME_PAIRS_OF_TOKENS ();

        bool validToken = (keccak256(abi.encodePacked(tokenInString)) == keccak256(abi.encodePacked("USDC")) && 
                        keccak256(abi.encodePacked(tokenOutString)) == keccak256(abi.encodePacked("ETH"))) ||
                        (keccak256(abi.encodePacked(tokenInString)) == keccak256(abi.encodePacked("ETH")) && 
                        keccak256(abi.encodePacked(tokenOutString)) == keccak256(abi.encodePacked("USDC")));
        if (!validToken) 
            revert ONLY_ETH_USDC_SWAPS_ARE_ALLOWED ();
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

    function safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );

        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            TRANSFER_FAILED ("", from, to, amount));
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
        
        uint256 amountOut = amm.calculateOutAmount (amountIn, tokenIn, tokenOut);
        amm.checkInsufficientLiquidity (tokenOut, amountOut);
         (LPool (amm.getLPoolAddress ())).updateLPool(tokenOut, amountIn, amountOut);
        amm.enforceInvariant(tokenOut, amountOut);

        // Transfer the tokens  
        // from the swapper to the contract
        //IERC20 (tokenIn).transferFrom (from, to, amountIn);
        safeTransferFrom(tokenIn, from, to, amountIn);

        // Transfer the tokens from the contract to the swapper
        //console.log("to: ", to, IERC20(tokenOut).balanceOf (to));
        //IERC20(tokenOut).transferFrom(to, from, amountOut);
        safeTransferFrom(tokenOut, to, from, amountOut);
       
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

    function getTokenAddress2String (address token) external view returns (string memory) {
        return amm.getTokenString (token);
    }

    

}