//SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {MinimalDex} from "../src/MinimalDex.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract DeployMinimalDex is Script {

  function deployMinimalDex() public {
    uint256 deployerKey = vm.envUint("PRIVATE_KEY");
    address deployer   = vm.addr(deployerKey);

    vm.startBroadcast(deployerKey);
        console.log("Deploying MinimalDex with account:", deployer);

        // 1) Deploy
        MinimalDex dex = new MinimalDex();
        console.log("MinimalDex deployed to:", address(dex));

        // 2) Approve LPool to pull tokens
        address usdc  = dex.getUSDCContract();
        address weth  = dex.getETHContract();
        address lpool = dex.getLPoolAddress();

        // these execute as txs from your EOA because broadcast is active
        IERC20(usdc).approve(lpool, 1 * 10 ** 6);    // 1 USDC (6 decimals)
        IERC20(weth).approve(lpool, 1 * 10 ** 15);   // 0.001 WETH (18 decimals)

        // 3) Fund the pool (pulls from deployer)
        dex.fundContract(deployer);
        vm.stopBroadcast();
    }

    function configureApprovals(MinimalDex dex) internal {
        address usdc  = dex.getUSDCContract();
        address weth  = dex.getETHContract();
        address lpool = dex.getLPoolAddress();

        // these execute as txs from your EOA because broadcast is active
        IERC20(usdc).approve(lpool, 1 * 10 ** 6);    // 1 USDC (6 decimals)
        IERC20(weth).approve(lpool, 1 * 10 ** 15);   // 0.001 WETH (18 decimals)
    }
    
    function run() external {
        deployMinimalDex ();
    } 
}
