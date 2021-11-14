// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "hardhat/console.sol";
import "./Auth.sol";
// Import Ownable from the OpenZeppelin Contracts library
import "@openzeppelin/contracts/access/Ownable.sol";

contract Auto is Ownable{

    string public nameAuto;
    Auth private _auth; 
    string public MyName;
    constructor () {
        _auth = new Auth(msg.sender);     
        nameAuto = "Fiat"; 
        console.log("Name : ", nameAuto);
    }

    function setNameAuto(string memory _nameAuto) public  {
        require(_auth.isAdministrator(msg.sender), "Unauthorized");
        nameAuto = _nameAuto;
    }

    function getNameAuto() external view returns(string memory) {
            return nameAuto;
    }


    //Restrict area
    function setMyName(string memory _myName) public onlyOwner {
        MyName = _myName;
    }

    function getMyName() external view returns (string memory) {
         require(_auth.isAdministrator(msg.sender), "Unauthorized");    
         return MyName;
    }

}