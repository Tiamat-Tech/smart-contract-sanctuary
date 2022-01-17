//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// CakeToken with Governance.
contract ClassyToken is ERC20("New Classy Token", "NCLSY"), Ownable {
    address private _minter;

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function mint(address _to, uint256 _amount) public {
        require(_msgSender() != address(0), "mint : owner is the zero address");
        require(
            _msgSender() == _minter,
            "mint : mint can only be used minter or owner address"
        );
        require(
            _msgSender() == owner(),
            "mint : mint can only be used minter or owner address"
        );

        _mint(_to, _amount);
    }

    function setMinter(address _newMinter) public onlyOwner {
        _minter = _newMinter;
    }

    function getMinter() public view virtual returns (address) {
        return _minter;
    }
}