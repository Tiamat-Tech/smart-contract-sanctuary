//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";
//import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "hardhat/console.sol";

contract GTH is
    Initializable,
    ContextUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable
{
    uint256 public maxMintLimit;

    mapping(address => bool) public blacklisted;

    function GTH_init() public initializer {
        __Context_init();
        __Ownable_init();
        //        __ERC165_init();
        __ERC20_init("Gather", "GTH");
        __ERC20Burnable_init();
        __ERC20Pausable_init();

        // __ReentrancyGuard_init();//checking...
        maxMintLimit = 400000000 * (10**uint256(18));
    }

    event Mint(address indexed to, uint256 amount);

    modifier notBlacklisted(address account) {
        require(!blacklisted[account], "GTH: account is blacklisted");
        _;
    }

    modifier canMint() {
        require(totalSupply() < maxMintLimit, "GTH: total supply reached max.");
        _;
    }

    function pause() public notBlacklisted(_msgSender()) onlyOwner {
        //
        super._pause();
    }

    function unpause() public notBlacklisted(_msgSender()) onlyOwner {
        super._unpause();
    }

    function burn(uint256 amount) public override whenNotPaused onlyOwner {
        require(
            amount <= totalSupply(),
            "GTH: amount is more than total supply"
        );
        super.burn(amount);
    }

    function mint(address to, uint256 amount)
        external
        notBlacklisted(to)
        whenNotPaused
        nonReentrant
        canMint
        onlyOwner
    {
        require(
            totalSupply() + amount <= maxMintLimit,
            "GTH: total supply reached max mint limit"
        );
        super._mint(to, amount);
        emit Mint(to, amount);
    }

    function transferOwnership(address newOwner)
        public
        override
        notBlacklisted(newOwner)
    {
        super.transferOwnership(newOwner);
    }

    function addToBlackList(address account) public onlyOwner {
        require(account != owner(), "GTH: account can not be owner");
        require(!blacklisted[account], "GTH: account already blacklisted");
        blacklisted[account] = true;
    }

    function removeFromBlackList(address account) public onlyOwner {
        require(blacklisted[account], "GTH: account is not blacklisted");
        delete blacklisted[account];
    }

    function isBlacklisted(address account) external view returns (bool) {
        return blacklisted[account];
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable){
        super._beforeTokenTransfer(from, to, amount);
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        notBlacklisted(_msgSender())
        notBlacklisted(recipient)
        nonReentrant
        returns (bool)
    {
        return super.transfer(recipient, amount);
    }

    function approve(address spender, uint256 amount)
        public
        override
        notBlacklisted(_msgSender())
        notBlacklisted(spender)
        whenNotPaused
        returns (bool)
    {
        return super.approve(spender, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    )
        public
        override
        notBlacklisted(_msgSender())
        notBlacklisted(recipient)
        notBlacklisted(sender)
        nonReentrant
        returns (bool)
    {
        return super.transferFrom(sender, recipient, amount);
    }
}