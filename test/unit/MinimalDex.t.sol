// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {Script} from "../../lib/forge-std/src/Script.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


import { BabylonianLib } from "../../src/libs/BabylonianLib.sol";
import { IDex } from "../../src/IDex.sol";
import { LiquidityProvision } from "../../src/LiquidityProvision.sol";
import { NetworkConfig } from "../../src/NetworkConfig.sol";
import { Pool } from "../../src/Pool.sol";
import { ProtocolReward } from "../../src/ProtocolReward.sol";
import {
    USDC_STR,
    WETH_STR,
    TRILLION_WEI,
    WETH_WEI,
    USDC_WEI,
    HUNDRED,
    MILLION,
    TEN_K,
    Context,
    LiquidityRecord,
    SwapRecord,
    ProtocolFeeDetails,
    ProtocolFee,
    Params
} from "../../src/Shared.sol";

import { MyERC20 } from "../../mocks/MyERC20.sol";

contract BabylonianLibTest is Test {
    function setUp() public {

    }

    // ---- fixed-value unit tests ----
    function testSqrt_Zero() public pure {
        uint256 result = BabylonianLib.sqrt(0);
        assert (result == 0);
    }
    function testSqrt_One() public pure {
        uint256 result = BabylonianLib.sqrt(1);
        assert (result == 1);
    }
    function testSqrt_Two() public pure {
        uint256 result = BabylonianLib.sqrt(2);
        assert (result == 1);
    }
    function testSqrt_Three() public pure {
        uint256 result = BabylonianLib.sqrt(3);
        assert (result == 1);
    }
    function testSqrt_Four_PerfectSquare() public pure {
        uint256 result = BabylonianLib.sqrt(4);
        assert (result == 2);
    }
    function testSqrt_Seven_NonSquare() public pure {
        uint256 result = BabylonianLib.sqrt(7);
        assert (result == 2);
    }
    function testSqrt_SixtyFour_PerfectSquare() public pure  {
        uint256 result = BabylonianLib.sqrt(64);
        assert (result == 8);
    }
    function testSqrt_OneHundredOne_NonSquareFlooring() public pure {
        uint256 result = BabylonianLib.sqrt(101);
        assert (result == 10);
    }

    function testSqrt_TenK_SquareFlooring() public pure {
        uint256 result = BabylonianLib.sqrt(10000);
        assert (result == 100);
    }


    function testSqrt_TenK4_SquareFlooring() public pure {
        uint256 result = BabylonianLib.sqrt(10004);
        assert (result == 100);
    }

    function testSqrt_9999_SquareFlooring() public pure {
        uint256 result = BabylonianLib.sqrt(9999);
        console.log (result);
        assert (result == 99);
    }
   

    //---- property-based / fuzz tests ----
    function testFuzz_Sqrt_Bounds(uint256 y) public pure {
        uint256 z = BabylonianLib.sqrt(y);
        assert (z*z <= y);
        if (z < type(uint128).max) {  // because (2^128)^2 fits in uint256
            assert((z + 1) * (z + 1) > y);
        }    
    }
    function testFuzz_Sqrt_Monotonic(uint256 a, uint256 b) public pure {
        (uint256 ra, uint256 rb) = (BabylonianLib.sqrt(a), BabylonianLib.sqrt(b));
        if (a >= b) 
            assert (ra >= rb);
        else
            assert (ra <= rb);
    } 
    function testFuzz_Sqrt_IdempotentOnSquares(uint256 x) public pure {
        if (x > type(uint128).max) return;
        assert (BabylonianLib.sqrt(x*x) == x);
    }  
}

contract ProtocolRewardTest is Test {
    ProtocolReward pReward;

    constructor () {

    }

}

contract IDexTest is Test {
    IDex private dex;
    LiquidityProvision private liquidityProvision;
    Pool private pool;
    NetworkConfig private networkConfig;
    MyERC20 private myERC20;
    ProtocolReward private protocolReward;
    uint256 constant MIN_LIQUIDITY_PPM      = 1000;     // e.g. 0.1% minimum liquidity in parts-per-million
    uint256 constant MAX_WITHDRAW_PCT       = 50;       // max withdraw percentage (50%)
    uint256 constant WITHDRAW_COOLDOWN      = 30 days;   // cooldown period for withdraw
    uint256 constant SWAP_FEE_PCT           = 3;       // 0.3% swap fee
    uint256 constant PROTOCOL_FEE_PCT       = 30;        // 30% of  SWAP_FEE_PCT
    uint256 constant MAX_PAUSE_DURATION     = 7 days;   // maximum pause duration for protocol
    
    string constant LPTOKEN_NAME = "USD/ETH LP ERC20 Token";
    string constant LPTOKEN_SYMBOL = "UELP";

    uint256 constant NPROVIDERS = 5;
    // ---------- setup ----------
    function setUp() public {
        networkConfig = new NetworkConfig();

        dex = new IDex
            (
                networkConfig.getUSDCContract(),
                networkConfig.getETHContract(),
                MIN_LIQUIDITY_PPM,
                MAX_WITHDRAW_PCT,
                WITHDRAW_COOLDOWN,
                SWAP_FEE_PCT,
                PROTOCOL_FEE_PCT,
                MAX_PAUSE_DURATION,
                true
            ); 
        liquidityProvision = new LiquidityProvision();
        pool = new Pool();
        protocolReward = new ProtocolReward();
        myERC20 = new MyERC20 (LPTOKEN_NAME, LPTOKEN_SYMBOL);

        dex.registerContracts ( address (pool), address (liquidityProvision), address(protocolReward), address (myERC20));
        pool.registerContracts(address (dex));
        liquidityProvision.registerContracts(address (dex));
        protocolReward.registerContracts(address (dex));
        myERC20.registerContracts (address (dex));
    }

    // ---------- deployment & config ----------
    function testDeploy_SetsDependencies() public view {

        (address p, address liqPro, address proRew, address ercToken) = dex.getContractAddressForTest();
        assert (p == address (pool));
        assert (liqPro == address (liquidityProvision));
        assert (proRew == address (protocolReward));
        assert (ercToken == address (myERC20));
    }

    function testConfig_DefaultParams() public view {
        (
            uint256 swapFees,
            uint256 protFees,
            uint256 minPpm,
            uint256 cooldown,
            address owner
        ) = dex.getConfigForTest();

        assert (swapFees == SWAP_FEE_PCT);
        assert (protFees == PROTOCOL_FEE_PCT);
        assert (minPpm == MIN_LIQUIDITY_PPM);
        assert (cooldown == WITHDRAW_COOLDOWN);
        assert (owner == address (this));
    }

    function testSetSwapFeePct_RevertAbove100() public {
        address usdc = networkConfig.getUSDCContract();
        address eth = networkConfig.getETHContract();
        vm.expectRevert();
        new IDex(
            usdc,
            eth,
            MIN_LIQUIDITY_PPM,
            MAX_WITHDRAW_PCT,
            WITHDRAW_COOLDOWN,
            109,                 // swapFeePct
            PROTOCOL_FEE_PCT,
            MAX_PAUSE_DURATION,
            true
        );
    }


    function testSetProtocolFeePct_RevertAbove100() public {
        address usdc = networkConfig.getUSDCContract();
        address eth = networkConfig.getETHContract();
        vm.expectRevert();
        new IDex(
            usdc,
            eth,
            MIN_LIQUIDITY_PPM,
            MAX_WITHDRAW_PCT,
            WITHDRAW_COOLDOWN,
            SWAP_FEE_PCT,                 // swapFeePct
            110,
            MAX_PAUSE_DURATION,
            true
        );
    }

    function testSetMinLiquidityPpm_RevertAbove1e6() public {
        address usdc = networkConfig.getUSDCContract();
        address eth = networkConfig.getETHContract();
        vm.expectRevert();
        new IDex(
            usdc,
            eth,
            1e6+100,
            MAX_WITHDRAW_PCT,
            WITHDRAW_COOLDOWN,
            SWAP_FEE_PCT,                 // swapFeePct
            PROTOCOL_FEE_PCT,
            MAX_PAUSE_DURATION,
            true
        );
    }

    function testSetWithdrawCooldown_RevertZero() public {
        address usdc = networkConfig.getUSDCContract();
        address eth = networkConfig.getETHContract();
        vm.expectRevert();
        new IDex(
            usdc,
            eth,
            MIN_LIQUIDITY_PPM,
            MAX_WITHDRAW_PCT,
            0,
            SWAP_FEE_PCT,                 // swapFeePct
            PROTOCOL_FEE_PCT,
            MAX_PAUSE_DURATION,
            true
        );
    }

    // ---------- liquidity: first deposit ----------
    function testDeposit_FirstDepositorBalnceUpdate () public {
        address usdc = networkConfig.getUSDCContract();
        address eth = networkConfig.getETHContract();
        uint256 usdc$ = 4000e6;
        uint256 eth$ = 1e18;
        deal(address(usdc), address(this), usdc$);
        deal(address(eth), address(this), eth$);
        IERC20(usdc).approve(address(dex), usdc$);
        IERC20(eth).approve(address(dex), eth$);

        uint256 uBalance0 = IERC20(usdc).balanceOf(address (pool));
        uint256 eBalance0 = IERC20(eth).balanceOf(address (pool));

        uint256 lpToken = liquidityProvision.calculateUelpForMinting(usdc$, eth$, 0,0, 0, false);
        
        uint256 lpBalance0 = myERC20.balanceOf (address (this));

        dex.seedDex(usdc$, eth$);

        uint256 uBalance1 = IERC20(usdc).balanceOf(address (pool));
        uint256 eBalance1 = IERC20(eth).balanceOf(address (pool));

        uint256 lpBalance1 = myERC20.balanceOf (address (this));


        assert (uBalance1 == uBalance0 + usdc$);
        assert (eBalance1 == eBalance0 + eth$);

        uint256 reserve = (lpToken * MIN_LIQUIDITY_PPM)/MILLION;

        assert (lpBalance1 == lpBalance0 + lpToken - reserve);
    }

    function testDeposit_SupplyLiquidityBalnceUpdateWithSeeding () public {
        testDeposit_FirstDepositorBalnceUpdate ();
        address usdc = networkConfig.getUSDCContract();
        address eth = networkConfig.getETHContract();
        uint256 usdc$ = 8010e6;
        uint256 eth$ = 2e18;
        deal(address(usdc), address(this), usdc$);
        deal(address(eth), address(this), eth$);
        IERC20(usdc).approve(address(dex), usdc$);
        IERC20(eth).approve(address(dex), eth$);

        uint256 uBalance0 = IERC20(usdc).balanceOf(address (pool));
        uint256 eBalance0 = IERC20(eth).balanceOf(address (pool));

        uint256 lpToken = liquidityProvision.calculateUelpForMinting(usdc$, eth$, pool.getBalance(usdc), pool.getBalance(eth), myERC20.totalSupply(), true);
        
        uint256 lpBalance0 = myERC20.balanceOf (address (this));

        dex.supplyLiquidity(usdc$, eth$);

        uint256 uBalance1 = IERC20(usdc).balanceOf(address (pool));
        uint256 eBalance1 = IERC20(eth).balanceOf(address (pool));

        uint256 lpBalance1 = myERC20.balanceOf (address (this));


        assert (uBalance1 == uBalance0 + usdc$);
        assert (eBalance1 == eBalance0 + eth$);


        assert (lpBalance1 == lpBalance0 + lpToken);    
    }

    function testDeposit_SupplyLiquidityWithoutSeeding () public {
        address usdc = networkConfig.getUSDCContract();
        address eth = networkConfig.getETHContract();
        uint256 usdc$ = 8010e6;
        uint256 eth$ = 2e18;
        deal(address(usdc), address(this), usdc$);
        deal(address(eth), address(this), eth$);
        IERC20(usdc).approve(address(dex), usdc$);
        IERC20(eth).approve(address(dex), eth$);
        
        vm.expectRevert(); 
        dex.supplyLiquidity(usdc$, eth$);
    }

    function testDeposit_FirstDepositorWrongAmount () public {
        address usdc = networkConfig.getUSDCContract();
        address eth = networkConfig.getETHContract();
        uint256 usdc$ = 0;
        uint256 eth$ = 0;
        deal(address(usdc), address(this), usdc$);
        deal(address(eth), address(this), eth$);
        IERC20(usdc).approve(address(dex), usdc$);
        IERC20(eth).approve(address(dex), eth$);
        vm.expectRevert(IDex.error_UelpAmountIsZero.selector);
        dex.seedDex(usdc$, eth$);
    }

       function testDeposit_SupplyLiquidityWrongAmount () public {
        testDeposit_FirstDepositorBalnceUpdate ();
        address usdc = networkConfig.getUSDCContract();
        address eth = networkConfig.getETHContract();
        uint256 usdc$ = 0;
        uint256 eth$ = 0;
        deal(address(usdc), address(this), usdc$);
        deal(address(eth), address(this), eth$);
        IERC20(usdc).approve(address(dex), usdc$);
        IERC20(eth).approve(address(dex), eth$);
        vm.expectRevert();
        dex.supplyLiquidity (usdc$, eth$);
    }

    function testDeposit_DoubleSeed () public {
        address usdc = networkConfig.getUSDCContract();
        address eth = networkConfig.getETHContract();
        uint256 usdc$ = 8010e6;
        uint256 eth$ = 2e18;
        deal(address(usdc), address(this), usdc$);
        deal(address(eth), address(this), eth$);
        IERC20(usdc).approve(address(dex), usdc$);
        IERC20(eth).approve(address(dex), eth$);
        dex.seedDex(usdc$, eth$);
        vm.expectRevert ();
        dex.seedDex(usdc$, eth$);
    }

    function testDeposit_MultipleSupplyLiquidityBalance () public {
        seedHelp ();
        (
            uint256[NPROVIDERS] memory eBalance0,
            uint256[NPROVIDERS] memory eBalance1,
            uint256[NPROVIDERS] memory uBalance0,
            uint256[NPROVIDERS] memory uBalance1,
            uint256[NPROVIDERS] memory lpBalance0,
            uint256[NPROVIDERS] memory lpBalance1,
            uint256[NPROVIDERS] memory lpSupply0,
            uint256[NPROVIDERS] memory lpSupply1,
            uint256[NPROVIDERS] memory calculatedLPAmount
        ) = supplyMultipleHelp();

        uint256 uBase = 5000e6;
        uint256 eBase = 1e18;
        for (uint256 i=0; i<NPROVIDERS;i++) {
            assert (uBalance1 [i] == uBalance0 [i] + (i+1)* uBase );
            assert (eBalance1 [i] == eBalance0 [i] + (i+1) * eBase);
            assert (lpBalance1 [i] == lpBalance0 [i] + calculatedLPAmount [i]);
            assert (lpSupply1 [i] == lpSupply0 [i] + calculatedLPAmount [i]);
        }
    }

    //*************** Swap */

    function testSwapETH4USDCBalanceUpdate () public {
        seedHelp ();
        supplyMultipleHelp ();
        address usdc = networkConfig.getUSDCContract();
        address eth = networkConfig.getETHContract();
        uint256 uPoolBalance0 = IERC20 (usdc).balanceOf (address (pool));
        uint256 ePoolBalance0 = IERC20 (eth).balanceOf (address (pool));

        address swapper = address (uint160 (1));

        uint256 swapETH = 1e18;
        uint256 quotedUSDC = dex.quoteOutAmount(swapETH, "WETH", "USDC");
        deal(address(eth), address(swapper), swapETH);
        uint256 swapFee = (swapETH * dex.getSwapFeesPct ()) / HUNDRED;
        uint256 protocolFee = (swapFee * dex.getProtocolFeePct ()) / HUNDRED;


        uint256 uSwapperBalance0 = IERC20 (usdc).balanceOf (swapper);
        uint256 eSwapperlBalance0 = IERC20 (eth).balanceOf (swapper);

        uint256 eProtocolRewardBalance0 = IERC20 (eth).balanceOf (address (protocolReward));

        vm.startPrank (swapper);
        IERC20(eth).approve(address(dex), swapETH);
        uint256 outUsdcAmount = dex.swap (swapETH, quotedUSDC, 1, "WETH", "USDC"); 
        vm.stopPrank ();  

        uint256 uPoolBalance1 = IERC20 (usdc).balanceOf (address (pool));
        uint256 ePoolBalance1 = IERC20 (eth).balanceOf (address (pool));
        uint256 uSwapperBalance1 = IERC20 (usdc).balanceOf (swapper);
        uint256 eSwapperlBalance1 = IERC20 (eth).balanceOf (swapper);
        uint256 eProtocolRewardBalance1 = IERC20 (eth).balanceOf (address (protocolReward));


        assert (uPoolBalance1 == uPoolBalance0 - outUsdcAmount);
        assert (ePoolBalance1 == ePoolBalance0 + swapETH - protocolFee);
        assert (uSwapperBalance1 == uSwapperBalance0 + outUsdcAmount);
        assert (eSwapperlBalance1 == eSwapperlBalance0 - swapETH);
        assert (eProtocolRewardBalance1 == eProtocolRewardBalance0 + protocolFee);
    }

    function testSwapUSDC4ETHBalanceUpdate () public {
        seedHelp ();
        supplyMultipleHelp ();
        address usdc = networkConfig.getUSDCContract();
        address eth = networkConfig.getETHContract();

        uint256 uPoolBalance0 = IERC20 (usdc).balanceOf (address (pool));
        uint256 ePoolBalance0 = IERC20 (eth).balanceOf (address (pool));

        address swapper = address (uint160 (1));

        uint256 swapUSDC = 4000e6;
        uint256 quotedETH = dex.quoteOutAmount(swapUSDC, "USDC", "WETH");
        deal(address(usdc), address(swapper), swapUSDC);
        uint256 swapFee = (swapUSDC * dex.getSwapFeesPct ()) / HUNDRED;
        uint256 protocolFee = (swapFee * dex.getProtocolFeePct ()) / HUNDRED;


        uint256 uSwapperBalance0 = IERC20 (usdc).balanceOf (swapper);
        uint256 eSwapperlBalance0 = IERC20 (eth).balanceOf (swapper);

        uint256 uProtocolRewardBalance0 = IERC20 (usdc).balanceOf (address (protocolReward));

        vm.startPrank (swapper);
        IERC20(usdc).approve(address(dex), swapUSDC);
        uint256 outETHAmount = dex.swap (swapUSDC, quotedETH, 1, "USDC", "WETH"); 
        vm.stopPrank ();  

        uint256 uPoolBalance1 = IERC20 (usdc).balanceOf (address (pool));
        uint256 ePoolBalance1 = IERC20 (eth).balanceOf (address (pool));
        uint256 uSwapperBalance1 = IERC20 (usdc).balanceOf (swapper);
        uint256 eSwapperlBalance1 = IERC20 (eth).balanceOf (swapper);
        uint256 uProtocolRewardBalance1 = IERC20 (usdc).balanceOf (address (protocolReward));

        assert (uPoolBalance1 == uPoolBalance0 + swapUSDC - protocolFee);
        assert (ePoolBalance1 == ePoolBalance0 - outETHAmount);
        assert (uSwapperBalance1 == uSwapperBalance0 - swapUSDC);
        assert (eSwapperlBalance1 == eSwapperlBalance0 + outETHAmount);
        assert (uProtocolRewardBalance1 == uProtocolRewardBalance0 + protocolFee);
    }

    // *** Helper Functions ***

    function seedHelp () internal {
        address usdc = networkConfig.getUSDCContract();
        address eth = networkConfig.getETHContract();
        uint256 usdc$ = 8010e6;
        uint256 eth$ = 2e18;
        deal(address(usdc), address(this), usdc$);
        deal(address(eth), address(this), eth$);
        IERC20(usdc).approve(address(dex), usdc$);
        IERC20(eth).approve(address(dex), eth$);
        dex.seedDex(usdc$, eth$);
    }

    function supplyHelp (address iAddress, uint256 usdc$, uint256 eth$) internal {
        address usdc = networkConfig.getUSDCContract();
        address eth = networkConfig.getETHContract();
        deal(address(usdc), address(iAddress), usdc$);
        deal(address(eth), address(iAddress), eth$);
        vm.startPrank(iAddress);
            IERC20(usdc).approve(address(dex), usdc$);
            IERC20(eth).approve(address(dex), eth$);
            dex.supplyLiquidity( usdc$ , eth$);
        vm.stopPrank();
    }

    function supplyMultipleHelp () 
    public 
    returns 
    (
        uint256[NPROVIDERS] memory eBalance0,
        uint256[NPROVIDERS] memory eBalance1,
        uint256[NPROVIDERS] memory uBalance0,
        uint256[NPROVIDERS] memory uBalance1,
        uint256[NPROVIDERS] memory lpBalance0,
        uint256[NPROVIDERS] memory lpBalance1,
        uint256[NPROVIDERS] memory lpSupply0,
        uint256[NPROVIDERS] memory lpSupply1,
        uint256[NPROVIDERS] memory calculatedLPAmount
    )
    {
        uint256 uBase = 5000e6;
        uint256 eBase = 1e18;
        address usdc = networkConfig.getUSDCContract();
        address eth = networkConfig.getETHContract();
        for (uint256 i=1; i<=NPROVIDERS; i++) {
            address iAddress = address (uint160 (i));
            uBalance0 [i-1] = IERC20 (usdc).balanceOf (address (pool));
            eBalance0 [i-1] = IERC20 (eth).balanceOf (address (pool)); 
            lpBalance0 [i-1] = myERC20.balanceOf (iAddress); 
            lpSupply0 [i-1] = myERC20.totalSupply();
            calculatedLPAmount [i-1] = liquidityProvision.calculateUelpForMinting
                                            (uBase *i, eBase * i, pool.getBalance(usdc), pool.getBalance(eth), myERC20.totalSupply(), true);
            
            supplyHelp (iAddress, uBase *i, eBase * i);

            uBalance1 [i-1] = IERC20 (usdc).balanceOf (address (pool));
            eBalance1 [i-1] = IERC20 (eth).balanceOf (address (pool)); 
            lpBalance1 [i-1] = myERC20.balanceOf (iAddress);
            lpSupply1 [i-1] = myERC20.totalSupply();
        }
    }

}

