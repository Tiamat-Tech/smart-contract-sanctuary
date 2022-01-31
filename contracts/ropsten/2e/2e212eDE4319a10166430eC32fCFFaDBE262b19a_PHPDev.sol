/**
 * SPDX-License-Identifier: MIT
 *
 * Copyright (c) 2021-2022 PDAX
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
pragma solidity ^0.8.7;

import "./ERC20Upgradeable.sol";
import "./ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title PHPDev
 * @dev A Pausable ERC20 token with burn and mint functions.
 */
contract PHPDev is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    /**
     * @dev Initializes the contract.
     * @param _name Name of the token.
     * @param _symbol Symbol of the token.
     * @param _masterMinter The initial master minter.
     * @param _blacklister The initial blacklister.
     * @param _pauser The initial pauser.
     */
    function initialize(
        string memory _name,
        string memory _symbol,
        address _masterMinter,
        address _blacklister,
        address _pauser
    ) public initializer {
        __ERC20_init(_name, _symbol, _masterMinter, _blacklister, _pauser);
        __ERC20Burnable_init();
        __UUPSUpgradeable_init();      
    }

    function _authorizeUpgrade(address newImplementation) onlyOwner internal override {}
}