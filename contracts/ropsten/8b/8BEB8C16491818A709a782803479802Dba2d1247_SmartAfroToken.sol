pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

contract SmartAfroToken is ERC20,Ownable  {
    constructor() ERC20("SmartAfro Coin", "SACOIN") {
        _mint(msg.sender, 1000);
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function burn(address _to, uint256 _amount) public onlyOwner {
        _burn(_to, _amount);
    }
}