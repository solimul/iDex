// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {NetworkConfig} from "./NetworkConfig.sol";
import {Pool} from "./Pool.sol";
import {USDC_STR, WETH_STR, TRILLION_WEI} from "./Shared.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";


contract IDex is ReentrancyGuard {
    
    error error_OnlyOwnerCanAccessThisFunction (address owner, address sender);
    error error_DoesNotHaveEnoughBalance (address sender, string token, uint256 balance, uint256 amount);
    error error_DoesNotHaveAllowanceToTransfer (address accessGrantor, address accessRequiredBy, uint256 amount);
    error error_ExternalToInternalTransferFailed (address from, address to, string token, address tokenAddress, uint256 _amount);
    error error_PostTransferBalanceMismatch ();
    error error_InvalidToken (string givenToken, string acceptedTokens);
    error error_SlippageTooHigh ();
    error error_SameTokenCannotBeExchanged ();
    error error_SenderIsNotValid ();
    error error_NoETHBalance ();
    error error_PoolAlreadySedded ();

    bool public seeded;

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

    modifier onlyOwner () {
    if (msg.sender != i_owner) 
        revert error_OnlyOwnerCanAccessThisFunction (i_owner, msg.sender);
        _;
    }

    modifier addressHasEnoughBalance (address _address, string memory _tokenStr, uint256 _amount) {
        IERC20 token = IERC20 (tokenMap [_tokenStr]);
        uint256 balance = token.balanceOf(_address);
        if (balance < _amount) 
            revert error_DoesNotHaveEnoughBalance (_address, _tokenStr, balance, _amount);
        _;
    }

    modifier hasApproval (string memory _tokenStr, uint256 _amount) {
        IERC20 token = IERC20 (tokenMap [_tokenStr]);
        if (token.allowance (msg.sender, address(this)) < _amount) 
            revert error_DoesNotHaveAllowanceToTransfer (msg.sender, address (this), _amount);
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

    modifier checkIfSameToken (string memory _in, string memory _out) {
        if (keccak256(abi.encodePacked(_in)) == keccak256(abi.encodePacked(_out)))
            revert error_SameTokenCannotBeExchanged ();
        _;
    }

    modifier validSender () {
        if (msg.sender == address (0))
            revert error_SenderIsNotValid ();
        _;
    }

    modifier checkNotSeeded () {
        if (seeded == true)
            revert error_PoolAlreadySedded ();
            _;
    }


    constructor (address _netConfigAddress) {
        config = NetworkConfig (_netConfigAddress);
        tokenMap [USDC_STR] = config.getUSDCContract ();
        tokenMap [WETH_STR] = config.getETHContract(); 
        i_owner = msg.sender; 
        mintLPTokens ();
        seeded = false;
    }
    


    function swap(
        uint256 _amount,
        uint256 slippagePercentage,
        string memory _tokenInString,
        string memory _tokenOutString
    ) external
    validSender
    validTokens (_tokenInString)
    validTokens (_tokenOutString)
    checkIfSameToken(_tokenInString, _tokenOutString)
    hasApproval (_tokenInString,  _amount)
    addressHasEnoughBalance (msg.sender, _tokenInString, _amount)
    nonReentrant {
        IERC20 tokenIn = IERC20 (tokenMap [_tokenInString]);
        IERC20 tokenOut =   IERC20 (tokenMap [_tokenOutString]);
        uint256 outAmount = pool.calculateOutAmount(_amount, address (tokenIn),address (tokenOut));
        
        uint256 minAmountOut = outAmount - (outAmount * slippagePercentage) / 100;
        if (outAmount <= minAmountOut)
        revert error_SlippageTooHigh ();

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


    function seedDex  
    (   
       uint256 _amountUSDC,
       uint256 _amountETH 
    ) 
    external 
    onlyOwner 
    checkNotSeeded {
        addLiquidityDeposit( USDC_STR, _amountUSDC);
        addLiquidityDeposit( WETH_STR, _amountETH);
        seeded = true;
    }

    function addLiquidityDeposit  
    (
        string memory _tokenStr, 
        uint256 _amount
    ) 
    internal 
    hasApproval (_tokenStr,  _amount)
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

    function setContractReferences (address _poolAddress) external onlyOwner(){
        pool = Pool (_poolAddress);
    }

    function getExchangeRate () public view returns (uint256) {
        uint256 usdcBalance = IERC20 (tokenMap [USDC_STR]).balanceOf (address (pool));
        uint256 ethBalance = IERC20 (tokenMap [WETH_STR]).balanceOf (address (pool));
        if (ethBalance == 0)
            revert error_NoETHBalance ();
        uint256 scaledUSDCBalance = usdcBalance * TRILLION_WEI;
        uint256 rate = scaledUSDCBalance / ethBalance;
        return rate;
    }

    function mintLPTokens () 
    internal 
    onlyOwner {

    }

}
