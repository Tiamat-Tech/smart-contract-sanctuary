// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./ChubbiAuction.sol";

/**
 * @title ChubbiAuction
 * ChubbiFren - The main contract,
 */
contract ChubbiFren is ChubbiAuction {
    constructor(
        string memory _name,
        string memory _symbol,
        address _proxyRegistryAddress
    ) ChubbiAuction(_name, _symbol, _proxyRegistryAddress, 8888) {
        setBaseTokenURI("https://api.chubbiverse.com/api/fren/");
    }
}