// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IWhitelist.sol";
import "./MintedCrowdsale.sol";

/**
 * @title EjsCrowdsale
 * @dev Crowdsale where tokens are minted in each purchase.
 */
contract EjsCrowdsale is MintedCrowdsale {
    constructor(
        address wallet_,
        address tokenSold_,
        address[] memory paymentTokens_,
        uint256[] memory paymentDecimals_,
        uint256[] memory rates_
    ) Crowdsale(wallet_, tokenSold_, paymentTokens_, paymentDecimals_, rates_) {
        // solhint-disable-previous-line no-empty-blocks
    }
}