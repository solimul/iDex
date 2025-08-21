//SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

string constant USDC_STR = "USDC";
string constant WETH_STR = "WETH"; 
string constant LPTOKEN_NAME = "USD/ETH LP Token";
string constant LPTOKEN_SYMBOL = "UELP";
uint256 constant TRILLION_WEI = 1e12;
uint256 constant WETH_WEI = 10e18;
uint256 constant USDC_WEI = 10e6;


struct DepositRecord {
    address depositor;
    uint256 amount;
    uint256 timeStamp;
    uint256 uelp;
}

struct SwapRecord {
    address swapper;
    address tokenIn;
    uint256 amountIn;
    uint256 amountOut;
    uint256 timeStamp;
}


