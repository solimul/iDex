//SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "../../lib/forge-std/src/Script.sol";
import {Test} from "../../lib/forge-std/src/Test.sol";
import {MinimalDex} from "../../src/MinimalDex.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {HelperConfig} from "../../helper/HelperConfig.h.sol";   
import {LPool} from "../../src/LPool.sol";
import {AMM} from "../../src/AMM.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";

contract MinimalDexTest is Test {
    uint256 private _reserveUSDC = 1 * 10 ** 6; // 1 USDC (6 decimals)
    uint256 private _rserveETH = 1 * 10 ** 15; // 0.001 WETH (18 decimals)
    LPool private lpool;

    function setUp() public {
        // Deploy the MinimalDex contract
        vm.startBroadcast();
        MinimalDex dex = new MinimalDex(_reserveUSDC, _rserveETH);
        vm.stopBroadcast();
        lpool = LPool (dex.getLPoolAddress ());
    }

    function testReserveETH() public {
        uint256 reserveETH = lpool.getReserveETH();
        assertEq(reserveETH, _rserveETH, "Reserve ETH should be 0.001");
    }
    
    function testReserveUSDC() public {
        uint256 reserveUSDC = lpool.getReserveUSDC();
        console.log ("Reserve USDC: ", reserveUSDC, _reserveUSDC, block.chainid);
        assertEq(reserveUSDC, _reserveUSDC, "Reserve USDC should be 1");
    }
}

