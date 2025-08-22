// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {NetworkConfig} from "./NetworkConfig.sol";
import {Pool} from "./Pool.sol";
import {LiqudityProvision} from "./LiqudityProvision.sol";
import {ProtocolReward} from "./ProtocolReward.sol";


import {Params, ProtocolFee, USDC_STR, WETH_STR, TRILLION_WEI, LPTOKEN_NAME, LPTOKEN_SYMBOL, HUNDRED, MILLION} from "./Shared.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {MyERC20} from "../mocks/MyERC20.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";


contract IDex is ReentrancyGuard {

    event LiquidityDepositDone(
        address indexed provider,
        uint256 usdcAmount,
        uint256 ethAmount,
        address usdcToken,
        address wethToken
    );

    event LiquidityWithdrawlDone (address indexed provider);

    
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
    error error_TotaSupplyMismatchAfterMinting ();
    error error_DepositRatioTooLow(uint256 userRate, uint256 poolRate);
    error error_PoolHasNotBeenSeddedYet ();
    error error_OnlyUELPTokenHoldersCanAccessThisFunction ();
    error error_WithdrawalShareExceedsLimit(uint256 requestedShare, uint256 maxAllowedShare);
    error error_WithdrawalRequestTooEarly(uint256 timeSinceLast, uint256 requiredWindow);
    error error_InternalToExternalTransferFailed ();
    error error_UELPBalanceTooLow ();


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
    LiqudityProvision private liqudityProvision;
    ProtocolReward private protocolReward;
    MyERC20 private merc20;

    mapping (string => address) public tokenMap;
    address immutable public i_owner;
    
    Params private params;

    modifier onlyOwner () {
    if (msg.sender != i_owner) 
        revert error_OnlyOwnerCanAccessThisFunction (i_owner, msg.sender);
        _;
    }

    modifier addressHasEnoughBalance (address _from, string memory _tokenStr, uint256 _amount) {
        IERC20 token = IERC20 (tokenMap [_tokenStr]);
        uint256 balance = token.balanceOf(_from);
        if (balance < _amount) 
            revert error_DoesNotHaveEnoughBalance (_from, _tokenStr, balance, _amount);
        _;
    }

    modifier hasApproval (address _from, string memory _tokenStr, uint256 _amount) {
        IERC20 token = IERC20 (tokenMap [_tokenStr]);
        if (token.allowance (_from, address(this)) < _amount) 
            revert error_DoesNotHaveAllowanceToTransfer (_from, address (this), _amount);
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

    modifier rateIsGood (uint256 _usdc, uint256 _eth) {
        uint256 poolRate = getPoolExchangeRate();
        uint256 userRate = getExchangeRate(_usdc, _eth); 
        if (userRate < poolRate) {
            revert error_DepositRatioTooLow(userRate, poolRate);
        }
        _;
    }

    modifier seedingIsDone () {
        if (seeded == false)
            revert error_PoolHasNotBeenSeddedYet ();
            _;
    }


    constructor 
    (
        address _netConfigAddress, 
        uint256 _minLiquidityPpm, 
        uint256 _maxWithdrawPct, 
        uint256 _withdrawCooldown,
        uint256 _swapFeePct,
        uint256 _protocolFeePct
    ) {
        config = NetworkConfig (_netConfigAddress);
        tokenMap [USDC_STR] = config.getUSDCContract ();
        tokenMap [WETH_STR] = config.getETHContract(); 
        i_owner = msg.sender; 
        createLPToken (LPTOKEN_NAME, LPTOKEN_SYMBOL);
        seeded = false;

        params.minLiquidityPpm = _minLiquidityPpm;
        params.maxWithdrawPct = _maxWithdrawPct;
        params.withdrawCooldown = _withdrawCooldown;
        params.swapFeePct = _swapFeePct;
        params.protocolFeePct = _protocolFeePct;
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
    hasApproval (msg.sender, _tokenInString,  _amount)
    addressHasEnoughBalance (msg.sender, _tokenInString, _amount)
    nonReentrant {
        // check
        IERC20 tokenIn = IERC20 (tokenMap [_tokenInString]);
        IERC20 tokenOut =   IERC20 (tokenMap [_tokenOutString]);

        uint256 swapFee = (_amount * params.swapFeePct) / HUNDRED;
        uint256 amountIn = _amount - swapFee;

        uint256 protocolFee = (swapFee * params.protocolFeePct) / HUNDRED;
        swapFee -=  protocolFee;



        uint256 outAmount = pool.calculateOutAmount(amountIn, address (tokenIn),address (tokenOut));
        
        uint256 minAmountOut = outAmount - ((outAmount * slippagePercentage) / HUNDRED);
        if (outAmount <= minAmountOut)
            revert error_SlippageTooHigh ();


       uint256 outTokenBalance0 = tokenOut.balanceOf (address (pool));

        if (outTokenBalance0 < outAmount)
            revert error_DoesNotHaveEnoughBalance (address (pool), _tokenOutString, outTokenBalance0, amountIn);
 

        //effect
        uint256  swapId = pool.getSwapsCount () + 1;
        protocolReward.updateProtocolRewardStateOnSwap (msg.sender, address (tokenIn), protocolFee, swapId);
        pool.updateStatesOnSwap (msg.sender, address (tokenIn), address (tokenOut), amountIn, outAmount, swapFee);

        //interaction

        // transfer amountIn and swapFee to pool       
        bool success = tokenIn.transferFrom(msg.sender, address (pool), amountIn + swapFee);
        if (!success)
            revert error_ExternalToInternalTransferFailed (msg.sender, address (pool), _tokenInString, address (tokenIn), amountIn + swapFee);

        // transfer part of the swapFee to the protocol reward contract
        success = tokenIn.transferFrom(msg.sender, address (protocolReward), protocolFee);

        // payback outAmount to the swapper
        pool.transferTo (msg.sender, address (tokenOut), outAmount);
        
        uint256 outTokenBalance1 = tokenOut.balanceOf (address (pool));
        if (outTokenBalance1 != outTokenBalance0 - outAmount)
            revert error_PostTransferBalanceMismatch ();


        emit SwapDone (msg.sender, address (tokenIn), address (tokenOut), _amount, outAmount, block.timestamp);    
    }


    function seedDex  
    (   
       uint256 _usdc,
       uint256 _eth 
    ) 
    external 
    onlyOwner 
    checkNotSeeded {
        uint256 uelp = liqudityProvision.calculateUelpForMinting(_usdc, _eth, 0, 0, 0, seeded);        
        addLiquidityFrom( msg.sender, USDC_STR, _usdc, uelp);
        addLiquidityFrom( msg.sender, WETH_STR, _eth, uelp);
        uint256 supply0 = merc20.totalSupply();
        
        // TODO: change this to a fixed 'minimumLiquidity'?
        uint256 minLiquidity = (uelp * params.minLiquidityPpm) / MILLION;
        merc20.mint (msg.sender, uelp - minLiquidity);
        merc20.mint (address (pool), minLiquidity);

        uint256 supply1 = merc20.totalSupply();
        if (supply1 != supply0 + uelp)
            revert error_TotaSupplyMismatchAfterMinting ();
        seeded = true;
        
        emit LiquidityDepositDone (msg.sender, _usdc, _eth , tokenMap [USDC_STR], tokenMap [WETH_STR]);
    }

    function supplyLiquidity 
    (
        uint256 _usdc, 
        uint256 _eth
    )
    rateIsGood (_usdc, _eth)
    seedingIsDone
    external {

        uint256 usdcReserve = pool.getBalance(tokenMap [USDC_STR]);
        uint256 ethReserve = pool.getBalance(tokenMap [WETH_STR]);
        uint256 totalUelpSupply = merc20.totalSupply();

        uint256 uelp = liqudityProvision.calculateUelpForMinting(_usdc, _eth, usdcReserve , ethReserve, totalUelpSupply, seeded);

        liqudityProvision.updateLiquidityRecord(msg.sender, uelp);
        addLiquidityFrom(msg.sender, USDC_STR, _usdc, uelp);
        addLiquidityFrom(msg.sender, WETH_STR, _eth, uelp);

        
        merc20.mint (msg.sender, uelp);
        
        emit LiquidityDepositDone (msg.sender, _usdc, _eth , tokenMap [USDC_STR], tokenMap [WETH_STR]);
    }

    function withdrawLiquidity (uint256 _uelp) 
    external {
        uint256 uelpBalance = merc20.balanceOf(msg.sender);
        if (uelpBalance == 0)
            revert error_OnlyUELPTokenHoldersCanAccessThisFunction ();
        if (uelpBalance < _uelp)
            revert error_UELPBalanceTooLow ();
        uint256 sharePct = (_uelp * HUNDRED) / merc20.totalSupply();
        if (sharePct > params.maxWithdrawPct)
            revert error_WithdrawalShareExceedsLimit (sharePct, params.maxWithdrawPct);
        uint256 lastWithdrawn = pool.getLastWithdrawTime (msg.sender);
        if (block.timestamp - lastWithdrawn < params.withdrawCooldown)
            revert error_WithdrawalRequestTooEarly (block.timestamp - lastWithdrawn, params.withdrawCooldown);

        withdrawLiquidtyTo (msg.sender, USDC_STR, sharePct, _uelp);
        withdrawLiquidtyTo (msg.sender, WETH_STR, sharePct, _uelp);

        merc20.burnFrom (msg.sender, _uelp);

        emit LiquidityWithdrawlDone (msg.sender);
    }

    function withdrawProtocolReawrd 
    (
        string memory _tokenStr, 
        uint256 _amount
    ) 
    external 
    onlyOwner {
        protocolReward.withdrawERC20Token(msg.sender, tokenMap [_tokenStr], _amount);
    }

    function viewProtocolRewardBalance () external view returns (uint256 usdc, uint256 eth) {
        usdc = protocolReward.viewProtocolRewardBalance (tokenMap [USDC_STR]);
        eth = protocolReward.viewProtocolRewardBalance (tokenMap [WETH_STR]);
    }

    function withdrawLiquidtyTo 
    (
        address _to,
        string memory _tokenStr,
        uint256 _share,
        uint256 _uelp
    ) 
    internal {
        IERC20 token = IERC20 (tokenMap [_tokenStr]);
        uint256 balance0 = token.balanceOf(address (pool));
        uint256 amount = (balance0 * _share) / HUNDRED;
        
        pool.updateStatesOnWithdrawal(_to, _tokenStr, address (token), amount, _uelp);

        bool success = pool.transferTo (_to, address (token), amount);
        if (!success)
            revert error_InternalToExternalTransferFailed ();

        uint256 balance1 = token.balanceOf(address (pool));
        if (balance1 != balance0 - amount)
            revert error_PostTransferBalanceMismatch ();
    }
    
    function addLiquidityFrom  
    (
        address _from,
        string memory _tokenStr, 
        uint256 _amount,
        uint256 _uelp
    ) 
    internal 
    hasApproval (_from, _tokenStr,  _amount)
    addressHasEnoughBalance (_from, _tokenStr, _amount){
        IERC20 token = IERC20 (tokenMap [_tokenStr]);
        uint256 balance0 = token.balanceOf(address (pool));
        bool success = token.transferFrom(_from, address (pool), _amount);
        if (!success)
            revert error_ExternalToInternalTransferFailed (_from, address (pool), _tokenStr, address (token), _amount);
        pool.updateStatesOnDeposit (_from, _tokenStr, address (token), _amount, _uelp);
        uint256 balance1 = token.balanceOf(address (pool));
        if (balance1 != balance0 + _amount)
            revert error_PostTransferBalanceMismatch ();
    }

    function setContractReferences (address _poolAddress, address _lpAddress, address payable _protocolReward) external onlyOwner(){
        pool = Pool (_poolAddress);
        liqudityProvision = LiqudityProvision (_lpAddress);
        protocolReward =  ProtocolReward (_protocolReward);
    }

    function getPoolExchangeRate () public view returns (uint256) {
        uint256 usdcBalance = IERC20 (tokenMap [USDC_STR]).balanceOf (address (pool));
        uint256 ethBalance = IERC20 (tokenMap [WETH_STR]).balanceOf (address (pool));
        if (ethBalance == 0)
            revert error_NoETHBalance ();
        uint256 scaledUSDCBalance = usdcBalance * TRILLION_WEI;
        uint256 rate = scaledUSDCBalance / ethBalance;
        return rate;
    }

    function getExchangeRate 
    (
        uint256 _usdc, 
        uint256 _eth
    ) 
    public 
    pure 
    returns (uint256) {
        uint256 scaledUSDC = _usdc * TRILLION_WEI;
        return scaledUSDC / _eth;
    }

    function createLPToken 
    (
        string memory _name, 
        string memory _symbol
    ) 
    internal 
    onlyOwner {
        merc20 = new MyERC20 (_name, _symbol);
    }

}
