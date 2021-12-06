pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import "./MintableBurnableBep20Token.sol";

contract HODLTokenDeployer {
    mapping(address => mapping(uint256 => IERC20)) public getUserToken;
    mapping(address => uint256) public getUserTokenCount;

    address[] public tokenList;

    constructor() {}

    function createSimpleToken(
        address owner,
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 totalSupply
    ) public {
        IERC20 newToken = new SimpleBep20Token(
            owner,
            name,
            symbol,
            decimals,
            totalSupply
        );
        getUserToken[owner][++getUserTokenCount[owner]] = newToken;
        tokenList.push(address(newToken));
    }

    function createMintAndBurnToken(
        address owner,
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 totalSupply
    ) public {
        IERC20 newToken = new MintableBurnableBep20Token(
            owner,
            name,
            symbol,
            decimals,
            totalSupply
        );
        getUserToken[owner][++getUserTokenCount[owner]] = newToken;
        tokenList.push(address(newToken));
    }
}