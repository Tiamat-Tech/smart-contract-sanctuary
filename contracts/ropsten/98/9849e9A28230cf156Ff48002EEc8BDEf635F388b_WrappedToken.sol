// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WrappedToken is ERC20, Ownable {
    uint256 public feePercent;
    address public feeRecipient;

    event Deposited(address indexed account, uint256 mintValue, uint256 fee);
    event Withdrawn(address indexed account, uint256 amount);
    event FeePercentUpdated(uint256 indexed feePercent);
    event FeeRecipientUpdated(address indexed feeRecipient);

    constructor(
        string memory name_,
        string memory symbol_,
        address feeRecipient_,
        uint256 feePercent_
    ) ERC20(name_, symbol_) {
        _updateFeeRecipient(feeRecipient_);
        _updateFeePercent(feePercent_);
    }

    receive() external payable {
        deposit();
    }

    function deposit() public payable returns (uint256) {
        uint256 fee = (msg.value * feePercent) / 100;
        uint256 mintValue = msg.value - fee;
        _mint(msg.sender, mintValue);
        transfer(feeRecipient, fee);
        emit Deposited(msg.sender, mintValue, fee);
        return mintValue;
    }

    function updateFeePercent(uint256 percent) external onlyOwner returns (bool) {
        _updateFeePercent(percent);
        return true;
    }

    function updateFeeRecipient(address _feeRecipient) external onlyOwner returns (bool) {
        _updateFeeRecipient(_feeRecipient);
        return true;
    }

    function withdraw(uint256 amount) external returns (bool) {
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
        emit Withdrawn(msg.sender, amount);
        return true;
    }

    function _updateFeePercent(uint256 percent) internal {
        require(percent <= 100, "Fee percent gt 100");
        feePercent = percent;
        emit FeePercentUpdated(feePercent);
    }

    function _updateFeeRecipient(address _feeRecipient) internal {
        require(_feeRecipient != address(0), "Zero address");
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(feeRecipient);
    }
}