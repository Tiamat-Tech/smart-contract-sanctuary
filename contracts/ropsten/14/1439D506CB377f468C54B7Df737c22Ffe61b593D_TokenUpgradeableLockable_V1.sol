// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract TokenUpgradeableLockable_V1 is Initializable, ERC20Upgradeable, OwnableUpgradeable {
    uint256 public maxSupply;

    struct whitelistAcct {
        bool exists;
        uint256 index_num;
    }
    mapping (address => whitelistAcct) private whitelists;
    address[] private whitelistAccts;

    struct blacklistAcct {
        bool exists;
        uint256 indexNum;
    }
    mapping (address => blacklistAcct) private blacklists;
    address[] private blacklistAccts;

    uint256 private whitelistIndexCount;
    uint256 private blacklistIndexCount;

    uint8 private _decimals;

    function initialize
        (
            string memory name_,
            string memory symbol_,
            uint256 maxSupply_,
            uint8 decimals_
        )
        external initializer {
            __ERC20_init (name_, symbol_);
            
            _decimals = decimals_;
            maxSupply = maxSupply_ * 10 ** decimals();

            __Ownable_init();    
        }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    modifier supplyRestriction(uint256 _mintSupply) {
        require(maxSupply >= totalSupply() + _mintSupply, "Max supply reached.");
        _;
    }

    modifier transferRestriction() {
        if (whitelistAccts.length > 0) {
            require (whitelists[msg.sender].exists == true, "Whitelist Mode: You cannot transfer token.");
        } else {
            require (blacklists[msg.sender].exists == false, "Blacklist Mode: You cannnot transfer token.");
        }
        _;
    }

    modifier mustNotExistYet(address _account) {
        require(whitelists[_account].exists == false, "The account is already in the whitelist.");
        require(blacklists[_account].exists == false, "The account is already in the blacklist.");
        _;
    }

    function addToWhitelist(address _account) external onlyOwner
        mustNotExistYet(_account) {
            whitelists[_account].exists = true;
            whitelists[_account].index_num = whitelistIndexCount;
            whitelistIndexCount++;

            whitelistAccts.push(_account);
    }

    function removeFromWhitelist(address _account) external onlyOwner {
            require(whitelists[_account].exists == true, "The account is not in the whitelist.");

            whitelists[_account].exists = false;
            delete whitelistAccts[whitelists[_account].index_num];
    }

    function addToBlacklist(address _account) external onlyOwner
        mustNotExistYet(_account) {
            blacklists[_account].exists = true;
            blacklists[_account].indexNum = blacklistIndexCount;
            blacklistIndexCount++;

            blacklistAccts.push(_account);
    }

    function removeFromBlacklist(address _account) external onlyOwner {
            require(blacklists[_account].exists == true, "The account is not in the blacklist.");

            blacklists[_account].exists = false;
            delete blacklistAccts[blacklists[_account].indexNum];
    }

    /**
     * @dev ERC20 functions
     */

    function mint(address _to, uint256 _mintSupply) external onlyOwner
        supplyRestriction(_mintSupply) {
            _mint(_to, _mintSupply);
    }

    function transfer(address recipient, uint256 amount) public transferRestriction override
        returns(bool) {  
            _transfer(_msgSender(), recipient, amount);
            return true;
    }

    function approve(address spender, uint256 amount) public transferRestriction override
        returns (bool) {
            _approve(_msgSender(), spender, amount);
            return true;
    }

    /**
     * @dev View
     */

    function getAllArrays() external view onlyOwner returns (uint256, address[] memory,
        uint256, address[] memory) {
            return
                (
                    whitelistAccts.length,
                    whitelistAccts,
                    blacklistAccts.length,
                    blacklistAccts
                );
    }
}