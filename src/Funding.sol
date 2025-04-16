// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

/**
 * @title Funding the pool
 * @author Md Solimul Chowdhury
 * @dev This contract is funds a given address with a given amount of DAI and ETH.
 */



contract Funding {

    constructor (address _dai, 
                address _eth, 
                address _to, 
                uint256 _ethAmount, 
                uint256 _daiAmount) {
        if (block.chainid == 31337) { // test-net 
            MockERC20 dai = MockERC20(_dai);
            MockERC20 eth = MockERC20(_eth);
            dai.mint(_to, _daiAmount);  
            eth.mint(_to, _ethAmount);
        } else if (block.chainid == 11155111) {  // sepolia
             IERC20(_dai).transfer(_to, _daiAmount);
             IERC20(_eth).transfer(_to, _ethAmount);
        }
        
    }
}