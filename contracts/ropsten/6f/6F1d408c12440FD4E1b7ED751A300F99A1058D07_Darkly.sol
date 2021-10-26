//SPDX-License-Identifier: GPL-3.0
// solhint-disable-next-line compiler-fixed
pragma solidity ^0.7.0;

import "hardhat/console.sol";


contract Darkly {
    string public customer;
    address public treasury;

    // solhint-disable-next-line func-visibility
    constructor(address _treasury) {
        console.log("Deploying Darkly with treasury:", _treasury);
        treasury = _treasury;
    }

    function getCustomer() public view returns (string memory) {
        return customer;
    }

    function setCustomer(string memory _customer) public {
        console.log("Changing customer from '%s' to '%s'", customer, _customer);
        customer = _customer;
    }
}