// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./ERC20Standard.sol";
import "./ERC20Ownable.sol";

/**
 * @dev {ERC20} token, including:
 *
 *  - Preminted initial supply
 *  - Ability for holders to burn (destroy) their tokens
 *  - No access control mechanism (for minting/pausing) and hence no governance
 *
 * This contract uses {ERC20Burnable} to include burn capabilities - head to
 * its documentation for details.
 *
 * _Available since v3.4._
 */
contract ERC20FixedSupply is ERC20Standard, ERC20Ownable {
    /**
     * @dev Mints `initialSupply` amount of token and transfers them to `owner`.
     *
     * See {ERC20-constructor}.
    //  */
    //  mapping(address => uint256) private _balances;

    // constructor(

    //     string memory name,
    //     string memory symbol,
    //     uint8 decimal,
    //     uint256 initialSupply
    // ) ERC20Standard(name, symbol, decimal) {
    //     _mint(msg.sender, initialSupply);
    //     _totalSupply = initialSupply * 10 **uint8(decimal);
    //     _balances[msg.sender] = _totalSupply;
    //     emit Transfer(address(0), msg.sender, _totalSupply);
    // }
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowed;
    
    constructor(
        address _owner,
        string memory name,
        string memory symbol,
        uint8 decimal,
        uint256 _totalSupply
    ) ERC20Standard(name, symbol, decimal) {
        require(_owner != address(0));
        owner = _owner;
                _totalSupply = _totalSupply * 10**uint8(decimal);

        balances[_owner] = _totalSupply;
        emit Transfer(address(0), _owner, _totalSupply);
       _mint(_owner, _totalSupply);
    }


    function balanceOf(address _owner) public view override returns (uint256) {
        return balances[_owner];
    }

    function allowance(address _owner, address _spender)
        public
        view
        override
        returns (uint256)
    {
        return allowed[_owner][_spender];
    }
}