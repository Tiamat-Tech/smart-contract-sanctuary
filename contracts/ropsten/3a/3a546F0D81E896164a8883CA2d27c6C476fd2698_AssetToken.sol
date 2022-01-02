// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// Blending with Governance.
contract AssetToken is ERC20Upgradeable {

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
    
    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}