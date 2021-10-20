// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./ERC20Upgradeable.sol";
import "./libs/Initializable.sol";
import "./SDAOUpgradableToken.sol";


contract SDAOUpgradableToken2 is  SDAOUpgradableToken {
    
    bool v2upgrade;

    function additionalMint(uint256 newSupply) public {

     	require (!v2upgrade,"already upgraded");
        _mint(_msgSender(), newSupply);
        v2upgrade = true;
    }

}