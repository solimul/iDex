// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {LiquidityRecord, SwapRecord} from "./Shared.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IDex} from "./IDex.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";


contract Pool is ReentrancyGuard{
    event TokenDepositedToPool(
        string indexed tokenStr,
        address indexed token,
        address indexed depositor,
        uint256 amount,
        uint256 depositCount,
        uint256 timestamp
    );

    error error_OnlyOwnerCanAccessThisFunction (address owner, address sender);
    error error_OnlyFacadeContractCanAccessThisFunction (address owner, address sender);



    IDex private facade;

    address immutable i_owner;
    mapping (address => LiquidityRecord []) private deposits; // token to deposits
    mapping (address => LiquidityRecord []) private withdrawals; // token to withdrawals
    
    mapping (address => uint256) private depositCounts;
    mapping (address => uint256) private withdrawCounts;
    mapping (address => uint256) private balance; 
    mapping (address=>uint256) private totalDeposits;
    mapping (address=>uint256) private totalUelpReceived;
    address [] depositors; // token to deposits
    address [] withdawers;
    
    mapping (address => uint256) lastWithdrawTime;

    mapping (address=>SwapRecord []) swaps;





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
        uint256 _amountOut
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
                    swapper : _swapper,
                    tokenIn : _tokenIn,
                    amountIn: _amountIn,
                    amountOut: _amountOut,
                    timeStamp : time
                }
            )
        );
    }

    function updateStatesOnDeposit
    (
        address _depositor,
        string memory _tokenStr,
        address _token,
        uint256 _amount,
        uint256 _uelp
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
        
        deposits [_token].push (record);
        depositCounts [_token] += 1;
        balance [_token] += _amount;
        totalDeposits [_depositor] += _amount;
        totalUelpReceived [_depositor] += _uelp;
        depositors.push (_depositor);
        
        emit TokenDepositedToPool (_tokenStr, _token, _depositor, _amount, depositCounts [_token], time);
    }

    function updateStatesOnWithdrawal
    (
        address _depositor,
        string memory _tokenStr,
        address _token,
        uint256 _amount,
        uint256 _uelp
    ) 
    public 
    onlyFacade {

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
} 
