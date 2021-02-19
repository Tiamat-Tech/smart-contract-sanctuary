// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "../libraries/LibDiamond.sol";

contract FacetBase {
    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }
}