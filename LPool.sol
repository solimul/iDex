/*
 * SPDX-License-Identifier: MIT
 * Author: Md Solimul Chowdhury
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the “Software”), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

pragma solidity 0.8.30;
import {NetworkConfig} from "./NetworkConfig.sol";
import {MyERC20} from "../mocks/MyERC20.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title LPool
 * @author Md Solimul Chowdhury
 * @notice This contract is a liquidity pool for ETH and USDC.
 * @dev It allows users to deposit and withdraw ETH and USDC, and provides functions to get the reserves of each token.
 */
contract LPool {

    error NOT_OWNER();
    error ETH_NEGATIVE();
    error USDC_NEGATIVE();

    event ReserveInitialized (uint256 reserveETH, uint256 reserveUSDC);
    event ReserveETHUpdated (uint256 reserveETH);
    event ReserveUSDCUpdated (uint256 reserveUSDC);
    event ReservesReset (uint256 reserveETH, uint256 reserveUSDC);


    uint256 private s_reserveETH;
    uint256 private s_reserveUSDC;
    NetworkConfig public immutable networkConfig;

    address private immutable i_owner;
    address private immutable i_usdc;
    address private immutable i_eth;

    constructor (uint256 _reserveETH, uint256 _reserveUSDC) {  
        i_owner = msg.sender;
        s_reserveETH = _reserveETH;
        s_reserveUSDC = _reserveUSDC;
        networkConfig = new NetworkConfig ();
        i_eth = networkConfig.getETHContract ();
        i_usdc = networkConfig.getUSDCContract ();
        emit ReserveInitialized (_reserveETH, _reserveUSDC);
    }

    modifier onlyOwner () {
        if (msg.sender != i_owner) revert NOT_OWNER();
        _;
    }

    modifier validCoins (address tokenOut) {
        require(tokenOut == i_usdc || tokenOut == i_eth, "Unsupported tokenOut");

        // Infer tokenIn based on tokenOut
        address tokenIn = tokenOut == i_usdc ? i_eth : i_usdc;

        uint8 decimalsIn  = IERC20Metadata(tokenIn).decimals();
        uint8 decimalsOut = IERC20Metadata(tokenOut).decimals();
        require(decimalsIn == 6 || decimalsIn == 18, "Unsupported decimals");
        require(decimalsOut == 6 || decimalsOut == 18, "Unsupported decimals");
        _;
    }

    function getETHPoolAmount () external view returns (uint256) {
        return s_reserveETH;
    }

    function getUSDCPoolAmount () external view returns (uint256) {
        return s_reserveUSDC;
    }

    function getUSDCAmount () external view returns (uint256) {
        return IERC20(i_usdc).balanceOf(address(this));
    }

    function getETHAmount () external view returns (uint256) {
        return IERC20(i_eth).balanceOf(address(this));
    }

    function getOwner () external view returns (address) {
        return i_owner;
    }

    function getUSDCContract () external view returns (address) {
        return i_usdc;
    }

    function getETHContract () external view returns (address) {
        return i_eth;
    }

      function getLPoolAddress () external view returns (address) {
        return address(this);
    }

    function getInvariant () external view returns (uint256) {
        return s_reserveETH * s_reserveUSDC;
    }

    function updateLPool(
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
        ) external validCoins(tokenOut) {
        // Adjust pool reserves based on direction
        if (tokenOut == i_usdc) {
            // ETH → USDC swap
            s_reserveETH  += amountIn;     // amountIn is in wei (18 decimals)
            s_reserveUSDC -= amountOut;    // amountOut is in USDC micro-units (6 decimals)
        } else {
            // USDC → ETH swap
            s_reserveUSDC += amountIn;     // amountIn is in USDC micro-units (6 decimals)
            s_reserveETH  -= amountOut;    // amountOut is in wei (18 decimals)
        }
        emit ReserveETHUpdated(s_reserveETH);
        emit ReserveUSDCUpdated(s_reserveUSDC);
    }


    function fundContract(address sender) public {
        if (block.chainid == 31337) {
            // Local testing — mint directly to LPool
            MyERC20 usdc = MyERC20(i_usdc);
            MyERC20 eth = MyERC20(i_eth);
            usdc.mint(address(this), s_reserveUSDC);
            eth.mint(address(this), s_reserveETH);
        } else if (block.chainid == 11155111) {
            // Sepolia — pull funds from external sender
            bool usdcSuccess = IERC20(i_usdc).transferFrom(sender, address(this), s_reserveUSDC);
            bool ethSuccess = IERC20(i_eth).transferFrom(sender, address(this), s_reserveETH);

            require(usdcSuccess, "USDC funding failed");
            require(ethSuccess, "ETH funding failed");
        }  
    }

}