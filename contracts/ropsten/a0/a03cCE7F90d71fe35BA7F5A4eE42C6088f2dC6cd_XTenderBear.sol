// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./@openzeppelin/contracts/utils/Address.sol";
import "./@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract XTenderBear is ERC20 {
    using Address for address;
    using SafeERC20 for IERC20;

    IERC20 public token;

    constructor(address _token) ERC20("XTenderBear", "XTDB") {
        token = IERC20(_token);
    }

    function balance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function deposit(uint256 _amount) public {
        // Amount must be greater than zero
        require(_amount > 0, "amount cannot be 0");

        // Transfer TenderBear to smart contract
        token.safeTransferFrom(msg.sender, address(this), _amount);

        // Mint XTenderBear to msg sender
        _mint(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) public {
        // Burn XTenderBears from msg sender
        _burn(msg.sender, _amount);

        // Transfer TenderBear from this smart contract to msg sender
        token.safeTransfer(msg.sender, _amount);
    }
}