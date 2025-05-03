//SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console} from "forge-std/Script.sol";
import {MinimalDex} from "../src/MinimalDex.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {HelperConfig} from "../helper/HelperConfig.h.sol";

contract DeployMinimalDex is Script {

    uint256 private _usdc = 1 * 10 ** 6;
    uint256 private _eth = 1 * 10 ** 15;
    
    function deployMinimalDex() public {
        
        uint256 deployerKey = vm.envUint(getDeployerKeyName());
        address deployer   = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);
        //  1) Deploy
        MinimalDex dex = new MinimalDex (_usdc, _eth);
        // 2) Approve LPool to pull tokens
        configureApprovals(dex);
        // 3) Fund the pool (pulls from deployer)
        dex.fundContract(deployer);
        vm.stopBroadcast();
    }

    function configureApprovals(MinimalDex dex) internal {
        if (block.chainid == 11155111) {
            address usdcContract  = dex.getUSDCContract();
            address wethContract  = dex.getETHContract();
            address lpool = dex.getLPoolAddress();

            // these execute as txs from your EOA because broadcast is active
            IERC20(usdcContract).approve(lpool, type(uint256).max);    // 1 USDC (6 decimals)
            IERC20(wethContract).approve(lpool, type(uint256).max);   // 0.001 WETH (18 decimals)
        }
    }

    function getDeployerKeyName() internal view returns (string memory) {
        string memory privateKeyName;
        if (block.chainid == 11155111) {
          privateKeyName = "PRIVATE_KEY";
        } else if (block.chainid == 31337) {
          privateKeyName = "ANVIL_PRIVATE_KEY";
        }
        return privateKeyName;
    }
    
    function run() external {
        deployMinimalDex ();
    } 
}
