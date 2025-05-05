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

    error SWAP_NOT_ENOUGH_LIQUIDITY(uint256 available, uint256 required); 
    uint256 private _reserveUSDC = 1 * 10 ** 6; // 1 USDC (6 decimals)
    uint256 private _rserveETH = 1 * 10 ** 15; // 0.001 WETH (18 decimals)
    LPool private lpool;
    AMM private amm;
    MinimalDex dex ;

    function getDeployerKeyName() internal view returns (string memory) {
        string memory privateKeyName;
        if (block.chainid == 11155111) {
          privateKeyName = "PRIVATE_KEY";
        } else if (block.chainid == 31337) {
          privateKeyName = "ANVIL_PRIVATE_KEY";
        }
        return privateKeyName;
    }

    function configureApprovals(MinimalDex dex) internal {
        if (block.chainid == 11155111) {
            address usdcContract  = dex.getUSDCContract();
            address wethContract  = dex.getETHContract();

            // these execute as txs from your EOA because broadcast is active
            IERC20(usdcContract).approve(lpool.getLPoolAddress(), type(uint256).max);    // 1 USDC (6 decimals)
            IERC20(wethContract).approve(lpool.getLPoolAddress(), type(uint256).max);   // 0.001 WETH (18 decimals)
        } else if (block.chainid == 31337) {
            // For local testing, we can use the MockERC20 contract to mint tokens
            MockERC20 usdc = MockERC20(dex.getUSDCContract());
            MockERC20 weth = MockERC20(dex.getETHContract());
            usdc.mint(address (lpool), _reserveUSDC);
            weth.mint(address (lpool), _rserveETH);
            IERC20(dex.getUSDCContract()).approve(address(lpool), type(uint256).max);
            IERC20(dex.getETHContract()).approve(address(lpool), type(uint256).max);
        }
    }

    function setUp() public {
        // Deploy the MinimalDex contract
        uint256 deployerKey = vm.envUint(getDeployerKeyName());
        address deployer   = vm.addr(deployerKey);
        vm.startBroadcast();
        dex = new MinimalDex(_reserveUSDC, _rserveETH);
        lpool = LPool(dex.getLPoolAddress());

                // 2) Approve LPool to pull tokens
        configureApprovals(dex);
        // 3) Fund the pool (pulls from deployer)
        dex.fundContract(deployer);
        vm.stopBroadcast();
    }

    function testReserveETH() public view {
        uint256 reserveETH = lpool.getETHPoolAmount();
        console.log ("reserveETH: ", reserveETH, _rserveETH);
        assertEq(reserveETH, _rserveETH, "Reserve ETH should be 0.001");
    }

    function testReserveUSDC() public view {
        uint256 reserveUSDC = lpool.getUSDCPoolAmount();
        assertEq(reserveUSDC, _reserveUSDC, "Reserve USDC should be 1");
    }

    function testSwapExpectRevert() public {
        // ── 1) seed yourself & approve the DEX for the user-pull ──
        MockERC20 usdc = MockERC20(dex.getUSDCContract());
        usdc.mint(address(this), _reserveUSDC * 10);
        usdc.approve(address(dex), type(uint256).max);

        // ── 2) now tell LPool to approve the DEX for the pool-pull ──
        vm.startPrank(address(lpool));
        IERC20(dex.getUSDCContract()).approve(address(dex), type(uint256).max);
        IERC20(dex.getETHContract()  ).approve(address(dex), type(uint256).max);
        vm.stopPrank();

        // ── 3) finally, call swap and expect it to revert somewhere downstream ──
        vm.expectRevert();
        dex.swap(1 * 10**8, 0, "USDC", "ETH");
    }


}

