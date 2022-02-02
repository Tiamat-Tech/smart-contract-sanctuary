// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import '@openzeppelin/contracts/access/Ownable.sol';

/*
* @title Decentralize list address
* @author nobodyw, https://github.com/nobodyw
* @notice Administration system with whitelist and blacklist
*/
contract Admin is Ownable{

    mapping(address => bool) WhiteList;
    mapping(address => bool) BlackList;

    event Whitelisted(address userWhiteList, bool isWhiteList);
    event BlackListed(address userBlackList, bool isBlackList);

/*
* @notice The owner adds an address in the whiteList
* @dev If the address was blacklisted add to whitelist
*/
    function addToWhiteList(address _addressWhiteListed) external onlyOwner {
        require(!WhiteList[_addressWhiteListed], "The account is already WhiteListed");

        WhiteList[_addressWhiteListed] = true;
        BlackList[_addressWhiteListed] = false;
        emit Whitelisted(_addressWhiteListed, WhiteList[_addressWhiteListed]);
    }

/*
* @notice The owner adds an address in the blacklist
* @dev If the address was whitelisted add to blacklist
*/
    function addToBlackList(address _addressBlackListed) external onlyOwner {
        require(!BlackList[_addressBlackListed], "The account is already BlackListed");

        BlackList[_addressBlackListed] = true;
        WhiteList[_addressBlackListed] = false;
        emit BlackListed(_addressBlackListed, BlackList[_addressBlackListed]);
    }

/*
* @notice return true if address is in whitelist
*/
    function isWhitelisted(address _addressUser) external view returns(bool){
        return WhiteList[_addressUser];
    }

/*
* @notice return true if address is in blacklist
*/
    function isBlacklisted(address _addressUser) external view returns(bool){
        return BlackList[_addressUser];
    }

/*
* @notice cancels the user in all lists
*/
    function removeList(address _addressUser) external onlyOwner{
        WhiteList[_addressUser] = false;
        BlackList[_addressUser] = false;
    }
}