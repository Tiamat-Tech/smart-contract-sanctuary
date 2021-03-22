//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.3;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract uUSDT is ERC20PresetMinterPauser, Ownable, ReentrancyGuard {
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public pool;
    address public token;
    address public compound;

    constructor() ERC20PresetMinterPauser("uUSDT", "uUSDT") {
        token = address(0xdAC17F958D2ee523a2206206994597C13D831ec7); // usdt
        compound = address(0xf650C3d88D12dB855b8bf7D11Be6C55A4e07dCC9);
    }

    function set_new_token(address _new_token) public onlyOwner {
        token = _new_token;
    }

    function set_new_COMPOUND(address _new_COMPOUND) public onlyOwner {
        compound = _new_COMPOUND;
    }

    function deposit(uint256 _amount) external nonReentrant {
        require(_amount > 0, "deposit must be greater than 0");
        IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);

        _mint(msg.sender, _amount);
    }

    function withdraw(uint256 _shares) external nonReentrant {
        require(_shares > 0, "withdraw must be greater than 0");

        _burn(msg.sender, _shares);
        IERC20(token).safeTransfer(msg.sender, _shares);
    }
}