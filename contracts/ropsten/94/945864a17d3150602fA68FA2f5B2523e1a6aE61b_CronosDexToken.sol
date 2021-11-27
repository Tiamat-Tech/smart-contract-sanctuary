// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CronosDexToken is ERC20, Ownable {
    using SafeMath for uint256;
    
    uint256 constant MAXCAPSUPPLY = 60_000_000 * (10 ** 18);

    function maxSupply() public  pure returns (uint256) {
        return MAXCAPSUPPLY;
    }

    function _mint(address account, uint256 amount) internal virtual override {
        require(totalSupply().add(amount) <= MAXCAPSUPPLY, "Max supply reached");
        super._mint(account, amount);
    }

    constructor() ERC20('CronosDex Finance', 'CRONOS') {}

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
    
}