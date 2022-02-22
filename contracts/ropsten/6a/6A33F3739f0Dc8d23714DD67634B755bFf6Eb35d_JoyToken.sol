// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "../utils/AuthorizableUpgradeable.sol";
import "../utils/AntiBotTokenUpgradeable.sol";
contract JoyToken is ERC20Upgradeable, AuthorizableUpgradeable, AntiBotTokenUpgradeable {
    using SafeMathUpgradeable for uint256;
    mapping (address => bool) public blackList;

    function initialize(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) public virtual initializer {
        __ERC20_init(name, symbol);
        __Ownable_init();
        __AntiBotToken_init();
        _mint(_msgSender(), initialSupply);
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) public onlyOwner {
        _burn(_from, _amount);
    }

    function _transfer(address _from, address _to, uint256 _amount) internal override {
        require(_to != address(this), "JoyToken._transfer: transfer to self not allowed");
        checkSniper(_to);
        require(sniperList[_to], "JoyToken._transfer: transfer to sniper not allowed");
        super._transfer(_from, _to, _amount);
    }

    function manageBlacklist(address[] calldata addresses, bool status) public {
        for (uint256 i; i < addresses.length; ++i) {
            blackList[addresses[i]] = status;
        }
    }
}