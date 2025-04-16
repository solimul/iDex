// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

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
import {MockERC20} from "../mocks/MockERC20.sol";

contract NetworkConfig {

    address private immutable i_owner;
    address private immutable i_dai;
    address private immutable i_eth;
    MockERC20 private immutable i_mockerc20_dai;
    MockERC20 private immutable i_mockerc20_eth;

    constructor () {
        i_owner = msg.sender;
        if (block.chainid == 31337) { // test-net 
            i_dai = address(new MockERC20("Mock DAI", "mDAI"));
            i_eth = address(new MockERC20("Mock ETH", "mETH"));

        } else if (block.chainid == 11155111) {  // sepolia
            i_dai = 0x11fE4B6AE13d2a6055C8D9cF65c55bac32B5d844; // DAI
            i_eth = 0xdd13E55209Fd76AfE204dBda4007C227904f0a81; // WETH
            /** 
             * Token	Faucet
                    DAI	https://sepoliafaucet.com/ or from Aave/Gelato testnet UI
                    WETH	Chainlink Sepolia Faucet
             * **/
        }
    }

    function getOwner () external view returns (address) {
        return i_owner;
    }

    function getDAIContract () external view returns (address) {
        return i_dai;
    }

    function getETHContract () external view returns (address) {
        return i_eth;
    }
    // Define the mainnet and testnet addresses for DAI and WETH
}