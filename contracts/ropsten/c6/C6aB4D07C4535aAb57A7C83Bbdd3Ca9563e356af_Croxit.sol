// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Croxit is ERC20{
    
    event OwnerTransfered(address oldOwner, address newOwner);
    
    address public owner;
    
    constructor() ERC20("Croxit", "CRXT"){
        owner = msg.sender;
    }
    
    modifier onlyOwner(){
        require(msg.sender == owner, "So sorry, you are not the owner :(");
        _;
    }
    
    function transferOwner(address _newOwner)
    public 
    onlyOwner{
        owner = _newOwner;
        emit OwnerTransfered(msg.sender, _newOwner);
    }
    
    function mint(address _account, uint _amount)
    public 
    onlyOwner{
        _mint(_account, _amount);
    }
    
    function burn(address _account, uint _amount)
    public
    onlyOwner{
        _burn(_account, _amount);
    }
}