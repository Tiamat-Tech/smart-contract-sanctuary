//SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/utils/cryptography/ECDSA.sol";

contract DepositPoolV3 is Ownable {
    using ECDSA for bytes32;
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public maxDeposit;

    address manager = 0xe066FcA44c978Fe4A5F221dfda264dDF41d3E62d;

    IERC20 public paymentToken;

    address _receiver = 0x6FeF0AA142C8aA4A6bf6A9C14217b24DcA156F08;
    uint256 public startDate;
    uint256 public closeDate;
    uint256 public paymentsReceived;
    uint256 private _divider = 10000;
    uint256 public minDeposit = 100 * 1e18;
    uint256 public goal;
    mapping(address => uint256) public nonces;

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

    function verifySig(
        uint256 amount,
        uint256 nonce,
        address account,
        bytes memory signature
    ) public view returns (bool) {
        return keccak256(abi.encodePacked(amount, nonce, account, address(this))).toEthSignedMessageHash().recover(signature) == manager;
    }

    function deposit(uint256 amount, bytes memory signature) public {
        require(saleActive(), "The sale is not active");
        require(deposits[msg.sender] + amount >= minDeposit, "You cant invest such small amount");
        require(paymentToken.balanceOf(msg.sender) >= amount, "You dont have enough funds to deposit");
        require(paymentToken.allowance(msg.sender, address(this)) >= amount, "Approve contract for spending your funds");
        require(deposits[msg.sender] + amount <= maxDeposit[msg.sender], "You cant invest such big amount");
        require(verifySig(amount, nonces[msg.sender], msg.sender, signature), "Off-chain error, probably KYC unconfirmed.");

        paymentToken.transferFrom(msg.sender, _receiver, amount);
        deposits[msg.sender] += amount;
        paymentsReceived += amount;
        nonces[msg.sender] += 1;

        emit Deposit(msg.sender, amount, deposits[msg.sender]);
    }

    function setSaleDates(uint256 _startDate, uint256 _closeDate) external onlyOwner {
        require(startDate < closeDate && startDate != 0 && closeDate != 0, "Wrong dates");
        startDate = _startDate;
        closeDate = _closeDate;
    }

    function setSaleGoal(uint256 _goal) external onlyOwner {
        goal = _goal;
    }

    function updateDepositsData(address[] calldata _investors, uint256[] calldata _amounts) external onlyOwner {
        uint256 _paymentsReceived = paymentsReceived;
        for (uint32 i = 0; i < _investors.length; i++) {
            deposits[_investors[i]] = _amounts[i];
            _paymentsReceived += _amounts[i];
        }
        paymentsReceived = _paymentsReceived;
    }

    function setPaymentToken(address _paymentToken) external onlyOwner {
        paymentToken = IERC20(_paymentToken);
    }

    function setMinDepo(uint256 _minDeposit) external onlyOwner {
        minDeposit = _minDeposit;
    }

    function extractPaymentToken(uint256 amount) external onlyOwner {
        paymentToken.transfer(msg.sender, amount);
    }

    function extractValue() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}