// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {LiquidityRecord, SwapRecord, ProtocolFeeDetails} from "./Shared.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IDex} from "./IDex.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";


contract Pool is ReentrancyGuard{

    event TokenProvidedToPool(
        string indexed tokenStr,
        address indexed token,
        address indexed provider,
        uint256 amount,
        uint256 providerCounts,
        uint256 timestamp
    );

    event TokenWithdrawnFromPool(
        string indexed tokenStr,
        address indexed token,
        address indexed provider,
        uint256 amount,
        uint256 providerCounts,
        uint256 timestamp
    );

    event NativeETHReceived (address from, uint256 amount);


    error error_OnlyOwnerCanAccessThisFunction (address owner, address sender);
    error error_OnlyFacadeContractCanAccessThisFunction (address owner, address sender);



    IDex private facade;

    address immutable i_owner;
    mapping (address => LiquidityRecord []) private providences; // token to providences
    mapping (address => LiquidityRecord []) private withdrawals; // token to withdrawals
    
    mapping (address => uint256) private providerCounts;
    mapping (address => uint256) private withdrawCounts;
    mapping (address => uint256) private balance; 
    mapping (address=> mapping (address => uint256)) private tokenToTotalProvidenceByProviders;
    mapping (address=>uint256) private totalUelpReceived;
    
    mapping (address => mapping (address=>uint256)) tokenProviders; // token to providers
    mapping (address => address []) withdrawers; // token to withdrawers
    mapping (address => uint256) withdrawersAddressToIndex;

    mapping (address => uint256) lastWithdrawTime;

    mapping (address=>SwapRecord []) swaps;

    uint256 private swapsCount;
    uint256 private totalSwapFees;


    modifier onlyOwner () {
    if (msg.sender != i_owner) 
        revert error_OnlyOwnerCanAccessThisFunction (i_owner, msg.sender);
        _;
    }

    modifier onlyFacade () {
    if (msg.sender != address (facade)) 
        revert error_OnlyFacadeContractCanAccessThisFunction (address (facade), msg.sender);
        _;
    }

    constructor () {
        i_owner = msg.sender;
    }

    function calculateOutAmount(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) 
    public 
    view 
    returns (uint256) {
        IERC20 token = IERC20 (tokenIn);
        uint256 reserveIn = token.balanceOf(address (this));
        token =  IERC20 (tokenOut);
        uint256 reserveOut = token.balanceOf (address (this));
        return (amountIn * reserveOut) / (reserveIn + amountIn);
    }

    function updateStatesOnSwap 
    (
        address _swapper,
        address _tokenIn, 
        address _tokenOut, 
        uint256 _amountIn, 
        uint256 _amountOut,
        uint256 _swapFee
    )
    external
    onlyFacade {

        balance [_tokenIn] += _amountIn + _swapFee;
        balance [_tokenOut] -= _amountOut;
        uint256 time = block.timestamp;

        swaps [_tokenOut].push ( 
            SwapRecord 
            (
                {
                    id : swapsCount,
                    swapper : _swapper,
                    tokenIn : _tokenIn,
                    amountIn: _amountIn + _swapFee,
                    amountOut: _amountOut,
                    swapFee: _swapFee,
                    timeStamp : time
                }
            )
        );
        swapsCount += 1;
        totalSwapFees += _swapFee;
    }

    


    function updateStatesOnProvidence
    (
        address _provider,
        string memory _tokenStr,
        address _token,
        uint256 _amount,
        uint256 _lp,
        bool _updateUelp
    ) 
    public 
    onlyFacade {
        uint256 time = block.timestamp;
        LiquidityRecord memory record = LiquidityRecord ({
            token: _token,
            amount: _amount,
            lp: _lp,
            timeStamp: time
        });

        providences [_token].push (record);
        
        providerCounts [_token] += 1;
        balance [_token] += _amount;
        tokenToTotalProvidenceByProviders [_provider] [_token] += _amount;
        if (_updateUelp==true)
            totalUelpReceived [_provider] += _lp;

        tokenProviders[_token] [_provider] += 1;
        
        emit TokenProvidedToPool (_tokenStr, _token, _provider, _amount, providerCounts [_token], time);
    }

    function updateStatesOnWithdrawal
    (
        address _provider,
        string memory _tokenStr,
        address _token,
        uint256 _amount,
        uint256 _lp,
        bool _updateUelp
    ) 
    public 
    onlyFacade {
        uint256 time = block.timestamp;
        LiquidityRecord memory record = LiquidityRecord ({
            token: _token,
            amount: _amount,
            lp: _lp,
            timeStamp: time
        });

        withdrawals [_token].push (record);
        balance [_token] -= _amount;
        tokenToTotalProvidenceByProviders [_provider] [_token] -= _amount;
        if (_updateUelp == true)
            totalUelpReceived [_provider] -= _lp;
        
        lastWithdrawTime [_provider] = time;

        emit TokenWithdrawnFromPool (_tokenStr, _token, _provider, _amount, providerCounts [_token], time);

    }



    function transferTo(
        address _to,
        address _token,
        uint256 _amount
    ) 
    external 
    onlyFacade
    nonReentrant
    returns (bool){
        bool success = IERC20(_token).transfer (_to, _amount);
        return success;
    }

    function registerContracts (address _idexAddress) external onlyOwner(){
        facade = IDex (payable (_idexAddress));
    }

    function getBalance (address _token) public view returns (uint256 ){
        return IERC20 (_token).balanceOf (address (this));
    } 

    function getLastWithdrawTime (address _provider) public view returns (uint256 ){
        return lastWithdrawTime [_provider];
    } 

    function getSwapsCount () public view returns (uint256) {
        return swapsCount;
    }

    receive () external payable {
        emit NativeETHReceived (msg.sender, msg.value);
    }

    fallback () external payable {
        emit NativeETHReceived (msg.sender, msg.value);
    }

    function getPoolRecord4ProvidenceTest 
    (
        address _provider,
        address _token
    ) 
    external
    view
    returns 
    (
        address token,
        uint256 amount,
        uint256 lp,
        uint256 pCounts,
        uint256 totalBalanceByToken,
        uint256 tokenProviderBalance,
        uint256 totalUelpByProvider,
        uint256 providerProvidedForThisToken

    ) {
        pCounts = getProviderCountByToken (_token);
        totalBalanceByToken = getTotalBalanceByToken (_token);

        if (tokenToTotalProvidenceByProviders [_provider] [_token] == 0)
            return (_token, 0, 0, pCounts, totalBalanceByToken, 0, 0, 0);
        LiquidityRecord storage recordByToken = providences [_token] [pCounts-1];
        token = recordByToken.token;
        amount = recordByToken.amount;
        lp = recordByToken.lp;
        tokenProviderBalance = tokenToTotalProvidenceByProviders [_provider] [_token];
        totalUelpByProvider = totalUelpReceived [_provider];
        providerProvidedForThisToken = tokenProviders[_token] [_provider];
    }

    function getProviderCountByToken (address _token) public view returns (uint256){
        return providerCounts [_token];
    }

    function getTotalBalanceByToken (address _token) public view returns (uint256) {
        return balance [_token];
    }

    function getSwapBalanceUpdate4Test 
    (
        address _tokenIn, 
        address _tokenOut
    ) 
    public
    view
    returns 
    (
        uint256 balance_tokenIn,
        uint256 balance_tokenOut,
        uint256 _swapsCount,
        address _swapper,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOut,
        uint256 swapFee,
        uint256 _totalSwapFee
    )  {
        if (swapsCount == 0)
            return (getBalance (_tokenIn), getBalance (_tokenOut), 0, address (0), _tokenIn, 0, 0, 0, totalSwapFees);
        balance_tokenIn = balance [_tokenIn];
        balance_tokenOut = balance [_tokenOut];
        SwapRecord memory r = swaps [_tokenOut] [swapsCount-1];
        _swapsCount = r.id+1;
        _swapper = r.swapper;
        amountIn = r.amountIn;
        amountOut = r.amountOut;
        swapFee = r.swapFee;
        _totalSwapFee = totalSwapFees;
        tokenIn = _tokenIn;
    }
    
} 


