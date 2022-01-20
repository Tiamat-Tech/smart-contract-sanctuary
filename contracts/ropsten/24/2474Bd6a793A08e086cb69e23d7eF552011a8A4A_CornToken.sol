//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";


/**
 * @title MintedCrowdsale
 * @dev Extension of Crowdsale contract whose tokens are minted in each purchase.
 * Token ownership should be transferred to MintedCrowdsale for minting.
 */
contract CornToken is ERC20PresetMinterPauser {

    uint256 public maxSupply;

    constructor(string memory _name, string memory _symbol, uint256 _maxSupply) ERC20PresetMinterPauser(_name, _symbol) {
        maxSupply = _maxSupply * 10 ** 18;
    }

}