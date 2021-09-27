//SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

contract DepositPool is Ownable {
    mapping(address => uint256) public deposits;
    mapping(address => bool) public whitelisted;

    IERC20 public paymentToken;

    address _receiver = 0x80b74Fc782cFa71a4255a4e3F92e117F29fBC818;
    uint256 public startDate;
    uint256 public closeDate;
    bool public whitelistEnabled = true;
    uint256 public paymentsReceived;
    uint256 private _divider = 10000;
    uint256 public minDeposit = 100 * 1e18;
    uint256 public maxDeposit = 1000 * 1e18;
    uint256 public goal;

    event Deposit(address participant, uint256 amount, uint256 newDepositTotal);

    constructor(
        address _paymentToken,
        uint256 _startDate,
        uint256 _closeDate,
        uint256 _goal
    ) {
        require(_startDate < _closeDate, "Wrong dates");

        paymentToken = IERC20(_paymentToken);
        startDate = _startDate;
        closeDate = _closeDate;
        goal = _goal;
    }

    function saleActive() public view returns (bool) {
        if (paymentsReceived >= goal) return false;
        return (block.timestamp >= startDate && block.timestamp <= closeDate);
    }

    function canBuy(address wallet) public view returns (bool) {
        if (!saleActive()) return false;
        if (!whitelistEnabled) return true;
        if (whitelisted[wallet]) return true;
        return false;
    }

    function setWhitelist(bool enabled) public onlyOwner {
        whitelistEnabled = enabled;
    }

    function deposit(uint256 amount) public {
        require(saleActive(), "The sale is not active");
        require(canBuy(msg.sender), "You cant buy tokens");
        require(deposits[msg.sender] + amount > minDeposit, "You can't invest such small amount");
        require(paymentToken.balanceOf(msg.sender) >= amount, "You don't have enough funds to deposit");
        require(paymentToken.allowance(msg.sender, address(this)) >= amount, "Approve contract for spending your funds");
        require(deposits[msg.sender] + amount <= maxDeposit, "You can't invest such big amount");

        paymentToken.transferFrom(msg.sender, _receiver, amount);
        deposits[msg.sender] += amount;
        paymentsReceived += amount;

        emit Deposit(msg.sender, amount, deposits[msg.sender]);
    }

    function setSaleDates(uint256 _startDate, uint256 _closeDate) external onlyOwner {
        require(startDate < closeDate && startDate != 0 && closeDate != 0, "Wrong dates");
        startDate = _startDate;
        closeDate = _closeDate;
    }

    function setPaymentToken(address _paymentToken) external onlyOwner {
        paymentToken = IERC20(_paymentToken);
    }

    function setMinMaxDepo(uint256 _minDeposit, uint256 _maxDeposit) external onlyOwner {
        minDeposit = _minDeposit;
        maxDeposit = _maxDeposit;
    }

    function batchSetWhitelist(address[] calldata _recepients, bool value) external onlyOwner {
        for (uint32 i = 0; i < _recepients.length; i++) {
            whitelisted[_recepients[i]] = value;
        }
    }

    function extractPaymentToken(uint256 amount) external onlyOwner {
        paymentToken.transfer(msg.sender, amount);
    }

    function extractValue() external onlyOwner {
        msg.sender.call{value: address(this).balance}("");
    }
}