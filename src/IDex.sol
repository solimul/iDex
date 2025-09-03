// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {console} from "../lib/forge-std/src/console.sol";

import {Pool} from "./Pool.sol";
import {LiquidityProvision} from "./LiquidityProvision.sol";
import {ProtocolReward} from "./ProtocolReward.sol";


import {Params, ProtocolFee, USDC_STR, WETH_STR, TRILLION_WEI, HUNDRED, TEN_K , MILLION} from "./Shared.sol";
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


    event LiquidityWithdrawlDone (address indexed provider);
    event ActivitiesPaused(uint256 until, string reason);
    event ActivitiesUnpaused ();
    event NativeETHReceived (address from, uint256 amount);

    
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
    error error_OnlyLPTokenHoldersCanAccessThisFunction ();
    error error_WithdrawalShareExceedsLimit(uint256 requestedShare, uint256 maxAllowedShare);
    error error_WithdrawalRequestTooEarly(uint256 timeSinceLast, uint256 requiredWindow);
    error error_InternalToExternalTransferFailed ();
    error error_LPBalanceTooLow ();
    error error_InvalidLiquidityProvisionAddress ();
    error error_InvalidMyERC20Address ();
    error error_InvalidPoolAddress ();
    error error_UelpAmountIsZero ();
    error error_SlippageBpsTooHigh (uint256 slippageBps);
    error error_BadQuote ();
    error error_SlippageTooHigh (uint256 quotedOutAmount, uint256 outAmount);
    error error_LPAllowanceTooLow(uint256 have, uint256 need);
    error error_ActivitiesPausedUntil(uint256 until);
    error error_InvalidPauseDuration(uint256 asked, uint256 max);

    error error_PercentageOutOfRange(string field, uint256 value, uint256 max);
    error error_MinLiquidityPpmTooHigh(uint256 value, uint256 max);
    error error_WithdrawCooldownZero();
    error error_AmountIsZero ();

    error error_ProviderNotRegistered ();

    bool public seeded;
    

    Pool private pool;
    LiquidityProvision private liquidityProvision;
    ProtocolReward private protocolReward;
    MyERC20 private merc20;

    mapping (string => address) public tokenMap;
    address immutable i_usdcContract;
    address immutable i_wethContract;

    address immutable public i_owner;
    
    Params private params;

    uint256 maxPauseDuration;
    uint256 pauseUntil;

    bool private testing;

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
        if (address(liquidityProvision) == address(0))
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

    modifier hasLPApproval(address from, uint256 amount) {
        uint256 a = merc20.allowance(from, address(this));
        if (a < amount) 
            revert error_LPAllowanceTooLow(a, amount);
        _;
    }

    modifier activityOpen () {
        if (block.timestamp < pauseUntil) {
            revert error_ActivitiesPausedUntil(pauseUntil);
        }
        _;
    }

    modifier nonZeroAmount (uint256 _amount) {
         if (_amount == 0) 
            revert error_AmountIsZero ();
         _;
    }


    modifier validParamBounds
    (
        uint256 _minLiquidityPpm,
        uint256 _maxWithdrawPct,
        uint256 _withdrawCooldown,
        uint256 _swapFeePct,
        uint256 _protocolFeePct
    ) {
        if (_maxWithdrawPct > HUNDRED)
            revert error_PercentageOutOfRange("maxWithdrawPct", _maxWithdrawPct, HUNDRED);
        if (_swapFeePct > HUNDRED)
            revert error_PercentageOutOfRange("swapFeePct", _swapFeePct, HUNDRED);
        if (_protocolFeePct > HUNDRED)
            revert error_PercentageOutOfRange("protocolFeePct", _protocolFeePct, HUNDRED);
        if (_minLiquidityPpm > MILLION)
            revert error_MinLiquidityPpmTooHigh(_minLiquidityPpm, MILLION);
        if (_withdrawCooldown == 0)
            revert error_WithdrawCooldownZero();
        _;
    }

    constructor 
    (
        address _usdcToken,
        address _ethToken,
        uint256 _minLiquidityPpm, 
        uint256 _maxWithdrawPct, 
        uint256 _withdrawCooldown,
        uint256 _swapFeePct,
        uint256 _protocolFeePct,
        uint256 _maxPauseDuration,
        bool _testing
    ) 
    validParamBounds(_minLiquidityPpm, _maxWithdrawPct, _withdrawCooldown, _swapFeePct, _protocolFeePct) {
        tokenMap [USDC_STR] = _usdcToken;
        tokenMap [WETH_STR] = _ethToken;
        i_owner = msg.sender; 
        seeded = false;

        params.minLiquidityPpm = _minLiquidityPpm;
        params.maxWithdrawPct = _maxWithdrawPct;
        params.withdrawCooldown = _withdrawCooldown;
        params.swapFeePct = _swapFeePct;
        params.protocolFeePct = _protocolFeePct;

        i_usdcContract = tokenMap[USDC_STR];
        i_wethContract = tokenMap[WETH_STR];

        pauseUntil = 0;
        maxPauseDuration = _maxPauseDuration;
        testing = _testing;
    }
    


    function swap(
        uint256 _amountIn,
        uint256 _quotedOut,
        uint256 _slippageBps,
        string memory _tokenInString,
        string memory _tokenOutString
    ) external
    activityOpen
    poolIsSet
    validSender
    validTokens (_tokenInString)
    validTokens (_tokenOutString)
    nonZeroAmount (_amountIn)
    checkIfSameToken(_tokenInString, _tokenOutString)
    hasApproval (msg.sender, _tokenInString,  _amountIn)
    addressHasEnoughBalance (msg.sender, _tokenInString, _amountIn)
    slippageBpsHigh(_slippageBps)
    badQuote (_quotedOut)
    nonReentrant 
    returns (uint256 outAmount){
        /**
        ** check 
        **/
        IERC20 tokenIn = IERC20 (tokenMap [_tokenInString]);
        IERC20 tokenOut =   IERC20 (tokenMap [_tokenOutString]);

        uint256 swapFee = (_amountIn * params.swapFeePct) / HUNDRED;
        uint256 amountIn = _amountIn - swapFee;

        uint256 protocolFee = (swapFee * params.protocolFeePct) / HUNDRED;

        outAmount = pool.calculateOutAmount(amountIn, address (tokenIn),address (tokenOut));
        
        uint256 minAmount = (_quotedOut * _slippageBps) / TEN_K;
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

        // if (outTokenBalance1 != outTokenBalance0 - outAmount)
        //     revert error_PostTransferBalanceMismatch ();


        emit SwapDone (msg.sender, address (tokenIn), address (tokenOut), _amountIn, outAmount, swapFee, protocolFee,block.timestamp);    
    }


    function seedDex  
    (   
       uint256 _usdc,
       uint256 _eth 
    ) 
    external 
    activityOpen
    liquidityProvisionIsSet
    lpTokenIsSet
    poolIsSet
    onlyOwner 
    checkNotSeeded 
    nonReentrant {
        uint256 lp = liquidityProvision.calculateUelpForMinting(_usdc, _eth, 0, 0, 0, seeded);  
        // check
        if (lp == 0)
            revert error_UelpAmountIsZero ();
        
        //effect
        seeded = true;
        liquidityProvision.updateLiquidityRecord (msg.sender, lp);     
        
        // Interactions (+ effects)
        addLiquidityFrom( msg.sender, USDC_STR, _usdc, lp, true);
        addLiquidityFrom( msg.sender, WETH_STR, _eth, lp, false);
        uint256 supply0 = merc20.totalSupply();
        
        // TODO: change this to a fixed 'minimumLiquidity'?
        uint256 minLiquidity = (lp * params.minLiquidityPpm) / MILLION;
        merc20.mint (msg.sender, lp - minLiquidity);
        merc20.mint (address (pool), minLiquidity);

        uint256 supply1 = merc20.totalSupply();
        if (supply1 != supply0 + lp)
            revert error_TotaSupplyMismatchAfterMinting ();
        
        emit LiquidityDepositDone (msg.sender, _usdc, _eth , i_usdcContract, i_wethContract);
    }

    function supplyLiquidity 
    (
        uint256 _usdc, 
        uint256 _eth
    )
    activityOpen
    validSender
    liquidityProvisionIsSet
    poolIsSet
    lpTokenIsSet
    rateIsGood (_usdc, _eth)
    nonZeroAmount (_usdc)
    nonZeroAmount(_eth)
    seedingIsDone
    nonReentrant
    external {


        uint256 usdcReserve = pool.getBalance(i_usdcContract);
        uint256 ethReserve = pool.getBalance(i_wethContract);
        uint256 totalUelpSupply = merc20.totalSupply();

        uint256 lp = liquidityProvision.calculateUelpForMinting(_usdc, _eth, usdcReserve , ethReserve, totalUelpSupply, seeded);
     

        // check
        if (lp == 0) 
            revert error_UelpAmountIsZero();
        //Effect
        liquidityProvision.updateLiquidityRecord(msg.sender, lp);

        // Interactions (+effect)
        addLiquidityFrom(msg.sender, USDC_STR, _usdc, lp, true);
        addLiquidityFrom(msg.sender, WETH_STR, _eth, lp, false);

        merc20.mint (msg.sender, lp);
        
        emit LiquidityDepositDone (msg.sender, _usdc, _eth , i_usdcContract, i_wethContract);
    }

    function withdrawLiquidity (uint256 _lp)
    activityOpen 
    poolIsSet
    lpTokenIsSet
    hasLPApproval (msg.sender, _lp)
    nonReentrant
    external {
        uint256 lpBalance = merc20.balanceOf(msg.sender);
        if (lpBalance == 0)
            revert error_OnlyLPTokenHoldersCanAccessThisFunction ();

        /**
        * Fix: Prevents non-original providers (who only acquired LP tokens via transfer) 
        * from withdrawing liquidity. Thus, turning UELP non-fungible. This ensures provider accounting structures remain consistent.
        *
        * TODO: Implement LP token transfer hooks (e.g. in ERC20 `transfer` / `transferFrom`)
        * to update provider records (`totalUelpReceived`, `tokenToTotalProvidenceByProviders`, etc.)
        * so that LP tokens regain fungibility and any holder can withdraw liquidity.
        */
        if (liquidityProvision.doesProviderExist (msg.sender) == false)
            revert error_ProviderNotRegistered ();
        if (lpBalance < _lp)
            revert error_LPBalanceTooLow ();
        uint256 sharePct = (_lp * HUNDRED) / merc20.totalSupply();
        if (sharePct > params.maxWithdrawPct)
            revert error_WithdrawalShareExceedsLimit (sharePct, params.maxWithdrawPct);
        uint256 lastWithdrawn = pool.getLastWithdrawTime (msg.sender);
        if (block.timestamp - lastWithdrawn < params.withdrawCooldown)
            revert error_WithdrawalRequestTooEarly (block.timestamp - lastWithdrawn, params.withdrawCooldown);

        withdrawLiquidtyTo (msg.sender, USDC_STR, sharePct, _lp, true);
        withdrawLiquidtyTo (msg.sender, WETH_STR, sharePct, _lp, false);

        merc20.burnFrom (msg.sender, _lp);

        emit LiquidityWithdrawlDone (msg.sender);
    }

    function withdrawProtocolReawrd 
    (
        uint256 _amountUSDC,
        uint256 _amountETH
    ) 
    external
    activityOpen 
    onlyOwner
    nonReentrant {
        protocolReward.withdrawERC20Token(msg.sender, tokenMap [USDC_STR], _amountUSDC);
        protocolReward.withdrawERC20Token(msg.sender, tokenMap [WETH_STR], _amountETH);
        protocolReward.updateProtocolRewardStateOnWithdrawal (msg.sender,  tokenMap [USDC_STR], _amountUSDC);
        protocolReward.updateProtocolRewardStateOnWithdrawal (msg.sender,  tokenMap [WETH_STR], _amountETH);
    }

    function viewProtocolRewardBalanceByToken () external view returns (uint256 usdc, uint256 eth) {
        usdc = protocolReward.viewProtocolRewardBalance (i_usdcContract);
        eth = protocolReward.viewProtocolRewardBalance (i_wethContract);
    }


    // function viewProtocolRewardBalanceByUser () external view returns (uint256 usdc, uint256 eth) {
    //     usdc = protocolReward.viewProtocolRewardBalanceByUser (msg.sender, tokenMap [USDC_STR]);
    //     eth = protocolReward.viewProtocolRewardBalanceByUser (msg.sender, tokenMap [WETH_STR]);
    // }

    function withdrawLiquidtyTo 
    (
        address _to,
        string memory _tokenStr,
        uint256 _share,
        uint256 _lp,
        bool _updateUelp
    )
    poolIsSet 
    internal {
        IERC20 token = IERC20 (tokenMap [_tokenStr]);
        uint256 balance0 = token.balanceOf(address (pool));
        uint256 amount = (balance0 * _share) / HUNDRED;
        
        pool.updateStatesOnWithdrawal(_to, _tokenStr, address (token), amount, _lp, _updateUelp);

        bool success = pool.transferTo (_to, address (token), amount);
        if (!success)
            revert error_InternalToExternalTransferFailed ();

        uint256 balance1 = token.balanceOf(address (pool));
        // if (balance1 != balance0 - amount)
        //     revert error_PostTransferBalanceMismatch ();
    }
    
    function addLiquidityFrom  
    (
        address _from,
        string memory _tokenStr, 
        uint256 _amount,
        uint256 _lp,
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
        pool.updateStatesOnProvidence (_from, _tokenStr, address (token), _amount, _lp, _updateUelp);
        uint256 balance1 = token.balanceOf(address (pool));
        // if (balance1 != balance0 + _amount)
        //     revert error_PostTransferBalanceMismatch ();
    }

    function registerContracts 
    (
        address _poolAddress, 
        address _lpAddress, 
        address _protocolReward,
        address _lpTokenAddress
    ) external onlyOwner(){
        pool = Pool (payable (_poolAddress));
        liquidityProvision = LiquidityProvision (_lpAddress);
        protocolReward =  ProtocolReward (payable (_protocolReward));
        merc20 = MyERC20 (_lpTokenAddress);
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

    function pauseActivity
    (
        uint256 _duration, 
        string calldata _reason
    ) 
    external
    activityOpen 
    onlyOwner {
    if (_duration == 0 || _duration > maxPauseDuration) {
        revert error_InvalidPauseDuration(_duration, maxPauseDuration);
        }
        pauseUntil = block.timestamp + _duration;
        emit ActivitiesPaused(pauseUntil, _reason);
    }

    function unpauseAllActivities()  
    onlyOwner
    external { 
        pauseUntil = 0;
        emit ActivitiesUnpaused();
    }

    function quoteOutAmount 
    (
        uint256 _amountIn,
        string memory _tokenInStr,
        string memory _tokenOutStr
    )
    external 
    view
    poolIsSet 
    validTokens(_tokenInStr)
    validTokens (_tokenOutStr)
    returns (uint256) {
        return pool.calculateOutAmount(_amountIn, tokenMap [_tokenInStr], tokenMap [_tokenOutStr]);
    }


    receive () external payable {
        emit NativeETHReceived (msg.sender, msg.value);
    }

    fallback () external payable {
        emit NativeETHReceived (msg.sender, msg.value);
    }

    function getContractAddressForTest () 
    external 
    view 
    returns (address, address, address, address ){
        return (address (pool), address (liquidityProvision), address (protocolReward), address (merc20));
    }

    function getConfigForTest()
    external
    view
    returns (uint256, uint256 , uint256 ,uint256, address)
    {
        return (params.swapFeePct, params.protocolFeePct, params.minLiquidityPpm, params.withdrawCooldown, i_owner);
    }

    function getSwapFeesPct () public view returns (uint256){
       return params.swapFeePct; 
    }

    function getProtocolFeePct () public view returns (uint256){
       return params.protocolFeePct; 
    }

    function getReserves () public view returns (uint256 usdc, uint256 eth) {
        usdc = pool.getBalance (tokenMap [USDC_STR]);
        eth = pool.getBalance(tokenMap [WETH_STR]);
    }

    function getAccruedSweepFees () public view returns (uint256 usdcF, uint256 ethF) {
        usdcF = pool.getAccruedSwapFeesByToken (tokenMap [USDC_STR]);
        ethF = pool.getAccruedSwapFeesByToken (tokenMap [WETH_STR]);
    }

    function getLPBalanceByProvider () public view returns (uint256) {
        return merc20.balanceOf(msg.sender);
    }

    function isSeeded () public view returns (bool) {
        return seeded;
    }

    function isApproved 
    (
        string memory _tokenStr, 
        uint256 _amount
    ) 
    external 
    view
    validTokens (_tokenStr) 
    returns (bool) {
        return _amount <= IERC20 (tokenMap [_tokenStr]).allowance(msg.sender, address(this));
    }

    function getAccruedProtocolFees () 
    public 
    view 
    returns (uint256 usdcF, uint256 ethF) {
        usdcF = protocolReward.viewProtocolRewardBalanceByUser (msg.sender, tokenMap [USDC_STR]);
        ethF = protocolReward.viewProtocolRewardBalanceByUser (msg.sender, tokenMap [WETH_STR]);
    }

    // function isUSDC(string memory _tStr) internal view returns (bool) {
    //     return tokenMap [_tStr] == tokenMap [USDC_STR];
    // }

    function getMyERC20ContractAddress () external view returns (address) {
        return address (merc20);
    }

    function getERC20ContractAddress (string memory _tokenStr) external view returns (address) {
        return tokenMap [_tokenStr];
    }

//     function getAnvilUSDCERC20 () external returns (address){
//         return address (tf);
//     }
}
