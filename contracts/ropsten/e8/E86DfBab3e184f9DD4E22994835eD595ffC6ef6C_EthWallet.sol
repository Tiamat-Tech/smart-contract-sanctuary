// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

//import "openzeppelin-solidity/contracts/access/AccessControl.sol";
import "openzeppelin-solidity/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";


contract EthWallet is ReentrancyGuard, Ownable {

    struct depSettings {
        uint128 size;
        uint128 fee;
    }

    depSettings depositInfo;

    event DepositEthMade(
        address sender,
        uint128 amount
    );

    constructor(uint128 _depositSize, uint128 _depositFee) {
        depositInfo = depSettings(_depositSize, _depositFee);
    }

    function deposit() external payable { // reentrance?
        require(msg.value == depositInfo.size + depositInfo.fee, 'EthWallet: invalid eth amount');
        emit DepositEthMade(_msgSender(), depositInfo.size); // timestamp/block?
    }

    function withdraw(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, 'EthWallet: not enough eth');
        require(amount != 0, 'EthWallet: 0 wei transfer');
        payable(owner()).transfer(amount);
    }

    function setDepositSize(uint128 newSize) external onlyOwner {
        depositInfo.size = newSize;
    }

    function setDepositFee(uint128 newFee) external onlyOwner {
        depositInfo.fee = newFee;
    }

    function setDepositInfo(uint128 _depositSize, uint128 _depositFee) external onlyOwner {
        depositInfo = depSettings(_depositSize, _depositFee);
    }
}