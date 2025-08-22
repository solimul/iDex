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
    
    mapping (address => address []) providers; // token to providers
    mapping (address => uint256) depAddressToIndex;
    mapping (address => address []) withdrawers; // token to withdrawers
    mapping (address => uint256) withdrawersAddressToIndex;

    mapping (address => uint256) lastWithdrawTime;

    mapping (address=>SwapRecord []) swaps;
    mapping (address => uint256 []) inToken2SwapIDs;

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

        balance [_tokenIn] += _amountIn;
        balance [_tokenOut] -= _amountOut;
        uint256 time = block.timestamp;

        swaps [_tokenOut].push ( 
            SwapRecord 
            (
                {
                    id : swapsCount,
                    swapper : _swapper,
                    tokenIn : _tokenIn,
                    amountIn: _amountIn,
                    amountOut: _amountOut,
                    swapFee: _swapFee,
                    timeStamp : time
                }
            )
        );
        inToken2SwapIDs [_tokenIn].push (swapsCount);
        swapsCount += 1;
        totalSwapFees += _swapFee;
    }



    function updateStatesOnProvidence
    (
        address _provider,
        string memory _tokenStr,
        address _token,
        uint256 _amount,
        uint256 _uelp,
        bool _updateUelp
    ) 
    public 
    onlyFacade {
        uint256 time = block.timestamp;
        LiquidityRecord memory record = LiquidityRecord ({
            token: _token,
            amount: _amount,
            uelp: _uelp,
            timeStamp: time
        });
        
        providerCounts [_token] += 1;
        balance [_token] += _amount;
        tokenToTotalProvidenceByProviders [_provider] [_token] += _amount;
        if (_updateUelp==true)
            totalUelpReceived [_provider] += _uelp;

        providers[_token].push (_provider);
        depAddressToIndex [_provider] = providers[_token].length-1;
        
        emit TokenProvidedToPool (_tokenStr, _token, _provider, _amount, providerCounts [_token], time);
    }

    function updateStatesOnWithdrawal
    (
        address _provider,
        string memory _tokenStr,
        address _token,
        uint256 _amount,
        uint256 _uelp,
        bool _updateUelp
    ) 
    public 
    onlyFacade {
        uint256 time = block.timestamp;
        LiquidityRecord memory record = LiquidityRecord ({
            token: _token,
            amount: _amount,
            uelp: _uelp,
            timeStamp: time
        });

        withdrawals [_token].push (record);
        balance [_token] -= _amount;
        tokenToTotalProvidenceByProviders [_provider] [_token] -= _amount;
        if (_updateUelp == true)
            totalUelpReceived [_provider] -= _uelp;
        
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

    function setContractReferences (address _idexAddress) external onlyOwner(){
        facade = IDex (_idexAddress);
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

    
} 


