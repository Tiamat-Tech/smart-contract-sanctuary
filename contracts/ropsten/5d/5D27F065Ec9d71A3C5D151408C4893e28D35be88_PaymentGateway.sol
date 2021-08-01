// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/escrow/Escrow.sol';
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/PullPayment.sol";

contract PaymentGateway is Ownable,PullPayment {
    address payable wallet= payable(0x6410d20dcE2E3aFd76aBf4C26077214ee8de0f5A);


    constructor()   PullPayment(){
        //wallet = _wallet;
    }

    /**
     * @dev Called by the payer to store the sent amount as credit to be pulled.
     * Funds sent in this way are stored in an intermediate {Escrow} contract, so
     * there is no danger of them being spent before withdrawal.
     *
     * @param amount The amount to transfer.
     */
    function deposit(uint256 amount) public  returns (bool) {
        _asyncTransfer(wallet, amount);
        return true;
    }

}