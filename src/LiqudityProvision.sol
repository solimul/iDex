// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {BabylonianLib} from "./libs/BabylonianLib.sol";
import {IDex} from "./IDex.sol";



contract LiqudityProvision {

    error error_OnlyOwnerCanAccessThisFunction (address owner, address sender);
    error error_OnlyFacadeCanAccessThisFunction (address facade, address sender);

    uint256 private minimumLiquidity;
    mapping (address => uint256) private totalUELP;
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
    constructor (uint256 _minimumLiquidity) {
        minimumLiquidity = _minimumLiquidity;
        iOwner = msg.sender;
    }

    function updateLiquidityRecord
    (
        address _provider,
        uint256 _uelp
    ) 
    external
    onlyFacade {
        totalUELP [_provider] += _uelp;        
        lpProviders.push (_provider);
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
    public 
    view 
    returns (uint256 lpToMint){
        if (!_seeded) {
            lpToMint = BabylonianLib.sqrt (_usdc*_eth) - minimumLiquidity;
        }
        else {
            uint256 usdcFraction = (_usdc * _tokenTotalSupply) / _usdcReserve;
            uint256 ethFraction = (_eth * _tokenTotalSupply) / _ethReserve;
            lpToMint = usdcFraction > ethFraction ? ethFraction : usdcFraction;
        }
    }

    function setContractReferences (address _idexAddress) external onlyOwner(){
        facade = IDex (_idexAddress);
    }

    function getUELPByProvider 
    (
        address _provider
    ) 
    public
    view
    returns (uint256) {
        return totalUELP [_provider];
    }


}