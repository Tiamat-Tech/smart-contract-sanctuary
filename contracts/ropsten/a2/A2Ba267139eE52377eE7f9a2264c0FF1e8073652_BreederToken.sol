// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract BreederToken is AccessControl, ERC20Votes {
    // keccak256("MINTER_ROLE")
    bytes32 private constant MINTER_ROLE =
        0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;

    // keccak256("BURNER_ROLE")
    bytes32 private constant BURNER_ROLE =
        0x3c11d16cbaffd01df69ce1c404f6340ee057498f5f00246190ea54220576a848;

    // TODO: finalize name, symbol, decimals
    constructor() ERC20Permit("Breeder") ERC20("Breeder", "$BREED") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(address _to, uint _amount) external onlyRole(MINTER_ROLE) {
        _mint(_to, _amount);
    }

    // TODO: enable burn?
    // function burn(address _from, uint256 _amount) onlyHasRole(BURNER_ROLE) external {
    //     _burn(_from, _amount);
    // }

    function _transfer(
        address _from,
        address _to,
        uint _amount
    ) internal override {
        require(_to != address(this), "transfer to self not allowed");
        super._transfer(_from, _to, _amount);
    }
}