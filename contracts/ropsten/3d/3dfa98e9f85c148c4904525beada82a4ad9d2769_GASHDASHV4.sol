// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract GASHDASHV4 is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, PausableUpgradeable, OwnableUpgradeable, ERC20PermitUpgradeable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    mapping(address => uint256) private lastWrite;
    mapping(address => bool) private adminList;

    function initialize() initializer public {
        __ERC20_init("GASHUPD", "GASHUPD");
        __ERC20Burnable_init();
        __Pausable_init();
        __Ownable_init();
        __ERC20Permit_init("GASHUPD");
        __UUPSUpgradeable_init();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) external {
        require(adminList[msg.sender], "Only admins can mint");
        _mint(to, amount);
    }

    /**
     * creates an admin
     * @param admin - address of the admin
    */
    function createAdmin(address admin) external onlyOwner {
        adminList[admin] = true;
    }

    /**
     * disables an admin
     * @param admin - address of the admin
    */
    function deleteAdmin(address admin) external onlyOwner {
        adminList[admin] = false;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal whenNotPaused override {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal onlyOwner override {}

    string sayHelloWorldV3;

    function setHello(string memory _hello) external onlyOwner {
        sayHelloWorldV3 = _hello;
    }

    function sayHello() external view returns(string memory) {
        return sayHelloWorldV3;
    }

    string value;

    function sayDome(string memory _value) external onlyOwner returns(string memory) {
        value = _value;
        return value;
    }
}