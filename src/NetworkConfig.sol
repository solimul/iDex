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

/**
 * @dev Interface for the ERC20 standard as defined in the EIP.
 * IERC20 provides function signatures for common token operations 
 * like transfer, approve, and allowance, but does not implement any logic.
 * Used to interact with any compliant ERC20 token.
 */
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @dev SafeERC20 wraps around IERC20 functions and ensures safe execution.
 * It prevents issues with non-standard ERC20 tokens that do not return a boolean.
 * Commonly used to safely perform token transfers, approvals, etc.
 */
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {MyERC20} from "../mocks/MyERC20.sol";

contract NetworkConfig {

    address private immutable i_owner;
    address private immutable i_usdc;
    address private immutable i_eth;
    MyERC20 private immutable i_MyERC20_usdc;
    MyERC20 private immutable i_MyERC20_eth;

    constructor () {
        i_owner = msg.sender;
        if (block.chainid == 31337) { // test-net 
            i_usdc = address(new MyERC20("Mock USDC", "mUSDC"));
            i_eth = address(new MyERC20("Mock ETH", "mETH"));

        } else if (block.chainid == 11155111) {  // sepolia
            i_usdc = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238 ; // USDC
            i_eth = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9; // WETH
            /** 
             * Token	Faucet
                    USDC	https://sepoliafaucet.com/ or from Aave/Gelato testnet UI
                    WETH	Chainlink Sepolia Faucet
             * **/
        }
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
    // Define the mainnet and testnet addresses for USDC and WETH
}