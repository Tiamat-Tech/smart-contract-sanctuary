// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./extensions/ERC20Burnable.sol";
import "./ERC20Standard.sol";

contract ERC20Mintable is ERC20Standard {
    string private _name;
    string private _symbol;
    uint256 private _cap;
   mapping(address => uint256) private _balances;
  

    constructor(
        address owner,
        uint256 cap_,
        string memory name,
        string memory symbol,
        uint8 decimal,
        uint256 initialSupply
    ) ERC20Standard(name, symbol, decimal) {
        _name = name;
        _symbol = symbol;
        _cap = cap_;
        _mint(owner, initialSupply);
        _totalSupply = initialSupply  *  10  ** uint8(decimal);
        
    }
    

    function mint(address recipient, uint256 amount) external {
        _mint(recipient, amount);
    }

    function cap() public view virtual returns (uint256) {
        return _cap;
    }

    function _mint(address account, uint256 amount) internal virtual override {
        require(
            ERC20Standard.totalSupply() + amount <= cap(),
            "ERC20Capped: cap exceeded"
        );
        super._mint(account, amount);
    }
}