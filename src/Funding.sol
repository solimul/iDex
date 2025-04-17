// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

//import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// import {MockERC20} from "../mocks/MockERC20.sol";

/**
 * @title Funding the pool
 * @author Md Solimul Chowdhury
 * @dev This contract is funds a given address with a given amount of USDC and ETH.
 */



contract Funding {
    
    address private immutable i_usdc;
    address private immutable i_eth;
    address private immutable i_to;
    uint256 private immutable i_ethAmount;
    uint256 private immutable i_usdcAmount;
    constructor (address _usdc, 
                address _eth, 
                address _to, 
                uint256 _ethAmount, 
                uint256 _usdcAmount) {
        i_usdc = _usdc;  
        i_eth = _eth; 
        i_to = _to;
        i_ethAmount = _ethAmount;
        i_usdcAmount = _usdcAmount;
    }

    // function fundContract () public {
    //    if (block.chainid == 31337) { // test-net 
    //         MockERC20 usdc = MockERC20(i_usdc);
    //         MockERC20 eth = MockERC20(i_eth);
    //         usdc.mint(i_to, i_usdcAmount);  
    //         eth.mint(i_to, i_ethAmount);
    //     } else if (block.chainid == 11155111) {  // sepolia
    //         IERC20(i_usdc).transferFrom(msg.sender, address(this), i_usdcAmount);
    //          IERC20(i_usdc).transfer(i_to, i_usdcAmount);
    //          IERC20(i_eth).transfer(i_to, i_ethAmount);
    //     }
    // }
}