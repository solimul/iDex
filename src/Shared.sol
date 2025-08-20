//SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

string constant USDC_STR = "USDC";
string constant WETH_STR = "WETH"; 

struct DepositRecord {
    address depositor;
    uint256 amount;
    uint256 timeStamp;
}

struct SwapRecord {
    address swapper;
    address tokenIn;
    uint256 amountIn;
    uint256 amountOut;
    uint256 timeStamp;
}


