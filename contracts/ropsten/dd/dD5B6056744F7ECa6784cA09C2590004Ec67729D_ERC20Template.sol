pragma solidity ^0.5.0;

import "./../../../libs/GSN/Context.sol";
import "./../../../libs/token/ERC20/ERC20.sol";
import "./../../../libs/token/ERC20/ERC20Detailed.sol";

contract ERC20Template is Context, ERC20, ERC20Detailed {
    
    constructor () public ERC20Detailed("The Test Token", "TTT", 9) {
        _mint(_msgSender(), 10000000000000);
    }
}