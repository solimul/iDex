// SPDX‑License‑Identifier: MIT
pragma solidity ^0.8.26;

import {MinimalDex} from "../src/MinimalDex.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IWETH {
  function deposit() external payable;
}

/// @notice Deploys & configures a freshly‑deployed MinimalDex:
///   • wraps and deposits ETH → WETH9  
///   • approves both USDC & WETH9 for the pool  
///   • calls fundContract(...) on your DEX  
contract HelperConfig {
    constructor(
      address deployerAddress,
      address dexAddress,
      uint256  wethAmount,    // in WETH units   (18 decimals)
      uint256  usdcAmount   // in USDC units (6 decimals)
    ) payable {
        MinimalDex dex = MinimalDex(dexAddress);

        address usdc  = dex.getUSDCContract();
        address weth  = dex.getETHContract();
        address lpool = dex.getLPoolAddress();
        address deployer = deployerAddress;

        // 1) Wrap native ETH into WETH9
        //require(msg.value == wethAmount, "Must send exactly wethAmount");
        //IWETH(weth).deposit{ value: wethAmount }();

        // 2) Approve pool to pull USDC & WETH
        IERC20(usdc).approve(lpool, usdcAmount);
        IERC20(weth).approve(lpool, wethAmount);

        // 3) Fund the pool
        dex.fundContract(deployer);
    }


}
