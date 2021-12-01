// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Crowdsale.sol";
import "./AllowanceCrowdsale.sol";
import "./TimedCrowdsale.sol";

contract KeeyTokenCrowdsale is AllowanceCrowdsale, TimedCrowdsale {
    constructor(
        uint256 _rate,
        address payable _wallet,
        ERC20 _token,
        address _tokenWallet,
        uint256 _openingTime,
        uint256 _closingTime
    )Crowdsale(_rate, _wallet, _token) AllowanceCrowdsale(_tokenWallet)
    TimedCrowdsale(_openingTime,_closingTime){}

	function _preValidatePurchase(address beneficiary, uint256 weiAmount)
		internal
		view
		override(Crowdsale, TimedCrowdsale)
		onlyWhileOpen
	{
		super._preValidatePurchase(beneficiary, weiAmount);
	}

    function _deliverTokens(address beneficiary, uint256 tokenAmount)
		internal
		override(Crowdsale, AllowanceCrowdsale)
	{
		super._deliverTokens(beneficiary, tokenAmount);
	}
	
}