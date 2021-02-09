pragma solidity =0.6.6;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "./interfaces/IWhitelistingTool.sol";

contract WhitelistingTool is
    IWhitelistingTool,
    Initializable,
    OwnableUpgradeable
{
    mapping(address => bool) whitelistedAddrs;

    event Whitelisting(address addr);
    event Unwhitelisting(address addr);

    function initialize() public initializer {
        OwnableUpgradeable.__Ownable_init();
    }

    function whitelist(address _addr) public onlyOwner {
        if(!whitelistedAddrs[_addr]) {
            whitelistedAddrs[_addr] = true;
            emit Whitelisting(_addr);
        }
    }

    function Unwhitelist(address _addr) public onlyOwner {
        if (whitelistedAddrs[_addr]) {
            delete whitelistedAddrs[_addr];
            emit Unwhitelisting(_addr);
        }
    }

    function whitelistAll(address[] memory _addrs) public onlyOwner {
        for (uint i = 0; i < _addrs.length; i ++) {
            whitelist(_addrs[i]);
        }
    }

    function UnwhitelistAll(address[] memory _addrs) public onlyOwner {
        for (uint i = 0; i < _addrs.length; i ++) {
            Unwhitelist(_addrs[i]);
        }
    }

    function isWhitelisted(address _addr) external view override returns (bool) {
        return whitelistedAddrs[_addr] || false;
    }
}