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
    uint256 private constant _exceedReserveUSDCAmount = 1 * 10 ** 8; // 1 USDC (6 decimals)
    uint256 private constant _exceedReserveETHAmount = 1 * 10 ** 16; // 0.01 WETH (18 decimals)
    LPool private lpool;
    AMM private amm;
    MinimalDex dex ;
    MockERC20 private mock_test_contract;

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

    /**
     * @notice Test the swap function with a valid amount and check the reserves
     * @dev This test will check if the reserves are updated correctly after a swap
     *     the dex will swap USDC for ETH: pulls USDC from the user, sends it to LPool, 
     *          and then pulls equivalent ETH from LPool, and sends it to the user 
     *              * for anvil network, we will mint the tokens directly to this test contract (which mocks an user account)
     *              and approve the DEX for the user-pull, because the DEX will pull the tokens from the user (that is this test contract)
     *              * for sepolia network, we will approve the DEX for the pool-pull, because the DEX will pull the tokens from the pool
     */
     
    function testSwapUSDC2ETHExpectRevertOnReserveUSDCExceed () public {

        if (block.chainid == 31337) { // for anvil network
            // seed this contract with _reserveUSDC & approve the DEX for the user-pull
            mock_test_contract = MockERC20(dex.getUSDCContract());
            mock_test_contract.mint(address(this), _reserveUSDC );
            mock_test_contract.approve(address(dex), type(uint256).max);
        }
      
        // // now tell LPool to approve the DEX for the ETH Pull 
        vm.startPrank(address(lpool));
        IERC20(dex.getETHContract()).approve(address(dex), type(uint256).max);
        vm.stopPrank();

        // finally, call swap and expect it to revert somewhere downstream ──
        vm.expectRevert();
        dex.swap(_exceedReserveUSDCAmount,0, "USDC", "ETH");
    }


    /**
     * @notice Test the swap function with an ETH amount that exceeds the reserve USDC in the pool
     * @dev This test checks if the DEX correctly reverts when trying to swap more ETH than the pool can support in USDC
     *      The DEX will swap ETH for USDC: pulls ETH from the user, sends it to LPool,
     *          and then pulls equivalent USDC from LPool and sends it to the user
     *          * for anvil network, we mint ETH tokens directly to this test contract (mocking a user)
     *            and approve the DEX for the user-pull, because the DEX will pull ETH from the user (this contract)
     *          * for sepolia network, we approve the DEX for the pool-pull, as the DEX will pull USDC from the pool
     */
    function testSwapETH2USDCExpectRevertOnReserveETHExceed () public {
        if (block.chainid == 31337) { // for anvil network
            // seed this contract with _rserveETH & approve the DEX for the user-pull
            mock_test_contract = MockERC20(dex.getETHContract());
            mock_test_contract.mint(address(this), _rserveETH );
            mock_test_contract.approve(address(dex), type(uint256).max);
        }

        // now tell LPool to approve the DEX for the USDC pull 
        vm.startPrank(address(lpool));
        IERC20(dex.getUSDCContract()).approve(address(dex), type(uint256).max);
        vm.stopPrank();

        // finally, call swap and expect it to revert somewhere downstream ──
        vm.expectRevert();
        dex.swap(_exceedReserveETHAmount, 0, "ETH", "USDC");
    }

    function testUserHasInsufficeintUSDCExpectRevert () public {
        if (block.chainid == 31337) { // for anvil network
            // seed this contract with _reserveUSDC & approve the DEX for the user-pull
            mock_test_contract = MockERC20(dex.getUSDCContract());
            mock_test_contract.mint(address(this), _reserveUSDC - 200000);
            mock_test_contract.approve(address(dex), type(uint256).max);
        }

        // now tell LPool to approve the DEX for the ETH Pull 
        vm.startPrank(address(lpool));
        IERC20(dex.getETHContract()).approve(address(dex), type(uint256).max);
        vm.stopPrank();

        // finally, call swap and expect it to revert somewhere downstream ──
        vm.expectRevert();
        dex.swap(_reserveUSDC - 100000, 0, "USDC", "ETH");
    }

    function testUserHasInsufficeintETHExpectRevert () public {
        if (block.chainid == 31337) { // for anvil network
            // seed this contract with _reserveETH & approve the DEX for the user-pull
            mock_test_contract = MockERC20(dex.getETHContract());
            mock_test_contract.mint(address(this), _rserveETH - 200000);
            mock_test_contract.approve(address(dex), type(uint256).max);
        }

        // now tell LPool to approve the DEX for the USDC Pull 
        vm.startPrank(address(lpool));
        IERC20(dex.getUSDCContract()).approve(address(dex), type(uint256).max);
        vm.stopPrank();

        // finally, call swap and expect it to revert somewhere downstream ──
        vm.expectRevert();
        dex.swap(_rserveETH - 100000, 0, "USDC", "ETH");
    }


}

