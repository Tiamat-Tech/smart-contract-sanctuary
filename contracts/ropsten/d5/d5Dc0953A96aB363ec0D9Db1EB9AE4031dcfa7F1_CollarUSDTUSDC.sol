//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Collar.sol";

contract CollarUSDTUSDC is Collar {
    function address_bond() public pure override returns (address) {
        return 0x0518b2918f15D1df0cc743E72B8fAcb2881e72ca;
    }

    function address_want() public pure override returns (address) {
        return 0xA365A4aAb6DbA0e29581dCe4d8B5cFaF0338f7c4;
    }

    function address_call() public pure override returns (address) {
        return 0xb1db8a06eBCdb1AD4d81D290dA72839b0b8C34Db;
    }

    function address_coll() public pure override returns (address) {
        return 0xcB0395E0c4850695c343E75F614E38BD25bC129e;
    }

    function expiry_time() public pure override returns (uint256) {
        return 4000000000;
    }
}