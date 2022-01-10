// contracts/GameItems.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol";


contract GameItems is ERC1155 {
    uint256 public totalSupply = 0;
    address public owner;
    mapping(address => bool) public WL;

    constructor() public ERC1155("https://game.example/api/item/") {
        owner = msg.sender;
    }


    function setWL(address[] memory _address) public onlyOwner() {
        for(uint256 i; i<_address.length; i++){
            require(_address[i] != address(0), "Invalid address found");
            address tempAdd = _address[i];
            WL[tempAdd] = true;
        }
    }

    function removeWL(address[] memory _address) public onlyOwner() {
        for(uint256 i; i<_address.length; i++){
            require(_address[i] != address(0), "Invalid address found");
            address tempAdd = _address[i];
            WL[tempAdd] = false;
        }
    }


    function Minto(uint256 quantity) public onlyWL() {
        require(msg.sender != address(0), "invalid address");
        require(quantity > 0,             "invalid quantity");
        
        _mint(msg.sender, totalSupply, quantity, "");
        totalSupply++;
    }


    // "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4","0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"
    // -------------------------------------------------------------

    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    modifier onlyWL() {
        require(WL[msg.sender] == true, "Caller is not Whitelist");
        _;
    }

}