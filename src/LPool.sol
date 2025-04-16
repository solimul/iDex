// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;
import {Funding} from "./Funding.sol";
import {NetworkConfig} from "./NetworkConfig.sol";

/**
 * @title LPool
 * @author Md Solimul Chowdhury
 * @notice This contract is a liquidity pool for ETH and DAI.
 * @dev It allows users to deposit and withdraw ETH and DAI, and provides functions to get the reserves of each token.
 */
contract LPool {

    error NOT_OWNER();
    error ETH_NEGATIVE();
    error DAI_NEGATIVE();

    event ReserveInitialized (uint256 reserveETH, uint256 reserveDAI);
    event ReserveETHUpdated (uint256 reserveETH);
    event ReserveDAIUpdated (uint256 reserveDAI);
    event ReservesReset (uint256 reserveETH, uint256 reserveDAI);


    uint256 private s_reserveETH;
    uint256 private s_reserveDAI;
    NetworkConfig public immutable networkConfig;

    address private immutable i_owner;
    address private immutable i_dai;
    address private immutable i_eth;

    constructor (uint256 _reserveETH, uint256 _reserveDAI) {  
        i_owner = msg.sender;
        s_reserveETH = _reserveETH;
        s_reserveDAI = _reserveDAI;
        networkConfig = new NetworkConfig ();
        i_eth = networkConfig.getETHContract ();
        i_dai = networkConfig.getDAIContract ();
        new Funding (i_dai, i_eth, msg.sender, _reserveETH, _reserveDAI);
        emit ReserveInitialized (_reserveETH, _reserveDAI);
    }

    modifier onlyOwner () {
        if (msg.sender != i_owner) revert NOT_OWNER();
        _;
    }

    function getReserveETH () external view returns (uint256) {
        return s_reserveETH;
    }

    function getReserveDAI () external view returns (uint256) {
        return s_reserveDAI;
    }

    function getOwner () external view returns (address) {
        return i_owner;
    }

    function getDAIContract () external view returns (address) {
        return i_dai;
    }

    function getETHContract () external view returns (address) {
        return i_eth;
    }

    function getInvariant () external view returns (uint256) {
        return s_reserveETH * s_reserveDAI;
    }


    function updateReserveETH (uint256 _reserveETH) external {
        s_reserveETH = _reserveETH;
        emit ReserveETHUpdated(_reserveETH);
    }

    function updateReserveDAI (uint256 _reserveDAI) external  {
        s_reserveDAI = _reserveDAI;
        emit ReserveDAIUpdated(_reserveDAI);
    }

    function resetReserves (uint256 _reserveETH, uint256 _reserveDAI) external onlyOwner {
        s_reserveETH = _reserveETH;
        s_reserveDAI = _reserveDAI;
        emit ReservesReset(_reserveETH, _reserveDAI);
    }

    function updateLPool (
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    ) external {
            if (tokenOut == i_dai) {
            s_reserveETH = s_reserveETH + amountIn;
            s_reserveDAI = s_reserveDAI - amountOut;
        } else {
            s_reserveDAI = s_reserveDAI + amountOut;
            s_reserveETH = s_reserveETH - amountIn;
        }
    }

    



}