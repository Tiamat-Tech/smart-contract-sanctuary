// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @dao: MEME
/// @author: Wizard

/*


                █████▒█    ██ ▓█████  ██▓    
              ▓██   ▒ ██  ▓██▒▓█   ▀ ▓██▒    
              ▒████ ░▓██  ▒██░▒███   ▒██░    
              ░▓█▒  ░▓▓█  ░██░▒▓█  ▄ ▒██░    
              ░▒█░   ▒▒█████▓ ░▒████▒░██████▒
              ▒ ░   ░▒▓▒ ▒ ▒ ░░ ▒░ ░░ ▒░▓  ░
              ░     ░░▒░ ░ ░  ░ ░  ░░ ░ ▒  ░
              ░ ░    ░░░ ░ ░    ░     ░ ░   
                        ░        ░  ░    ░  ░


*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FUEL is ERC20, ERC20Burnable, ERC20Capped, Ownable {
    address public minter;
    uint256 public fuelAmount = 35555000000000000000000000;

    constructor()
        ERC20("Rocket Fuel", "FUEL")
        ERC20Capped(355550000000 * (10**uint256(18)))
    {}

    modifier onlyMinter() {
        require(minter == _msgSender(), "must be  minter");
        _;
    }

    function setMinter(address _minter) public virtual onlyOwner {
        minter = _minter;
    }

    function setFuelAmount(uint256 amount) public virtual onlyOwner {
        fuelAmount = amount;
    }

    function mint(address account) public onlyMinter {
        _mint(account, fuelAmount);
    }

    function _mint(address account, uint256 amount)
        internal
        virtual
        override(ERC20, ERC20Capped)
    {
        require(ERC20.totalSupply() + amount <= cap(), "cap exceeded");
        super._mint(account, amount);
    }
}