// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IWhitelist.sol";
import "./CappedTokenSoldCrowdsaleHelper.sol";
import "./IndividuallyCappedCrowdsaleHelper.sol";
import "./MintedCrowdsale.sol";
import "./PausableCrowdsaleHelper.sol";
import "./TimedCrowdsaleHelper.sol";
import "./WhitelistCrowdsaleHelper.sol";

/**
 * @title EjsCrowdsale
 * @dev Crowdsale where tokens are minted in each purchase.
 */
contract EjsCrowdsale is
    MintedCrowdsale,
    CappedTokenSoldCrowdsaleHelper,
    IndividuallyCappedCrowdsaleHelper,
    PausableCrowdsaleHelper,
    TimedCrowdsaleHelper,
    WhitelistCrowdsaleHelper
{
    constructor(
        address wallet_,
        address tokenSelling_,
        address[] memory paymentTokens_,
        uint256[] memory paymentDecimals_,
        uint256[] memory rates_,
        uint256 tokenCap_,
        uint256 weiCap_,
        uint256 openingTime_,
        uint256 closingTime_,
        address whitelistContract_
    )
        Crowdsale(
            wallet_,
            tokenSelling_,
            paymentTokens_,
            paymentDecimals_,
            rates_
        )
        CappedTokenSoldCrowdsaleHelper(tokenCap_)
        IndividuallyCappedCrowdsaleHelper(weiCap_)
        PausableCrowdsaleHelper()
        TimedCrowdsaleHelper(openingTime_, closingTime_)
        WhitelistCrowdsaleHelper(whitelistContract_)
    {
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @param beneficiary Token beneficiary
     * @param paymentToken ERC20 payment token address
     * @param weiAmount Amount of wei contributed
     * @param tokenAmount Number of tokens to be purchased
     */
    function _preValidatePurchase(
        address beneficiary,
        address paymentToken,
        uint256 weiAmount,
        uint256 tokenAmount
    )
        internal
        view
        override
        tokenCapNotExceeded(tokensSold, tokenAmount)
        beneficiaryCapNotExceeded(beneficiary, weiAmount)
        whenNotPaused
        onlyWhileOpen
        isWhitelisted(beneficiary)
    {
        super._preValidatePurchase(
            beneficiary,
            paymentToken,
            weiAmount,
            tokenAmount
        );
    }

    /**
     * @dev Extend parent behavior to update purchased amount of tokens by beneficiary.
     * @param beneficiary Token purchaser
     * @param paymentToken ERC20 payment token address
     * @param weiAmount Amount in wei of ERC20 payment token
     * @param tokenAmount Number of tokens to be purchased
     */
    function _updatePurchasingState(
        address beneficiary,
        address paymentToken,
        uint256 weiAmount,
        uint256 tokenAmount
    ) internal override {
        super._updatePurchasingState(
            beneficiary,
            paymentToken,
            weiAmount,
            tokenAmount
        );

        _updateBeneficiaryContribution(beneficiary, weiAmount);
    }
}