//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./utils/Pods.sol";
import "./Pod.sol";

contract ERC20Pool is Context, Ownable {

    using SafeERC20 for ERC20;
    using Pods for Pod[];

    ERC20 private immutable _poolToken;

    uint private _minimumDeposit;
    uint private _balance;

    Pod[] _pods;

    constructor(ERC20 poolToken_, uint minimumDeposit_) {
        _poolToken = poolToken_;
        _minimumDeposit = minimumDeposit_;
    }

    function _allowance(address address_) private view returns (uint) {
        return _poolToken.allowance(address_, address(this));
    }

    function _checkPodDeposit(uint amount_) private view {
        require(amount_ >= _minimumDeposit, "ERC20Pool: invalid deposit");
    }

    function addPod(string calldata podName_) onlyOwner external {
        _pods.add(podName_, _minimumDeposit);
    }

    function addPods(string[] calldata podNames_) onlyOwner external {
        _pods.addAll(podNames_, _minimumDeposit);
    }

    function allowance() external view returns (uint) {
        return _allowance(_msgSender());
    }

    function balance() external view returns (uint) {
        return _balance;
    }

    function decreaseBalance(uint amount_) onlyPod public {
        _balance -= amount_;
    }

    function deposit(uint amount_) external { // TODO: incentivize: mint booster tokens
        // amount_ >= current amount -> 1 booster
        // otherwise current amount / amount_ boosters
        _poolToken.safeTransferFrom(_msgSender(), address(this), amount_);
        _balance += amount_;
    }

    function depositIntoPods(uint amount_) external returns (uint[] memory) {
        uint i = _pods.length;
        uint perPodAmount = amount_ / i;
        _checkPodDeposit(perPodAmount);
        address sender = _msgSender();
        _poolToken.safeTransferFrom(sender, address(this), perPodAmount * i);
        uint[] memory tickets = new uint[](i);
        while (i > 0) {
            Pod pod = _pods[--i];
            tickets[i] = pod.increaseBalanceAndMintTicket(sender, perPodAmount);
        }
        return tickets;
    }

    function draw(uint random_) onlyOwner external {
        uint winningPodIndex = random_ % _pods.length;
        (uint payout, ) = prize();
        Pod winningPod = _pods[winningPodIndex];
        winningPod.draw(block.timestamp, _balance, payout);
    }

    function increaseBalance(uint amount_) onlyPod public {
        _balance += amount_;
    }

    function pods() external view returns (Pod[] memory) {
        return _pods;
    }

    function poolToken() external view returns (address) {
        return address(_poolToken);
    }

    // returns (payout, fee)
    function prize() public view returns (uint, uint) {
        uint total = _poolToken.balanceOf(address(this)) - _balance;
        uint fee = total / 100;
        return (total - fee, fee);
    }

    function transfer(address address_, uint amount_) onlyPod public {
        _poolToken.safeTransfer(address_, amount_);
    }

    function transferFrom(address address_, uint amount_) public {
        _poolToken.safeTransferFrom(address_, address(this), amount_);
    }

    function withdraw(uint amount_) onlyOwner external {
        require(amount_ <= _balance, "ERC20Pool: invalid withdrawal");
        _balance -= amount_;
        _poolToken.safeTransfer(_msgSender(), amount_);
    }

    function withdrawFromPods() external {
        uint total;
        uint i = _pods.length;
        address sender = _msgSender();
        while (i > 0) {
            total += _pods[--i].resetBalance(sender);
        }
        _poolToken.safeTransfer(sender, total);
    }

    modifier onlyPod {
        require(Pod(_msgSender()).owner() == address(this), "ERC20Pool: caller not a pool pod");
        _;
    }
}