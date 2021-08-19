// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract twkim is ERC20, ERC20Burnable, Ownable {
    string depositAddress = "0000000000000000000000000000000000";
    address ownerAddress = 0x5e2A9A0095b20633fD2606CACBE7298878b23e08;

    event Received(address, uint256);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(ownerAddress, 10 * 10**decimals());
    }

    function minttoken() public onlyOwner returns (uint8) {
        _mint(ownerAddress, 10 * 10**decimals());
        return 1;
    }

    function decimals() public view virtual override returns (uint8) {
        return 8;
    }

    function setDepositAddress(string memory depositAdr) public onlyOwner {
        depositAddress = depositAdr;
    }

    function getDepositAddress() public view returns (string memory) {
        return depositAddress;
    }
}