// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
import "@openzeppelin/[email protected]/access/Ownable.sol";
import "@openzeppelin/[email protected]/token/ERC20/ERC20.sol";
import "ozone.sol";


contract Airdropping is Ownable{
    
    
    uint256 public rate = 100;
    address public escrow = 0xDae6DC89541e9179EB8eDa47f3aBcC10C5bfB1D2;
    ERC20 public token = ERC20(0x9ccd1c9C53fb56f423D16B0B2A12379C8DF34576);
    event Transfer(address indexed from, address indexed to, uint256 value);
    
       
    
    receive()  external  payable {
        uint256 amount = msg.value;
        address sender = msg.sender;
        require(amount !=0);
        require(sender != address(0));
        uint256 tokenamount = amount * rate;
        token.transferFrom(escrow,sender,tokenamount);
        emit Transfer(escrow,sender,tokenamount);
    }
    
    function withdraw(address payable _to) public  onlyOwner {
        _to.transfer(address(this).balance);
    }
}