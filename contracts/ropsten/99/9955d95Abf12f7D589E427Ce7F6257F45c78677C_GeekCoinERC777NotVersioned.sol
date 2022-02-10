// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GeekCoinERC777NotVersioned is ERC777, Pausable, Ownable {
    constructor() ERC777("GeekCoinNVERC777", "GKC", new address[](0)) {
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256 amount
    ) internal whenNotPaused override {
        super._beforeTokenTransfer(
            operator,
            from,
            to,
            amount
        );
    }

    function mint(
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    ) public onlyOwner {
        _mint(to, amount, userData, operatorData);
    }

    function mint(
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData,
        bool requireReceptionAck
    ) public onlyOwner {
        _mint(to, amount, userData, operatorData, requireReceptionAck);
    }
}