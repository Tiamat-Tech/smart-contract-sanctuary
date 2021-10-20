// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./ERC20Upgradeable.sol";
import "./libs/Initializable.sol";


contract SDAOUpgradableToken2 is Initializable, ERC20Upgradeable {
    
    bool v2upgrade;

    function initialize(string memory name, string memory symbol, uint256 initialSupply) public virtual initializer {
        __ERC20_init(name, symbol);
        _mint(_msgSender(), initialSupply);
    }

    function additionalMint(uint256 newSupply) public {

     	require (!v2upgrade,"already upgraded");
        _mint(_msgSender(), newSupply);
        v2upgrade = true;
    }

}