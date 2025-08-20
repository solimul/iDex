// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {NetworkConfig} from "./NetworkConfig.sol";
import {Pool} from "./Pool.sol";
import {USDC_STR, WETH_STR} from "./Shared.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


contract IDex {
    
    error error_OnlyOwnerCanAccessThisFunction (address owner, address sender);
    error error_DoesNotHaveEnoughBalance (address sender, string token, uint256 balance, uint256 amount);
    error error_DoesNotHaveAllowanceToTransfer (address accessGrantor, address accessRequiredBy, uint256 amount);
    error error_ExternalToInternalTransferFailed (address from, address to, string token, address tokenAddress, uint256 _amount);
    error error_PostTransferBalanceMismatch ();
    error error_InvalidToken (string givenToken, string acceptedTokens);

    event SwapDone (
        address indexed swapper,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 timestamp
    );


    NetworkConfig private config;
    Pool private pool;
    mapping (string => address) public tokenMap;
    address immutable public i_owner;

    modifier onlyOwnerAccess (address _sender) {
    if (_sender != i_owner) 
        revert error_OnlyOwnerCanAccessThisFunction (i_owner, _sender);
        _;
    }

    modifier addressHasEnoughBalance (address _address, string memory _tokenStr, uint256 _amount) {
        IERC20 token = IERC20 (tokenMap [_tokenStr]);
        uint256 balance = token.balanceOf(_address);
        if (balance < _amount) 
            revert error_DoesNotHaveEnoughBalance (_address, _tokenStr, balance, _amount);
        _;
    }

    modifier hasApproval (address _sender, string memory _tokenStr, uint256 _amount) {
        IERC20 token = IERC20 (tokenMap [_tokenStr]);
        if (token.allowance (_sender, address(this)) < _amount) 
            revert error_DoesNotHaveAllowanceToTransfer (_sender, address (this), _amount);
        _;
    }

    modifier validTokens(string memory _tokenStr) {
        bool isValid = (
            keccak256(abi.encodePacked(_tokenStr)) == keccak256(abi.encodePacked(USDC_STR)) ||
            keccak256(abi.encodePacked(_tokenStr)) == keccak256(abi.encodePacked(WETH_STR))
        );

        if (!isValid)
        revert error_InvalidToken (_tokenStr, string.concat(USDC_STR, " | ", WETH_STR));
        _;
    }


    constructor (address _netConfigAddress) {
        config = NetworkConfig (_netConfigAddress);
        tokenMap [USDC_STR] = config.getUSDCContract ();
        tokenMap [WETH_STR] = config.getETHContract(); 
        i_owner = msg.sender; 
    }
    


    function swap(
        uint256 _amount,
        uint256 slippagePercentage,
        string memory _tokenInString,
        string memory _tokenOutString
    ) external
        validTokens (_tokenInString)
        validTokens (_tokenOutString)
        hasApproval (msg.sender, _tokenInString,  _amount)
        addressHasEnoughBalance (msg.sender, _tokenInString, _amount){
        IERC20 tokenIn = IERC20 (tokenMap [_tokenInString]);
        IERC20 tokenOut =   IERC20 (tokenMap [_tokenOutString]);
        uint256 outAmount = pool.calculateOutAmount(_amount, address (tokenIn),address (tokenOut));
        uint256 outTokenBalance0 = tokenOut.balanceOf (address (pool));
        if (outTokenBalance0 < outAmount)
            revert error_DoesNotHaveEnoughBalance (address (pool), _tokenOutString, outTokenBalance0, _amount);
        pool.updateStatesOnSwap (msg.sender, address (tokenIn), address (tokenOut), _amount, outAmount);
        bool success = tokenIn.transferFrom(msg.sender, address (pool), _amount);
        if (!success)
            revert error_ExternalToInternalTransferFailed (msg.sender, address (pool), _tokenInString, address (tokenIn), _amount);

        pool.transferToSwapper(msg.sender, address (tokenOut), outAmount);
        uint256 outTokenBalance1 = tokenOut.balanceOf (address (pool));
        if (outTokenBalance1 != outTokenBalance0 - outAmount)
            revert error_PostTransferBalanceMismatch ();

        emit SwapDone (msg.sender, address (tokenIn), address (tokenOut), _amount, outAmount, block.timestamp);    
    }

    function fundContract 
    (
        string memory _tokenStr, 
        uint256 _amount
    ) 
    external 
    onlyOwnerAccess(msg.sender) 
    hasApproval (msg.sender, _tokenStr,  _amount)
    addressHasEnoughBalance (msg.sender, _tokenStr, _amount){
        IERC20 token = IERC20 (tokenMap [_tokenStr]);
        uint256 balance0 = token.balanceOf(address (pool));
        bool success = token.transferFrom(msg.sender, address (pool), _amount);
        if (!success)
            revert error_ExternalToInternalTransferFailed (msg.sender, address (pool), _tokenStr, address (token), _amount);
        pool.updateStatesOnDeposit (msg.sender, _tokenStr, address (token), _amount);
        uint256 balance1 = token.balanceOf(address (pool));
        if (balance1 != balance0 + _amount)
            revert error_PostTransferBalanceMismatch ();
    }

    function setContractReferences (address _poolAddress) external onlyOwnerAccess(msg.sender){
        pool = Pool (_poolAddress);
    }

}
