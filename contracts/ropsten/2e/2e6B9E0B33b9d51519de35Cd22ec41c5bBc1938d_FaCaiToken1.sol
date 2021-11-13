// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./aa/Ajson.sol";

contract FaCaiToken1 is ERC20Burnable, Ownable, Ajson {
    using SafeMath for uint256;
    
    uint256 public maxSupply = 10000000000 * 1e18;     // the total supply
    uint256 public preMineSupply = 9000000000 * 1e18;
    
    address public minter;

    constructor() ERC20("FaCai Token", "FC"){
        _mint(msg.sender, preMineSupply);
    }

    // mint with max supply
    function mint(address _to, uint256 _amount) public onlyMinter returns (bool) {
        if (_amount.add(totalSupply()) > maxSupply) {
            return false;
        }
        _mint(_to, _amount);
        return true;
    }

    function setMinter(address _minter) public onlyOwner returns (bool) {
        // require(_minter != address(0), "_minter is the zero address");
        minter = _minter;
        return true;
    }

    // modifier for mint function
    modifier onlyMinter() {
        require(msg.sender == minter, "caller is not the minter");
        _;

    }

}