// SPDX-License-Identifier: UNLICENSED

// Amended by HashLips
/**
    !Disclaimer!
    These contracts have been used to create tutorials,
    and was created for the purpose to teach people
    how to create smart contracts on the blockchain.
    please review this code on your own before using any of
    the following code for production.
    HashLips will not be liable in any way if for the use 
    of the code. That being said, the code has been tested 
    to the best of the developers' knowledge to work as intended.
*/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/finance/PaymentSplitter.sol"; 

contract PAYMENTS is PaymentSplitter {

    constructor (address[] memory _payees, uint256[] memory _shares) PaymentSplitter(_payees, _shares) payable {}
}

/**
 ["0x34Ec9678feC7C567fc99087db1c08AE368b23d94", 
 "0x83B5B59D9C807d4d9aA7ab4b1fB6b9bB8916f4Ce",
]
 */
 
 /**
 [50, 
 50]
 */