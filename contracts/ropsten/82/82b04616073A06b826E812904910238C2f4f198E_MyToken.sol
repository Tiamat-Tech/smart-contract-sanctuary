// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "openzeppelin-solidity/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract MyToken is ERC20PresetFixedSupply{
uint8 immutable private _decimals;
    constructor (string memory _name, string memory _symbol,uint256 _initialSupply,
        address _owner,uint8 decimals_)

        ERC20PresetFixedSupply(_name,_symbol,_initialSupply,_owner)
        {
            _decimals=decimals_;
        }
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
        
}