//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";


contract Splitter is Ownable {

    address[] public beneficiaries;
    mapping(address => uint8) public fractions; // the absolute value of these don't matter, just their relative values
    uint8 public size;

    uint8 private _sumFractions;


    constructor(address owner_) {
        transferOwnership(owner_);
    }

    function addBeneficiary(address beneficiary, uint8 fraction) external onlyOwner{
        beneficiaries.push(beneficiary);
        fractions[beneficiary] = fraction;
        _sumFractions += fraction;
        size++;
    }

    function editBeneficiaryFraction(address beneficiary, uint8 fraction) external onlyOwner {
        if (fractions[beneficiary] <= fraction) {
            _sumFractions += fraction - fractions[beneficiary];
        } else {
            _sumFractions -= fractions[beneficiary] - fraction;
        }
        fractions[beneficiary] = fraction;
    }

    receive() external payable {
        _split();
    }

    fallback() external payable {
        _split();
    }

    function _split() internal {
        uint256 bal = address(this).balance;
        for (uint i = 0; i < size; i++) {
            payable(beneficiaries[i]).transfer(bal * fractions[beneficiaries[i]] / _sumFractions);
        }
    }
}