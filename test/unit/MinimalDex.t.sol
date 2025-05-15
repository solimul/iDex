// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {MinimalDex} from "../../src/MinimalDex.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {LPool} from "../../src/LPool.sol";
import {AMM} from "../../src/AMM.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {TestSetup} from "../../utils/TestSetup.sol";

contract MinimalDexTest is Test {
    uint256 private _reserveUSDC = 1 * 10 ** 6; // 1 USDC
    uint256 private _reserveETH = 1 * 10 ** 15; // 0.001 ETH
    uint256 private constant _exceedReserveUSDCAmount = 1 * 10 ** 8;
    uint256 private constant _exceedReserveETHAmount = 1 * 10 ** 16;

    error ETH_RESERVE_NOT_UPDATED ();
    error USDC_RESERVE_NOT_UPDATED ();

    LPool private lpool;
    MinimalDex private dex;
    TestSetup private testSetup;

    function getDeployerKeyName() internal view returns (string memory) {
        return block.chainid == 11155111 ? "PRIVATE_KEY" : "ANVIL_PRIVATE_KEY";
    }

    function setUp() public {
        testSetup = new TestSetup();
        uint256 deployerKey = vm.envUint(getDeployerKeyName());
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast();
        dex = new MinimalDex(_reserveUSDC, _reserveETH);
        lpool = LPool(dex.getLPoolAddress());
        testSetup.configureFundingAndApprovals(dex, lpool, _reserveUSDC, _reserveETH);
        dex.fundContract(deployer);
        vm.stopBroadcast();
    }

    function testReserveETH() public view {
        assertEq(lpool.getETHPoolAmount(), _reserveETH, "Reserve ETH should be 0.001");
    }

    function testReserveUSDC() public view {
        assertEq(lpool.getUSDCPoolAmount(), _reserveUSDC, "Reserve USDC should be 1");
    }

    function testSwapUSDC2ETHExpectRevertOnReserveUSDCExceed() public {
        // ANVIL:
        // Mint USDC to this test contract to simulate user balance (required since mock balances start at zero).
        // Then approve the DEX to pull USDC from this user (i.e., this contract).

        // NOTE: for SEPOLIA / MAINNET
        // Minting is not needed — tokens like USDC are real assets on-chain.
        // The user must already hold sufficient USDC; otherwise, the swap will revert.
        testSetup.mintApproveToken(dex.getUSDCContract(), address(this), address(dex), _reserveUSDC);

        // Approve the DEX to pull ETH from the pool (LPool), since it will send ETH to the user during the swap.
        testSetup.approveDexToPullFrom(dex.getETHContract(), address(lpool), address(dex));

        // Try swapping more USDC than the pool can return in ETH — should revert due to insufficient ETH liquidity.
        vm.expectRevert();
        dex.swap(_exceedReserveUSDCAmount, 0, "USDC", "ETH");
    }

    function testSwapETH2USDCExpectRevertOnReserveETHExceed() public {
        // ANVIL:
        // Mint ETH to this test contract to simulate user balance.
        // Approve the DEX to pull ETH from this test contract.

        // NOTE: for SEPOLIA / MAINNET
        // No minting — user must already own ETH.
        // Swap will revert if user balance is insufficient.

        testSetup.mintApproveToken(dex.getETHContract(), address(this), address(dex), _reserveETH);

        // Approve the DEX to pull USDC from the pool (LPool), since it will send USDC to the user during the swap.
        testSetup.approveDexToPullFrom(dex.getUSDCContract(), address(lpool), address(dex));

        // Try swapping more ETH than the pool can return in USDC — should revert due to insufficient USDC liquidity.
        vm.expectRevert();
        dex.swap(_exceedReserveETHAmount, 0, "ETH", "USDC");
    }

    function testUserHasInsufficientUSDCExpectRevert() public {
        // ANVIL:
        // Mint slightly less USDC than required to simulate an underfunded user.
        // Approve the DEX to pull USDC from this test contract.

        // NOTE: for SEPOLIA / MAINNET
        // No minting — user must already hold USDC.
        // If user's balance is insufficient, the swap will revert.

        testSetup.mintApproveToken(dex.getUSDCContract(), address(this), address(dex), _reserveUSDC - 200000);

        // Approve the DEX to pull ETH from the pool (LPool), since it will send ETH to the user during the swap.
        testSetup.approveDexToPullFrom(dex.getETHContract(), address(lpool), address(dex));

        // Try to swap slightly more USDC than user owns — should revert due to insufficient user balance.
        vm.expectRevert();
        dex.swap(_reserveUSDC - 100000, 0, "USDC", "ETH");
    }


    function testUserHasInsufficientETHExpectRevert() public {
        // ANVIL:
        // Mint slightly less ETH than needed to this test contract to simulate insufficient user balance.
        // This is necessary because on Anvil (a local test network), token balances start at zero,
        // and mock tokens like WETH must be manually minted for testing purposes.
        // and then Approve the DEX to pull ETH from this minted tokens for the swap.

        // NOTE: for SEPOLIA / MAINNET
        // Minting is not needed — tokens (e.g., WETH) are real assets deployed on-chain.
        // The user (i.e., the EOA running the test) must already hold ETH in their wallet.
        // If the wallet lacks sufficient ETH, the swap will revert due to insufficient balance.    
        testSetup.mintApproveToken(dex.getETHContract(), address(this), address(dex), _reserveETH - 300000);

        // Approve the DEX to pull USDC from the lpool for the swap.
        testSetup.approveDexToPullFrom(dex.getUSDCContract(), address(lpool), address(dex));

        // Now attempt a swap with more ETH than the user actually owns — this should revert.
        vm.expectRevert();
        dex.swap(_reserveETH - 200000, 0, "ETH", "USDC");
    }

    function testGetTokenAddress () public view {
        // Check that the token address for USDC is correct
        assertEq((AMM(dex.getAMM ())).getTokenAddress("USDC"), dex.getUSDCContract(), "USDC address should match");
        // Check that the token address for ETH is correct
        assertEq((AMM(dex.getAMM ())).getTokenAddress("ETH"), dex.getETHContract(), "ETH address should match");
    }

    function testCalculateUSDCOutAmountForETH () public view {
        uint256 amountIn = 100000; // 1 USDC
        uint256 amountOut = 0;
        address tokenIn = dex.getUSDCContract();
        address tokenOut = dex.getETHContract();
        uint256 currentUSDCReserve = lpool.getUSDCPoolAmount();
        uint256 currentETHReserve = lpool.getETHPoolAmount();
        // Calculate the expected amount out using the formula
        uint256 expectedAmountOut = (amountIn * currentETHReserve) / (currentUSDCReserve + amountIn);
        // Call the function to calculate the amount out
        amountOut = (AMM (dex.getAMM ())).calculateOutAmount(amountIn, tokenIn, tokenOut);

        assertEq(amountOut, expectedAmountOut, "Calculated amount out should match expected amount out");
    }

    function testUpdateLPoolOnSwapETH2USDC () public {

             
        // ANVIL:
        // Mint ETH test contract to simulate user balance
        // This is necessary because on Anvil (a local test network), token balances start at zero,
        // and mock tokens like WETH must be manually minted for testing purposes.
        // and then Approve the DEX to pull ETH from this minted tokens for the swap.

        // NOTE: for SEPOLIA / MAINNET
        // Minting is not needed — tokens (e.g., WETH) are real assets deployed on-chain.
        // The user (i.e., the EOA running the test) must already hold ETH in their wallet.
        // If the wallet lacks sufficient ETH, the swap will revert due to insufficient balance.    
        testSetup.mintApproveToken(dex.getETHContract(), address(this), address(dex), _reserveETH );

        // Approve the DEX to pull USDC from the lpool for the swap.
        testSetup.approveDexToPullFrom(dex.getUSDCContract(), address(lpool), address(dex));

        uint256 ethAmountIn = 10000; 
        uint256 currentUSDCReserve = lpool.getUSDCPoolAmount();
        uint256 currentETHReserve = lpool.getETHPoolAmount(); 

        uint256 expectedAmountOut = (ethAmountIn * currentUSDCReserve) / (currentETHReserve + ethAmountIn);

        uint256 updatedETHReserve = currentETHReserve + ethAmountIn;
        uint256 updatedUSDCReserve = currentUSDCReserve - expectedAmountOut;   

        // console.log ("my balance: ", IERC20(dex.getETHContract()).balanceOf(address(this)));
        // console.log ("lpool balance: ", IERC20(dex.getETHContract()).balanceOf(address(lpool)));
        // console.log ("lpool USDC balance: ", IERC20(dex.getUSDCContract()).balanceOf(address(lpool)));
        // console.log ("lpool ETH balance: ", IERC20(dex.getETHContract()).balanceOf(address(lpool)));
        // swap ETH for USDC
        dex.swap(ethAmountIn, 0, "ETH", "USDC");

        // Check that the reserves have been updated correctly
        assert(lpool.getETHPoolAmount() == updatedETHReserve);
        assert(lpool.getUSDCPoolAmount() == updatedUSDCReserve);

    }

    function testUpdateLPoolOnSwapUSDC2ETH () public {

             
        // ANVIL:
        // Mint USDC test contract to simulate user balance
        // This is necessary because on Anvil (a local test network), token balances start at zero,
        // and mock tokens like WETH must be manually minted for testing purposes.
        // and then Approve the DEX to pull ETH from this minted tokens for the swap.

        // NOTE: for SEPOLIA / MAINNET
        // Minting is not needed — tokens (e.g., USDC) are real assets deployed on-chain.
        // The user (i.e., the EOA running the test) must already hold ETH in their wallet.
        // If the wallet lacks sufficient ETH, the swap will revert due to insufficient balance.    
        testSetup.mintApproveToken(dex.getUSDCContract(), address(this), address(dex), _reserveUSDC );

        // Approve the DEX to pull USDC from the lpool for the swap.
        testSetup.approveDexToPullFrom(dex.getETHContract(), address(lpool), address(dex));

        uint256 usdcAmountIn = 10000; 
        uint256 currentUSDCReserve = lpool.getUSDCPoolAmount();
        uint256 currentETHReserve = lpool.getETHPoolAmount(); 

        uint256 expectedAmountOut = (usdcAmountIn * currentETHReserve) / (currentUSDCReserve + usdcAmountIn);

        uint256 updatedUSDCReserve = currentUSDCReserve + usdcAmountIn;
        uint256 updatedETHReserve = currentETHReserve - expectedAmountOut;   

        dex.swap(usdcAmountIn, 0, "USDC", "ETH");

        // Check that the reserves have been updated correctly
        assertEq(lpool.getETHPoolAmount(), updatedETHReserve, "ETH reserve should be updated correctly");
        assertEq(lpool.getUSDCPoolAmount(), updatedUSDCReserve, "USDC reserve should be updated correctly");        

    }

    function testUSDC2SOLSWapExpectRevert () public {
        // ANVIL:
        // Mint USDC to this test contract to simulate user balance (required since mock balances start at zero).
        // Then approve the DEX to pull USDC from this user (i.e., this contract).

        // NOTE: for SEPOLIA / MAINNET
        // Minting is not needed — tokens like USDC are real assets on-chain.
        // The user must already hold sufficient USDC; otherwise, the swap will revert.
        testSetup.mintApproveToken(dex.getUSDCContract(), address(this), address(dex), _reserveUSDC);

        // Approve the DEX to pull ETH from the pool (LPool), since it will send ETH to the user during the swap.
        testSetup.approveDexToPullFrom(dex.getETHContract(), address(lpool), address(dex));

        // Try USDC to get SOL, which is not allowed. we should expect a revert. 
        vm.expectRevert();
        dex.swap(_reserveUSDC-1000, 0, "USDC", "SOL");
    }

    function testETH2ETHSWapExpectRevert () public {

        testSetup.mintApproveToken(dex.getETHContract(), address(this), address(dex), _reserveETH);

        testSetup.approveDexToPullFrom(dex.getUSDCContract(), address(lpool), address(dex));

        vm.expectRevert();
        dex.swap(_reserveETH-1000, 0, "ETH", "ETH");
    }

    function testUSDC2ETHSwapForCorrectBalanceUpdate () public {

        testSetup.mintApproveToken(dex.getUSDCContract(), address(this), address(dex), _reserveUSDC);

        testSetup.approveDexToPullFrom(dex.getETHContract(), address(lpool), address(dex));

        uint256 currentUSDC = IERC20(dex.getUSDCContract()).balanceOf(address(lpool));
        uint256 currentETH = IERC20(dex.getETHContract()).balanceOf(address(lpool));
        uint256 usdcAmountIn = currentUSDC / 10; // 10% of the current USDC balance 

        uint256 expectedAmountOut = (usdcAmountIn * lpool.getETHPoolAmount()) / (lpool.getUSDCPoolAmount() + usdcAmountIn);        
  

        dex.swap(usdcAmountIn, 0, "USDC", "ETH");

        assertEq(IERC20(dex.getUSDCContract()).balanceOf(address(lpool)), currentUSDC + usdcAmountIn, "User USDC balance should be updated correctly");
        assertEq(IERC20(dex.getETHContract()).balanceOf(address(lpool)), currentETH - expectedAmountOut, "User ETH balance should be updated correctly");

    }

    function testETH2USDCSwapForCorrectBalanceUpdate () public {

        testSetup.mintApproveToken(dex.getETHContract(), address(this), address(dex), _reserveETH);

        testSetup.approveDexToPullFrom(dex.getUSDCContract(), address(lpool), address(dex));

        uint256 currentUSDC = IERC20(dex.getUSDCContract()).balanceOf(address(lpool));
        uint256 currentETH = IERC20(dex.getETHContract()).balanceOf(address(lpool));
        uint256 ethAmountIn = currentETH / 10; // 10% of the current USDC balance 

        uint256 expectedAmountOut = (ethAmountIn * lpool.getUSDCPoolAmount()) / (lpool.getETHPoolAmount() + ethAmountIn);        
  

        dex.swap(ethAmountIn, 0, "ETH", "USDC");

        assertEq(IERC20(dex.getUSDCContract()).balanceOf(address(lpool)), currentUSDC - expectedAmountOut, "User USDC balance should be updated correctly");
        assertEq(IERC20(dex.getETHContract()).balanceOf(address(lpool)), currentETH + ethAmountIn, "User ETH balance should be updated correctly");

    }
}
