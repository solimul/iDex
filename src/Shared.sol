//SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

string constant USDC_STR = "USDC";
string constant WETH_STR = "WETH"; 
string constant LPTOKEN_NAME = "USD/ETH LP Token";
string constant LPTOKEN_SYMBOL = "UELP";
uint256 constant TRILLION_WEI = 1e12;
uint256 constant WETH_WEI = 10e18;
uint256 constant USDC_WEI = 10e6;
uint256 constant HUNDRED = 100;
uint256 constant MILLION = 1_000_000;

enum Context {
    PFeeDeposit,
    SwapFeeDeposit
}



struct LiquidityRecord {
    address token;
    uint256 amount;
    uint256 uelp;
    uint256 timeStamp;
}

struct SwapRecord {
    uint256 id;
    address swapper;
    address tokenIn;
    uint256 amountIn;
    uint256 amountOut;
    uint256 swapFee;
    uint256 timeStamp;
}

struct ProtocolFeeDetails {
    uint256 totalAmount;
    ProtocolFee [] fees;
}

struct ProtocolFee {
    uint256 swapId;
    uint256 amount;
    Context context;
}

struct Params {
    uint256 minLiquidityPpm;
    uint256 maxWithdrawPct;
    uint256 withdrawCooldown;
    uint256 swapFeePct;
    uint256 protocolFeePct;
}


