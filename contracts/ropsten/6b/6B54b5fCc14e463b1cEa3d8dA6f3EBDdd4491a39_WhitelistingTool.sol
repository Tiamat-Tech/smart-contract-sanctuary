pragma solidity =0.6.6;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "./interfaces/IWhitelistingTool.sol";

contract WhitelistingTool is
    IWhitelistingTool,
    Initializable,
    OwnableUpgradeable
{
    mapping(address => bool) public whitelistedAddrs;

    event Whitelisting(address addr);
    event Unwhitelisting(address addr);

    function initialize() external initializer {
        OwnableUpgradeable.__Ownable_init();
    }

    function whitelist(address _addr) public onlyOwner {
        if(!whitelistedAddrs[_addr]) {
            whitelistedAddrs[_addr] = true;
            emit Whitelisting(_addr);
        }
    }

    function unwhitelist(address _addr) public onlyOwner {
        if (whitelistedAddrs[_addr]) {
            delete whitelistedAddrs[_addr];
            emit Unwhitelisting(_addr);
        }
    }

    function whitelistAll(address[] calldata _addrs) external override onlyOwner {
        for (uint i = 0; i < _addrs.length; i ++) {
            whitelist(_addrs[i]);
        }
    }

    function unwhitelistAll(address[] calldata _addrs) external override onlyOwner {
        for (uint i = 0; i < _addrs.length; i ++) {
            unwhitelist(_addrs[i]);
        }
    }

    function isWhitelisted(address _addr) external view override returns (bool) {
        return whitelistedAddrs[_addr] || false;
    }
}