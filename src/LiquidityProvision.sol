// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {console} from "../lib/forge-std/src/console.sol";

import {BabylonianLib} from "./libs/BabylonianLib.sol";
import {IDex} from "./IDex.sol";

import {TRILLION_WEI} from "./Shared.sol";


contract LiquidityProvision {

    error error_OnlyOwnerCanAccessThisFunction (address owner, address sender);
    error error_OnlyFacadeCanAccessThisFunction (address facade, address sender);
    error error_BadReservesOrSupply(uint256 usdcReserve, uint256 ethReserve, uint256 tokenTotalSupply);


    mapping (address => uint256) private totalLP;
    mapping (address => uint256) private providerIndex;
    mapping (address => bool) private providerEnabled;
    address [] private lpProviders;
    address private immutable iOwner;
    IDex private facade;

    modifier onlyFacade () {
        if (msg.sender != address (facade)) {
            revert error_OnlyFacadeCanAccessThisFunction (address (facade), msg.sender);
        }
        _;
    }

    modifier onlyOwner () {
    if (msg.sender != iOwner) 
        revert error_OnlyOwnerCanAccessThisFunction (iOwner, msg.sender);
        _;
    }

    modifier validReservesAndSupply(
        bool _seeded,
        uint256 _usdcReserve,
        uint256 _ethReserve,
        uint256 _tokenTotalSupply
    ) {
        if (_seeded == true) {
            if (_usdcReserve == 0 || _ethReserve == 0 || _tokenTotalSupply == 0) {
                revert error_BadReservesOrSupply(_usdcReserve, _ethReserve, _tokenTotalSupply);
            }
        }
        _;
    }
    constructor () {
        iOwner = msg.sender;
    }

    function updateLiquidityRecord
    (
        address _provider,
        uint256 _lp
    ) 
    external
    onlyFacade {
        if (providerEnabled [_provider] == false){
            lpProviders.push (_provider);
        }
        totalLP [_provider] += _lp;
        providerIndex [_provider] = lpProviders.length-1;      
        providerEnabled [_provider] = true;

    }

    function calculateUelpForMinting 
    (
        uint256 _usdc, 
        uint256 _eth, 
        uint256 _usdcReserve,
        uint256 _ethReserve,
        uint256 _tokenTotalSupply,
        bool _seeded
    )
    validReservesAndSupply(_seeded, _usdcReserve, _ethReserve, _tokenTotalSupply)
    public 
    pure 
    returns (uint256 lpToMint){
        uint256 scaledUSDC = _usdc * TRILLION_WEI;

        if (!_seeded) {
            lpToMint = BabylonianLib.sqrt (scaledUSDC*_eth);
        }
        else {
            uint256 scaledUSDCReserve =  _usdcReserve * TRILLION_WEI;
            uint256 usdcFraction = (scaledUSDC * _tokenTotalSupply) / scaledUSDCReserve;
            uint256 ethFraction = (_eth * _tokenTotalSupply) / _ethReserve;
            lpToMint = usdcFraction > ethFraction ? ethFraction : usdcFraction;
        }
    }

    function registerContracts (address _idexAddress) external onlyOwner(){
        facade = IDex (payable (_idexAddress));
    }

    function doesProviderExist ( address _provider) public view returns (bool) {
        return providerEnabled [_provider];
    }

    function getLPByProvider 
    (
        address _provider
    ) 
    public
    view
    returns (uint256) {
        return totalLP [_provider];
    }

    function getLiquidityRecord4Test 
    (
        address _provider
    ) 
    external
    view
    returns (uint256 _totalLP, uint256 cntLPProviders) {
        if (providerIndex [_provider] == 0)
            return (0, lpProviders.length);
        (_totalLP, cntLPProviders) = (totalLP [_provider], lpProviders.length);       
    }
}