//SPDX-License-Identifier: NONE

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract RewardNFT is ERC721{

    uint tokenID = 0;
    uint public remaining = 50 ;
    address contractAuction;
    address Owner;
    uint totalSupply = 50;
    modifier onlyOwner(){
        require(msg.sender == Owner,"only owner can be use this function");
        _;
    }
    modifier onlyContract(){
        require(msg.sender == contractAuction,"only contract can be use this function");
        _;
    }

    mapping(address => uint) internal _pass;

    constructor(
        address _owner
    ) ERC721("RewardNFT","RNFT", _owner){
        Owner = _owner;
    }    

    function checkOwner() view public returns (address) {
        return (Owner);
    }

    function updatePass(address user, uint amount) public onlyContract{
        _pass[user] += amount;
    }

    function claimPass(address user, uint amount) internal{
        _pass[user] -= amount;
    }

    function updateContractAddress(address _ContractAuction) public onlyOwner{
        contractAuction = _ContractAuction;
    }

    function mint() public {
        require(_pass[msg.sender] >= 1, "you don't have Pass");
        _safeMint(msg.sender, (tokenID++));
        tokenID++;
        remaining - tokenID;
        claimPass(msg.sender,1);
    }
    function checkPass(address user) view public returns (uint) {
        return (_pass[user]);
    }
}