pragma solidity ^0.5.5;

import "./CopperToken.sol";
import "@openzeppelin/[email protected]/crowdsale/Crowdsale.sol";
import "@openzeppelin/[email protected]/crowdsale/emission/MintedCrowdsale.sol";
import "@openzeppelin/[email protected]/crowdsale/validation/TimedCrowdsale.sol";


// RefundablePostDeliveryCrowdsale
contract CopperSale is Crowdsale, MintedCrowdsale, TimedCrowdsale {
    constructor(
        uint rate,
        address payable wallet,
        IERC20 token,
        uint256 openingTime,
        uint256 closingTime
    ) public  Crowdsale(rate, wallet, token)
        MintedCrowdsale()
        TimedCrowdsale(openingTime, closingTime) {}
}