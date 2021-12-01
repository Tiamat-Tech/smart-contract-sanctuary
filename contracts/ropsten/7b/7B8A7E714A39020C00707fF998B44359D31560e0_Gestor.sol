/*
   _____                       ____                  _   __  __      _            
  / ____|                     |  _ \                | | |  \/  |    | |           
 | |  __ _ __ ___  ___ _ __   | |_) | ___  _ __   __| | | \  / | ___| |_ ___ _ __ 
 | | |_ | '__/ _ \/ _ \ '_ \  |  _ < / _ \| '_ \ / _` | | |\/| |/ _ \ __/ _ \ '__|
 | |__| | | |  __/  __/ | | | | |_) | (_) | | | | (_| | | |  | |  __/ ||  __/ |   
  \_____|_|  \___|\___|_| |_| |____/ \___/|_| |_|\__,_| |_|  |_|\___|\__\___|_|   
                                                                                                                                                                  
*/

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.8.10;

contract Gestor is Ownable {

    string[] private data;    

    constructor() {}

    function setData(string memory _data) public onlyOwner {
        data.push(_data);        
    }

    function getAllData() public view returns(string[] memory){
        return data;
    }

    function getData(uint256 _index) public view returns(string memory){
        return data[_index];
    }
    
    function modifyData(string memory _data, uint256 _index) public onlyOwner {
        data[_index] = _data;
    }
    

}