pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "./IERC721.sol";
import "../../../utils/Strings.sol";
import "../../../utils/Address.sol";


contract ERC721{

    using Strings for uint256;
    using Address for address;

    string public name;
    string public symbol;


    mapping(address => uint256) public _balances;

    constructor (string memory _name, string memory _symbol){
        console.log("name and symbol collection:",_name,_symbol);
        name=_name;
        symbol=_symbol;
    } 

    function balanceOf(address owner) public view  returns(uint256 balance){
        require(owner != address(0),"ERC721: balance query for the zero address");
        return _balances[owner];
    }
}