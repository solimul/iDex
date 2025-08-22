// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IDex} from "./IDex.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ProtocolFee, ProtocolFeeDetails, Context} from "./Shared.sol";


contract ProtocolReward {
    event NativeETHReceived (address from, uint256 amount);

    address immutable private iOwner;
    IDex private facade;
    mapping (address => ProtocolFeeDetails ) token2Fees;
    mapping (address => ProtocolFeeDetails) provider2FeesDetail;
    mapping (address => address []) token2Provides;
    mapping (address => mapping (address =>uint256)) providerToFees; 

    error error_OnlyOwnerCanAccessThisFunction (address owner, address sender);
    error error_OnlyFacadeContractCanAccessThisFunction (address owner, address sender);
    error error_DoesNotHaveEnoughBalance(address token, uint256 currentBalance, uint256 requiredAmount);


    modifier onlyOwner () {
    if (msg.sender != iOwner) 
        revert error_OnlyOwnerCanAccessThisFunction (iOwner, msg.sender);
        _;
    }

    modifier onlyFacade () {
    if (msg.sender != address (facade)) 
        revert error_OnlyFacadeContractCanAccessThisFunction (address (facade), msg.sender);
        _;
    }

    modifier hasEnough (address _token, uint256 _amount) {
        uint256 balance = IERC20 (_token).balanceOf (address (this));
        if ( balance < _amount)
            revert error_DoesNotHaveEnoughBalance (_token, balance, _amount);
        _;
    }

    constructor () {
        iOwner = msg.sender;
    }


    function setContractReferences (address _idexAddress) external onlyOwner(){
        facade = IDex (payable (_idexAddress));
    }

    function updateProtocolRewardStateOnSwap 
    (
        address _from,
        address _token,
        uint256 _amount,
        uint256 _swapId
    ) 
    external
    onlyFacade
    {
        ProtocolFee memory fees = ProtocolFee 
                            (
                                {
                                    swapId : _swapId,
                                    amount : _amount,
                                    context : Context.PFeeDeposit
                                }
                            );
        
        token2Fees [_token].totalAmount += _amount;
        token2Fees [_token].fees.push (fees);

        provider2FeesDetail [_from].totalAmount += _amount;
        provider2FeesDetail [_from].fees.push (fees); 

        token2Provides [_token].push(_from);
        providerToFees [_from] [_token] += _amount;
    }

    function withdrawERC20Token 
    (
        address _to, 
        address _token, 
        uint256 _amount
    ) 
    external 
    onlyFacade 
    hasEnough (_token, _amount)
    returns (bool) {
        bool success = IERC20(_token).transfer(_to, _amount);
        return success;
    }

    function viewProtocolRewardBalance 
    (
        address token
    ) 
    external 
    view
    returns (uint256) {
        return IERC20 (token).balanceOf (address (this));
    }

    receive () external payable {
        emit NativeETHReceived (msg.sender, msg.value);
    }

    fallback () external payable {
        emit NativeETHReceived (msg.sender, msg.value);
    }

    
}