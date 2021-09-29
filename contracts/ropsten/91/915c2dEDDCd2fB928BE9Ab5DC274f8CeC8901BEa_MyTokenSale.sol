// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 ;
import "crowdSale.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.0.0/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.0.0/contracts/access/Ownable.sol";


contract MyTokenSale is Crowdsale, Ownable {
    using SafeMath for uint256;
    uint256 preSaleQty = 30000000;
    uint256 seedSaleQty = 50000000;
    uint256 remainingQty = 2000000;
    

//initializing tokenAvailabeto the pre preSaleSupply
    uint256 public tokenAvailabe = preSaleQty;
    //definingTheStages
    enum Stages {
        PreSaleStage,
        SeedSaleStage,
        RemainingSaleStage
    }
    
    
    // defining stage and linking it with the stages.presale
    Stages public stage = Stages.PreSaleStage;

    constructor(
        uint256 rate, 
        address payable wallet,
        ERC20 token
    ) public Crowdsale(rate, wallet, token) {}

    
    //overriding the functions of buy token as we cant override the buy token
    function _preValidatePurchase(address beneficiary, uint256 weiAmount)
        internal
        override
    {
        super._preValidatePurchase(beneficiary, weiAmount);
    }
    
    
    
    // function for getting the rate of token in token bits 
    
    function _getTokenAmount(uint256 weiAmount)
        internal
        view
        override
        returns (uint256)
    {
        return weiAmount.mul(rateOfToken());
    }
    
    

    //assume 1 eth = 3000$ approx 
    // assume decimal pts =18
    //assume rate of token in final stage = 0.03 
    
    function rateOfToken() public view returns (uint256) {
        if (stage == Stages.PreSaleStage) {
            return 3*10**5 ;
        }                   
        
        else if (stage == Stages.SeedSaleStage) {
            return 15*10**4 ;
        } 
        
        else if (stage == Stages.RemainingSaleStage) {
            return 10**5 ;
        }
        
    }

//function for the updating the remaning tokens after a purchase made
    function _processPurchase(address beneficiary, uint256 tokenAmount)
        internal
        override
    {
        require(
            tokenAmount <= tokenAvailabe * 10**18,
            "invalid request , please enter the valid Qty "
        );
        tokenAvailabe -= tokenAmount / 10**18;
        
       if (stage == Stages.PreSaleStage && tokenAvailabe == 0) {
            //changing stage from pre to seed
            stage = Stages.SeedSaleStage;
            tokenAvailabe = seedSaleQty;
        } 
        else if (stage == Stages.SeedSaleStage && tokenAvailabe == 0) {
            //changing stage from seed to remaning
            stage = Stages.RemainingSaleStage;
            tokenAvailabe = remainingQty;
        }
        
        super._processPurchase(beneficiary, tokenAmount);
    }
    

}