pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

contract FTPAntiBot is Context, Ownable {
    event addressScanned(
        address _address,
        address safeAddress,
        address _origin
    );
    event blockRegistered(address _recipient, address _sender);

    function scanAddress(
        address _address,
        address safeAddress,
        address _origin
    ) external returns (bool) {
        emit addressScanned(_address, safeAddress, _origin);
        return true;
    }

    function registerBlock(address _recipient, address _sender) external {
        emit blockRegistered(_recipient, _sender);
    }
}