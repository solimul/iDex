// /*
//  * SPDX-License-Identifier: MIT
//  * Author: Md Solimul Chowdhury
//  *
//  * Permission is hereby granted, free of charge, to any person obtaining a copy
//  * of this software and associated documentation files (the “Software”), to deal
//  * in the Software without restriction, including without limitation the rights
//  * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  * copies of the Software, and to permit persons to whom the Software is
//  * furnished to do so, subject to the following conditions:
//  *
//  * The above copyright notice and this permission notice shall be included in all
//  * copies or substantial portions of the Software.
//  *
//  * THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  * SOFTWARE.
//  */

// pragma solidity 0.8.30;

// import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// import {MockERC20} from "../mocks/MockERC20.sol";
// import {MinimalDex} from "../src/MinimalDex.sol";
// import {LPool} from "../src/LPool.sol";
// import {Script} from "../lib/forge-std/src/Script.sol";

// contract TestSetup is Script {
//     uint256 public constant ANVIL_CHAINID = 31337;
//     uint256 public constant SEPOLIA_CHAINID = 11155111;

//     /// @notice Configure initial funding and approvals for the pool
//     function configureFundingAndApprovals(MinimalDex dex, LPool lpool, uint256 reserveUSDC, uint256 reserveETH) external {
//         if (block.chainid == SEPOLIA_CHAINID) {
//             address usdc = dex.getUSDCContract();
//             address weth = dex.getETHContract();

//             // These run under the broadcasted EOA
//             IERC20(usdc).approve(lpool.getLPoolAddress(), type(uint256).max);
//             IERC20(weth).approve(lpool.getLPoolAddress(), type(uint256).max);
//         } else if (block.chainid == ANVIL_CHAINID) {
//             // Mint mock tokens to LPool directly for testing
//             MockERC20(dex.getUSDCContract()).mint(address(lpool), reserveUSDC);
//             MockERC20(dex.getETHContract()).mint(address(lpool), reserveETH);

//             IERC20(dex.getUSDCContract()).approve(address(lpool), type(uint256).max);
//             IERC20(dex.getETHContract()).approve(address(lpool), type(uint256).max);
//         }
//     }

//     /// @notice Mint tokens and approve spender (for Anvil/mock tokens only)
//     function mintApproveToken(
//         address token,
//         address to,
//         address spender,
//         uint256 amount
//     ) external {
//         if (block.chainid == ANVIL_CHAINID) {
//             MockERC20(token).mint(to, amount);
//             // The approval must come from the `to` address (i.e., the token holder)
//             vm.prank(to);
//             // Approve the spender to pull tokens from the `to` address
//             MockERC20(token).approve(spender, type(uint256).max);
//         }
//     }

//     /// @notice Approve DEX to pull tokens from another contract (e.g., LPool)
//     function approveDexToPullFrom(
//         address token,
//         address from,
//         address dex
//     ) external {
//         vm.startPrank(from);
//         IERC20(token).approve(dex, type(uint256).max);
//         vm.stopPrank();
//     }
// }
