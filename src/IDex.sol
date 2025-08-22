// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {NetworkConfig} from "./NetworkConfig.sol";
import {Pool} from "./Pool.sol";
import {LiqudityProvision} from "./LiqudityProvision.sol";
import {ProtocolReward} from "./ProtocolReward.sol";


import {Params, ProtocolFee, USDC_STR, WETH_STR, TRILLION_WEI, LPTOKEN_NAME, LPTOKEN_SYMBOL, HUNDRED, TEN_K , MILLION} from "./Shared.sol";
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
    error error_InvalidLiquidityProvisionAddress ();
    error error_InvalidMyERC20Address ();
    error error_InvalidPoolAddress ();
    error error_UelpAmountIsZero ();
    error error_SlippageBpsTooHigh (uint256 slippageBps);
    error error_BadQuote ();
    error error_SlippageTooHigh (uint256 quotedOutAmount, uint256 outAmount);
    error error_UELPAllowanceTooLow(uint256 have, uint256 need);



    bool public seeded;

    event SwapDone (
        address indexed swapper,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 swapFee,
        uint256 protocolFee,
        uint256 timestamp
    );


    NetworkConfig private config;
    Pool private pool;
    LiqudityProvision private liqudityProvision;
    ProtocolReward private protocolReward;
    MyERC20 private merc20;

    mapping (string => address) public tokenMap;
    address immutable i_usdcContract;
    address immutable i_wethContract;

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

    modifier liquidityProvisionIsSet() {
        if (address(liqudityProvision) == address(0))
            revert error_InvalidLiquidityProvisionAddress();
        _;
    }

    modifier lpTokenIsSet() {
        if (address(merc20) == address(0))
            revert error_InvalidMyERC20Address();
        _;
    }

    modifier poolIsSet() {
        if (address(pool) == address(0))
            revert error_InvalidPoolAddress();
        _;
    }

    modifier slippageBpsHigh (uint256 slippageBps) {
         if (slippageBps > TEN_K) 
            revert error_SlippageBpsTooHigh (slippageBps);
         _;
    }

    modifier badQuote (uint256 _quote) {
        if (_quote == 0)
            revert error_BadQuote ();
        _;
    }

    modifier hasUELPApproval(address from, uint256 amount) {
        uint256 a = merc20.allowance(from, address(this));
        if (a < amount) 
            revert error_UELPAllowanceTooLow(a, amount);
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

        i_usdcContract = tokenMap[USDC_STR];
        i_wethContract = tokenMap[WETH_STR];
    }
    


    function swap(
        uint256 _amountIn,
        uint256 _quotedOut,
        uint256 _slippageBps,
        string memory _tokenInString,
        string memory _tokenOutString
    ) external
    poolIsSet
    validSender
    validTokens (_tokenInString)
    validTokens (_tokenOutString)
    checkIfSameToken(_tokenInString, _tokenOutString)
    hasApproval (msg.sender, _tokenInString,  _amountIn)
    addressHasEnoughBalance (msg.sender, _tokenInString, _amountIn)
    slippageBpsHigh(_slippageBps)
    badQuote (_quotedOut)
    nonReentrant {
        /**
        ** check 
        **/
        IERC20 tokenIn = IERC20 (tokenMap [_tokenInString]);
        IERC20 tokenOut =   IERC20 (tokenMap [_tokenOutString]);

        uint256 swapFee = (_amountIn * params.swapFeePct) / HUNDRED;
        uint256 amountIn = _amountIn - swapFee;

        uint256 protocolFee = (swapFee * params.protocolFeePct) / HUNDRED;

        uint256 outAmount = pool.calculateOutAmount(amountIn, address (tokenIn),address (tokenOut));
        
        uint256 minAmount = (_quotedOut *  (TEN_K - _slippageBps)) / TEN_K;
        if (outAmount < minAmount)
            revert error_SlippageTooHigh (_quotedOut, minAmount);
        


       uint256 outTokenBalance0 = tokenOut.balanceOf (address (pool));

        if (outTokenBalance0 < outAmount)
            revert error_DoesNotHaveEnoughBalance (address (pool), _tokenOutString, outTokenBalance0, outAmount);
 

        /**
        ** effect 
        **/
        swapFee -=  protocolFee;
        uint256  nextSwapId = pool.getSwapsCount () + 1;
        protocolReward.updateProtocolRewardStateOnSwap (msg.sender, address (tokenIn), protocolFee, nextSwapId);
        pool.updateStatesOnSwap (msg.sender, address (tokenIn), address (tokenOut), amountIn, outAmount, swapFee);

        /**
        ** check 
        **/

        // transfer amountIn and swapFee to pool       
        bool success = tokenIn.transferFrom(msg.sender, address (pool), amountIn + swapFee);
        if (!success)
            revert error_ExternalToInternalTransferFailed (msg.sender, address (pool), _tokenInString, address (tokenIn), amountIn + swapFee);

        // transfer part of the swapFee to the protocol reward contract
        success = tokenIn.transferFrom(msg.sender, address (protocolReward), protocolFee);
        if (!success)
            revert error_ExternalToInternalTransferFailed (msg.sender, address (protocolReward), _tokenInString, address (tokenIn), protocolFee);

        // payback outAmount to the swapper
        success = pool.transferTo (msg.sender, address (tokenOut), outAmount);
        if (!success) 
        revert error_InternalToExternalTransferFailed();

        uint256 outTokenBalance1 = tokenOut.balanceOf (address (pool));

        if (outTokenBalance1 != outTokenBalance0 - outAmount)
            revert error_PostTransferBalanceMismatch ();


        emit SwapDone (msg.sender, address (tokenIn), address (tokenOut), _amountIn, outAmount, swapFee, protocolFee,block.timestamp);    
    }


    function seedDex  
    (   
       uint256 _usdc,
       uint256 _eth 
    ) 
    external 
    liquidityProvisionIsSet
    lpTokenIsSet
    poolIsSet
    onlyOwner 
    checkNotSeeded {
        uint256 uelp = liqudityProvision.calculateUelpForMinting(_usdc, _eth, 0, 0, 0, seeded);  
        // check
        if (uelp == 0)
            revert error_UelpAmountIsZero ();
        
        //effect
        seeded = true;
        liqudityProvision.updateLiquidityRecord (msg.sender, uelp);     
        
        // Interactions (+ effects)
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
        
        emit LiquidityDepositDone (msg.sender, _usdc, _eth , i_usdcContract, i_wethContract);
    }

    function supplyLiquidity 
    (
        uint256 _usdc, 
        uint256 _eth
    )
    liquidityProvisionIsSet
    poolIsSet
    lpTokenIsSet
    rateIsGood (_usdc, _eth)
    seedingIsDone
    external {

        uint256 usdcReserve = pool.getBalance(i_usdcContract);
        uint256 ethReserve = pool.getBalance(i_wethContract);
        uint256 totalUelpSupply = merc20.totalSupply();

        uint256 uelp = liqudityProvision.calculateUelpForMinting(_usdc, _eth, usdcReserve , ethReserve, totalUelpSupply, seeded);
        // check
        if (uelp == 0) 
            revert error_UelpAmountIsZero();
        //Effect
        liqudityProvision.updateLiquidityRecord(msg.sender, uelp);
        // Interactions (+effect)
        addLiquidityFrom(msg.sender, USDC_STR, _usdc, uelp, true);
        addLiquidityFrom(msg.sender, WETH_STR, _eth, uelp, false);

        merc20.mint (msg.sender, uelp);
        
        emit LiquidityDepositDone (msg.sender, _usdc, _eth , i_usdcContract, i_wethContract);
    }

    function withdrawLiquidity (uint256 _uelp) 
    poolIsSet
    lpTokenIsSet
    hasUELPApproval (msg.sender, _uelp)
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

        withdrawLiquidtyTo (msg.sender, USDC_STR, sharePct, _uelp, true);
        withdrawLiquidtyTo (msg.sender, WETH_STR, sharePct, _uelp, false);

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
        usdc = protocolReward.viewProtocolRewardBalance (i_usdcContract);
        eth = protocolReward.viewProtocolRewardBalance (i_wethContract);
    }

    function withdrawLiquidtyTo 
    (
        address _to,
        string memory _tokenStr,
        uint256 _share,
        uint256 _uelp,
        bool _updateUelp
    )
    poolIsSet 
    internal {
        IERC20 token = IERC20 (tokenMap [_tokenStr]);
        uint256 balance0 = token.balanceOf(address (pool));
        uint256 amount = (balance0 * _share) / HUNDRED;
        
        pool.updateStatesOnWithdrawal(_to, _tokenStr, address (token), amount, _uelp, _updateUelp);

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
        uint256 _uelp,
        bool _updateUelp
    ) 
    internal 
    poolIsSet
    hasApproval (_from, _tokenStr,  _amount)
    addressHasEnoughBalance (_from, _tokenStr, _amount){
        IERC20 token = IERC20 (tokenMap [_tokenStr]);
        uint256 balance0 = token.balanceOf(address (pool));
        bool success = token.transferFrom(_from, address (pool), _amount);
        if (!success)
            revert error_ExternalToInternalTransferFailed (_from, address (pool), _tokenStr, address (token), _amount);
        pool.updateStatesOnProvidence (_from, _tokenStr, address (token), _amount, _uelp, _updateUelp);
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
        uint256 usdcBalance = IERC20 (i_usdcContract).balanceOf (address (pool));
        uint256 ethBalance = IERC20 (i_wethContract).balanceOf (address (pool));
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
