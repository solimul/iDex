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

contract IDexTest is Test {
    IDex dex;
    uint256 constant MIN_LIQUIDITY_PPM      = 1000;     // e.g. 0.1% minimum liquidity in parts-per-million
    uint256 constant MAX_WITHDRAW_PCT       = 50;       // max withdraw percentage (50%)
    uint256 constant WITHDRAW_COOLDOWN      = 30 days;   // cooldown period for withdraw
    uint256 constant SWAP_FEE_PCT           = 3;       // 0.3% swap fee
    uint256 constant PROTOCOL_FEE_PCT       = 30;        // 30% of  SWAP_FEE_PCT
    uint256 constant MAX_PAUSE_DURATION     = 7 days;   // maximum pause duration for protocol
    // ---------- setup ----------
    function setUp() public {
        NetworkConfig networkConfig = new NetworkConfig();
        dex = new IDex
            (
                networkConfig.getUSDCContract(),
                networkConfig.getETHContract(),
                MIN_LIQUIDITY_PPM,
                MAX_WITHDRAW_PCT,
                WITHDRAW_COOLDOWN,
                SWAP_FEE_PCT,
                PROTOCOL_FEE_PCT,
                MAX_PAUSE_DURATION
            ); 
    }
}

