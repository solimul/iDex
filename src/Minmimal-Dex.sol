// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AMM} from "./AMM.sol";

contract MinimalDex {
    AMM private amm;
    address private immutable i_owner;
    

    constructor () {
        amm = new AMM ();
        i_owner = msg.sender;
    }

    modifier onlyOwner () {
        require (msg.sender == i_owner, "Not the owner");
        _;
    }

    function getAMMContract () external view onlyOwner returns (address)  {
        return address(amm);
    }

    function getOwner () external view returns (address) {
        return i_owner;
    }

    function swap  ( 
        uint256 amountIn,
        uint256 slippagePrecentage,
        string memory tokenInString,
        string memory tokenOutString
       ) public {
        amm.swapTokens(amountIn, slippagePrecentage, tokenInString, tokenOutString);
    }
}