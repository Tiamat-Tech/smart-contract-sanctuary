// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "../@openzeppelin/contracts/access/Ownable.sol";

// import "@oopenzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
// import "@openzeppelin-contracts/contracts/access/Ownable.sol";

/// @custom:security-contact [email protected]
contract NGUDAOCOM is ERC20, ERC20Burnable, Ownable {

    mapping (address => bool) public authMinter;

    constructor() ERC20("NGUDAO.COM", "NGU") {
        authMinter[msg.sender] = true;
        _mint(msg.sender, 12000000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public {
        require(authMinter[msg.sender]);
        _mint(to, amount);
    }

    function setAuthMinter(address _minter, bool _auth) public onlyOwner {
        authMinter[_minter] = _auth;
    }
}