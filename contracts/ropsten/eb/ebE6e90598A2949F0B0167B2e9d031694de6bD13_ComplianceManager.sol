// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * Compliance Manager for whiteListed and blackListed Addresses using arrays rather than mappiing.
 */

contract ComplianceManager is AccessControl{

    event AddedToWhiteList(address indexed user, string message);
    event RemovedFromWhiteList(address indexed user, string message);
    event AddedToBlackList(address indexed user, string message);
    event RemovedFromBlackList(address indexed user, string message);

    address[] public blackList;
    address[] public whiteList;

 /**
 * INPUT_ROLE for the actor who is allowed to add and remove addresses from the lists.
 * Currently asigned to the deployer but the role can be granted to others
 * in accordance with the compliance and governance rules.
 */
    bytes32 public constant INPUT_ROLE = keccak256("INPUT_ROLE");

    constructor(){
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(INPUT_ROLE, msg.sender);
    }

/**
 * For control proposes if an address needs to be added to the BlackList it could not
 * currently be in the WhiteList.
 */  
    function addBlackList(address _addr) public onlyRole(INPUT_ROLE) {
    require(!checkWhiteList(_addr),"Address in the WhiteList. Remove it first");
    blackList.push(_addr);
    emit AddedToBlackList(_addr, "Successfully added to BlackList");
    }
    
    function getBlackList() public view returns(address[] memory) {
        return blackList;
    }

    function checkBlackList(address _addr) public view returns (bool){
        for(uint i; i< blackList.length;i++){
            if(blackList[i] == _addr){
               return true;
            }
        } return false;
    }

    function removeFromBlackList(address _addr) public onlyRole(INPUT_ROLE) {
        require(checkBlackList(_addr), "Address not in the BlackList");
        for(uint i; i < blackList.length; i++){
            delete blackList[i];
        emit RemovedFromBlackList (_addr, "Successfully removed from BlackList");    
        }
    }
/**
 * For control proposes if an address needs to be added to the WhiteList it could not
 * currently be in the BlackList.
 */
    function addwhiteList(address _addr) public onlyRole(INPUT_ROLE) {
    require(!checkBlackList(_addr),"Address in the BlackList. Remove it first");
    whiteList.push(_addr);
    emit AddedToWhiteList(_addr, "Successfully added to WhiteList");
    }
    
    function getwhiteList() public view returns(address[] memory) {
        return whiteList;
    }

    function checkWhiteList(address _addr) public view returns (bool){
        for(uint i; i< whiteList.length;i++){
            if(whiteList[i] == _addr){
               return true;
            }
        } return false;
    }

    function removeFromwhiteList(address _addr) public onlyRole(INPUT_ROLE) {
        require(checkWhiteList(_addr), "Address not in the whiteList");
        for(uint i; i < whiteList.length; i++){
            delete whiteList[i];
            emit RemovedFromWhiteList (_addr, "Successfully removed from WhiteList");
        } 
    }

    function getAddressStatus(address _addr) public view returns (
        bool _blackListResult, 
        bool _whiteListResult) {
        _blackListResult = checkBlackList(_addr);
        _whiteListResult = checkWhiteList(_addr);
        return (_blackListResult , _whiteListResult); 
    }
}