pragma solidity ^0.5.5;

import "./CopperToken.sol";

import "@openzeppelin/contracts/crowdsale/Crowdsale.sol";
import "@openzeppelin/contracts/crowdsale/emission/MintedCrowdsale.sol";
import "@openzeppelin/contracts/crowdsale/validation/TimedCrowdsale.sol";


// RefundablePostDeliveryCrowdsale
contract CopperSale is Crowdsale, MintedCrowdsale, TimedCrowdsale {
    constructor(
        uint rate,
        address payable wallet,
        IERC20 token,
        uint256 openingTime,
        uint256 closingTime
    ) public 
        Crowdsale(rate, wallet, token)
        MintedCrowdsale()
        TimedCrowdsale(openingTime, closingTime) {}
}

contract CopperSaleDeployer {

    address public token_sale_address;
    address public token_address;
    

    constructor(
        address payable wallet
    )
        public
    {
        CopperToken token = new CopperToken("peg63.546u", "Cu", 18);
        token_address = address(token);
        
        CopperSale token_sale = new CopperSale(2000, wallet, token, now, now + 20 minutes);
        token_sale_address = address(token_sale);

        token.addMinter(token_sale_address);
        token.renounceMinter();
    }
    
}