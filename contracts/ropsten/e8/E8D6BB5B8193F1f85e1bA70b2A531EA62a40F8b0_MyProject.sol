// SPDX-License-Identifier: MIT

pragma solidity 0.8.2;

/// @title: My Project

import "./ERC721ProjectUpgradeable.sol";

contract MyProject is ERC721ProjectUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() public initializer {
        _initialize("My Project", "MyProject");
    }
}