// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract UScoin is ERC20{
    address public admin;
    mapping(address => uint256) private _balances;

    uint8 public constant DECIMALS = 18;
    uint256 public constant INITIAL_SUPPLY = 420 * (10 ** uint256(DECIMALS));

    constructor() ERC20('$MARS','$MARS'){
        _mint(msg.sender,INITIAL_SUPPLY);
    }

    function mint(address to, uint amount) public {
        // require(msg.sender == admin, 'only admin');
        _mint(to,amount);
    }

    function balance(address account) public view virtual returns (uint256) {
        return balanceOf(account);
    }

    function transfer(address sender, address recipient, uint256 amount) public {
        // require(msg.sender == admin, 'only admin');
        _transfer(sender,recipient,amount);
    }
}