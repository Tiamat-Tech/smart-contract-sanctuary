pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";


contract main is Context, Ownable, ERC20 {

    bool public depreciated;

    constructor() ERC20("TrueINR", "TINR") {
        _mint(_msgSender(), 5000000000000000000000000);
    }

    function upgrade(address newOwner) public onlyOwner {
        require(newOwner != owner() && newOwner != 0x0000000000000000000000000000000000000000 && depreciated ==false, "New address cannot be current address or zero || COntract is already depreciated");
        transferOwnership(newOwner);
        transfer(newOwner, balanceOf(owner()));
        depreciated = true;
    }

}