// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../libraries/Authorizable.sol";

contract xJoyToken is ERC20, Ownable, Authorizable {
    using SafeMath for uint256;

    constructor(
      string memory _name,
      string memory _symbol
    ) ERC20(_name, _symbol) {
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner.
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}