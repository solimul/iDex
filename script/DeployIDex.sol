// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "../lib/forge-std/src/Script.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


import { BabylonianLib } from "../src/libs/BabylonianLib.sol";
import { IDex } from "../src/IDex.sol";
import { LiquidityProvision } from "../src/LiquidityProvision.sol";
import { NetworkConfig } from "../src/NetworkConfig.sol";
import { Pool } from "../src/Pool.sol";
import { ProtocolReward } from "../src/ProtocolReward.sol";
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
} from "../src/Shared.sol";

import { MyERC20 } from "../mocks/MyERC20.sol";

contract DeployIDex is Script {


    error error_UnsupportedNetwork();


    uint256 constant MIN_LIQUIDITY_PPM      = 1000;     // e.g. 0.1% minimum liquidity in parts-per-million
    uint256 constant MAX_WITHDRAW_PCT       = 50;       // max withdraw percentage (50%)
    uint256 constant WITHDRAW_COOLDOWN      = 30 days;   // cooldown period for withdraw
    uint256 constant SWAP_FEE_PCT           = 3;       // 0.3% swap fee
    uint256 constant PROTOCOL_FEE_PCT       = 30;        // 30% of  SWAP_FEE_PCT
    uint256 constant MAX_PAUSE_DURATION     = 7 days;   // maximum pause duration for protocol

    string constant LPTOKEN_NAME = "USD/ETH LP ERC20 Token";
    string constant LPTOKEN_SYMBOL = "UELP";

    string constant MAINNET_PRIVATE_KEY = "MAINNET_PRIVATE_KEY";
    string constant SEPOLIA_PRIVATE_KEY = "SEPOLIA_PRIVATE_KEY";
    string constant ANVIL_PRIVATE_KEY = "ANVIL_PRIVATE_KEY";

    uint256 constant MAINNET_CHAIN_ID = 1;
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ANVIL_CHAIN_ID = 31337;


    IDex private iDex;
    LiquidityProvision private liquidityProvision;
    NetworkConfig private networkConfig;
    Pool private pool;
    ProtocolReward private protocolReward;
    MyERC20 private myERC20;

    function get_private_key() internal view returns (uint256 deployerPrivateKey) {
        uint256 chainID = block.chainid;
        if (chainID == MAINNET_CHAIN_ID) {
            // Ethereum Mainnet
            deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");
        } else if (chainID == SEPOLIA_CHAIN_ID) {
            deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");
        } else if (chainID == ANVIL_CHAIN_ID) {
            deployerPrivateKey = vm.envUint("ANVIL_PRIVATE_KEY");
        } else {
            revert error_UnsupportedNetwork();
        }
    }

    function run () external {
        uint256 deployerPrivateKey = get_private_key();
        vm.startBroadcast(deployerPrivateKey);
            networkConfig = new NetworkConfig();
            iDex = new IDex
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
            liquidityProvision = new LiquidityProvision();
            pool = new Pool();
            protocolReward = new ProtocolReward();
            myERC20 = new MyERC20 (LPTOKEN_NAME, LPTOKEN_SYMBOL);
        vm.stopBroadcast();
        registerContracts ();
    }

    function registerContracts () internal {
        address iDexA = address (iDex);
        address poolA = address (pool);
        address lProvisionA = address (liquidityProvision);
        address prA = address (protocolReward);
        address lpTokenA = address (myERC20);

        iDex.registerContracts(poolA, lProvisionA, prA, lpTokenA);
        pool.registerContracts(iDexA);
        liquidityProvision.registerContracts(iDexA);
        protocolReward.registerContracts(iDexA);
    }
}
