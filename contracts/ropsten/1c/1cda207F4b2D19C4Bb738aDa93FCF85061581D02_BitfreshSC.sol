// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BitfreshSC is Ownable {
    address private tokenAddr;
    uint256 private maxTokenWithdrawal = 0;

    event TokensReceived(string waxAddr, address userAddr, uint256 quantity);
    event EtherReceived(string waxAddr, address indexed sender, uint256 amount);
    event Received(address indexed sender, uint256 amount);
    event WithdrawalDone(address indexed financialDestinatary, uint256 amount);
    event TokensTransfered(address indexed receiver, uint256 amount);
    event EthersTransfered(address indexed receiver, uint256 amount);

    constructor(address _tokenAddr, uint256 _maxTokenWithdrawal) {
        maxTokenWithdrawal = _maxTokenWithdrawal;
        tokenAddr = _tokenAddr;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    mapping(address => bool) operatives;

    function isOperative() public view returns (bool) {
        return operatives[msg.sender] == true;
    }

    function getMaxWithdrawal() public view returns (uint256) {
        return maxTokenWithdrawal;
    }

    modifier onlyOperativeOrOwner() {
        require((owner() == msg.sender || isOperative()), "Not valid caller");
        _;
    }

    function addOperative(address _addr) public onlyOwner {
        operatives[_addr] = true;
    }

    function removeOperative(address _addr) public onlyOwner {
        require((operatives[_addr] == true), "Operative not valid");
        operatives[_addr] = false;
    }

    function destroy() public onlyOwner {
        IERC20 token = IERC20(tokenAddr);
        token.transfer(owner(), token.balanceOf(address(this)));
        selfdestruct(payable(owner()));
    }

    function transferAll(address _target) public onlyOwner {
        IERC20 token = IERC20(tokenAddr);
        uint256 allBalance = token.balanceOf(address(this));
        token.transfer(_target, allBalance);
    }

    function transfer(address _target, uint256 _qty)
        public
        onlyOperativeOrOwner()
    {
        require(_qty <= maxTokenWithdrawal, "Quantity exceeds limit");
        IERC20 token = IERC20(tokenAddr);
        token.transfer(_target, _qty);
        emit TokensTransfered(_target, _qty);
    }

    function transferEther(address payable _target, uint256 amount)
        public
        onlyOperativeOrOwner()
    {
        require(
            amount <= address(this).balance,
            "Quantity exceeds contract balance"
        );
        _target.transfer(amount);
        emit EthersTransfered(_target, amount);
    }

    function completeTokenReception(string memory _waxAddr, uint256 _tokenQty)
        public
    {
        IERC20 token = IERC20(tokenAddr);
        token.transferFrom(msg.sender, address(this), _tokenQty);
        emit TokensReceived(_waxAddr, msg.sender, _tokenQty);
    }

    function completeEtherReception(string memory _waxAddr) public payable {
        emit EtherReceived(_waxAddr, msg.sender, msg.value);
    }

    function newWithdrawalMax(uint256 _newMaxValue) public onlyOwner {
        maxTokenWithdrawal = _newMaxValue;
    }

    function withdrawFunds(uint256 amount) public onlyOperativeOrOwner {
        require(
            address(this).balance >= amount,
            "There is not enough balance to execute the transfer"
        );
        address payable payableAddress = payable(msg.sender);
        payableAddress.transfer(amount);
        emit WithdrawalDone(msg.sender, amount);
    }
}