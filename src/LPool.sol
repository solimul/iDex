// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;
import {Funding} from "./Funding.sol";
import {NetworkConfig} from "./NetworkConfig.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


/**
 * @title LPool
 * @author Md Solimul Chowdhury
 * @notice This contract is a liquidity pool for ETH and USDC.
 * @dev It allows users to deposit and withdraw ETH and USDC, and provides functions to get the reserves of each token.
 */
contract LPool {

    error NOT_OWNER();
    error ETH_NEGATIVE();
    error USDC_NEGATIVE();

    event ReserveInitialized (uint256 reserveETH, uint256 reserveUSDC);
    event ReserveETHUpdated (uint256 reserveETH);
    event ReserveUSDCUpdated (uint256 reserveUSDC);
    event ReservesReset (uint256 reserveETH, uint256 reserveUSDC);


    uint256 private s_reserveETH;
    uint256 private s_reserveUSDC;
    NetworkConfig public immutable networkConfig;

    address private immutable i_owner;
    address private immutable i_usdc;
    address private immutable i_eth;

    constructor (uint256 _reserveETH, uint256 _reserveUSDC) {  
        i_owner = msg.sender;
        s_reserveETH = _reserveETH;
        s_reserveUSDC = _reserveUSDC;
        networkConfig = new NetworkConfig ();
        i_eth = networkConfig.getETHContract ();
        i_usdc = networkConfig.getUSDCContract ();
        emit ReserveInitialized (_reserveETH, _reserveUSDC);
    }

    modifier onlyOwner () {
        if (msg.sender != i_owner) revert NOT_OWNER();
        _;
    }

    function getReserveETH () external view returns (uint256) {
        return s_reserveETH;
    }

    function getReserveUSDC () external view returns (uint256) {
        return s_reserveUSDC;
    }

    function getOwner () external view returns (address) {
        return i_owner;
    }

    function getUSDCContract () external view returns (address) {
        return i_usdc;
    }

    function getETHContract () external view returns (address) {
        return i_eth;
    }

      function getLPoolAddress () external view returns (address) {
        return address(this);
    }

    function getInvariant () external view returns (uint256) {
        return s_reserveETH * s_reserveUSDC;
    }


    function updateReserveETH (uint256 _reserveETH) external {
        s_reserveETH = _reserveETH;
        emit ReserveETHUpdated(_reserveETH);
    }

    function updateReserveUSDC (uint256 _reserveUSDC) external  {
        s_reserveUSDC = _reserveUSDC;
        emit ReserveUSDCUpdated(_reserveUSDC);
    }

    function resetReserves (uint256 _reserveETH, uint256 _reserveUSDC) external onlyOwner {
        s_reserveETH = _reserveETH;
        s_reserveUSDC = _reserveUSDC;
        emit ReservesReset(_reserveETH, _reserveUSDC);
    }

    function updateLPool (
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    ) external {
            if (tokenOut == i_usdc) {
            s_reserveETH = s_reserveETH + amountIn;
            s_reserveUSDC = s_reserveUSDC - amountOut;
        } else {
            s_reserveUSDC = s_reserveUSDC + amountOut;
            s_reserveETH = s_reserveETH - amountIn;
        }
    }



    function fundContract(address sender) public {
        if (block.chainid == 31337) {
            // Local testing — mint directly to LPool
            MockERC20 usdc = MockERC20(i_usdc);
            MockERC20 eth = MockERC20(i_eth);
            usdc.mint(address(this), s_reserveUSDC);
            eth.mint(address(this), s_reserveETH);
        } else if (block.chainid == 11155111) {
            // Sepolia — pull funds from external sender
            bool usdcSuccess = IERC20(i_usdc).transferFrom(sender, address(this), s_reserveUSDC);
            bool ethSuccess = IERC20(i_eth).transferFrom(sender, address(this), s_reserveETH);

            require(usdcSuccess, "USDC funding failed");
            require(ethSuccess, "ETH funding failed");
        }
    }

  

}