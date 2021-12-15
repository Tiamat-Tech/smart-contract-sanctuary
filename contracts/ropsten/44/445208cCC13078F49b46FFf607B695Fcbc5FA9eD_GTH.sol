//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "hardhat/console.sol";

contract GTH is OwnableUpgradeable, ERC20PresetMinterPauserUpgradeable, ReentrancyGuardUpgradeable {
    uint256 public maxMintLimit;
    mapping(address => uint256) public mintPermissions;

    mapping(address => bool) public blacklisted;

    function GTH_init() public initializer {
        __Ownable_init();
        __ERC20PresetMinterPauser_init("Gather", "GTH");
        __ReentrancyGuard_init();
        maxMintLimit = 400000000 * (10**uint256(18));
    }

    event Mint(address indexed to, uint256 amount);

    modifier notBlacklisted(address account) {
        require(!blacklisted[account], "GTH: the account is blacklisted");
        _;
    }

    modifier canMint() {
        require(totalSupply() < maxMintLimit, "GTH: Total supply reached max.");
        _;
    }

    modifier hasMintPermission() {
        require(
            checkMintPermission(msg.sender),
            "GTH: the caller reached his max limit"
        );
        _;
    }

    function setMinter(address minter, uint256 amount)
        external
        onlyOwner
        notBlacklisted(minter)
    {
        require(minter != owner(), "GTH: minter can NOT be owner.");
        revokeRole(MINTER_ROLE, owner());
        grantRole(MINTER_ROLE, minter);
        mintPermissions[minter] = amount;
    }

    function setPauser(address pauser)
        external
        onlyOwner
        notBlacklisted(pauser)
    {
        require(pauser != owner(), "GTH: minter can NOT be owner.");
        revokeRole(PAUSER_ROLE, owner());
        grantRole(PAUSER_ROLE, pauser);
    }

    function pause()public override notBlacklisted(_msgSender()){
        super.pause();
    }
    function unpause()public override notBlacklisted(_msgSender()){
        super.unpause();
    }


    function mint(address to, uint256 amount)
        public
        override
        notBlacklisted(_msgSender())
        notBlacklisted(to)
        whenNotPaused
        nonReentrant
        canMint
        hasMintPermission
    {
        require(
            totalSupply() + amount <= maxMintLimit,
            "GTH: the minter reaches max mint limit"
        );
        super.mint(to, amount);
        mintPermissions[msg.sender] = mintPermissions[msg.sender] - amount;
        emit Mint(to, amount);
    }

    function mintAllowed(address minter) external view returns (uint256) {
        return mintPermissions[minter];
    }

    function checkMintPermission(address minter) private view returns (bool) {
        return mintPermissions[minter] > 0;
    }

    function addToBlackList(address account) public onlyOwner {
        require(!blacklisted[account], "GTH: account already blacklisted");
        blacklisted[account] = true;
    }

    function removeFromBlackList(address account) public onlyOwner {
        require(blacklisted[account], "GTH: account was already removed from blacklist");
        blacklisted[account] = false;
    }

    function isBlacklisted(address account)external view returns (bool){
        return blacklisted[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        notBlacklisted(_msgSender())
        notBlacklisted(recipient)
        whenNotPaused
        nonReentrant
        returns (bool)
    {
        return super.transfer(recipient, amount);
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
        whenNotPaused
        nonReentrant
        returns (bool)
    {
        return super.transferFrom(sender, recipient, amount);
    }

    
}