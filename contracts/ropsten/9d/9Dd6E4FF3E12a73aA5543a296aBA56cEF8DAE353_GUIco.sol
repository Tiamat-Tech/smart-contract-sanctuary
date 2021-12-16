pragma solidity ^0.5.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/ownership/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/crowdsale/distribution/RefundablePostDeliveryCrowdsale.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/crowdsale/Crowdsale.sol";
//import "hardhat/console.sol";

contract GUIco is Ownable, Crowdsale, RefundablePostDeliveryCrowdsale {
    using SafeMath for uint256;

    uint256 public privateSaleICOQuantity = 400000000 * 10**9;
    uint256 public preSaleICOQuantity = 400000000 * 10**9;
    uint256 public publicSaleICOQuantity = 1000000000 * 10**9;
    uint256 constant denominator = 10**6;
    uint256 public deployTime;
    uint256 public priceAmount;
    uint256 public rateAmount;
    uint256 public newRate;
    uint256[3] oldRate;

    IERC20 private tokens;

    enum ICOStage {
        privatesaleICO,
        presaleICO,
        publicsaleICO
    }

    ICOStage public stage = ICOStage.privatesaleICO;

    constructor(
        uint256 rate_,
        address payable wallet_,
        IERC20 token_,
        uint256 openingTime_,
        uint256 closingTime_,
        uint256 goal_
    )
        public
        Crowdsale(rate_, wallet_, token_)
        TimedCrowdsale(openingTime_, closingTime_)
        RefundableCrowdsale(goal_)
    {
        deployTime = block.timestamp + 180 days;

        oldRate = [1600, 800, 80];
    }

    function changeRate(uint256 _stage, uint256 price)
        external
        onlyOwner
        returns (bool)
    {
        oldRate[_stage] = price;
        return true;
    }

    // Calculate Rate according to Stage
    function calculateRate() public view returns (uint256) {
        if (stage == ICOStage.privatesaleICO) {
            return oldRate[0];
        } else if (stage == ICOStage.presaleICO) {
            return oldRate[1];
        } else {
            return oldRate[2];
        }
    }

    function _getTokenAmount(uint256 weiAmount)
        internal
        view
        returns (uint256)
    {
        return (weiAmount.mul(calculateRate())).div(denominator);
    }

    //Set ICO Stage
    function _processPurchase(address beneficiary, uint256 tokenAmount)
        internal
    {
        //require(block.timestamp > deployTime);

        if (stage == ICOStage.privatesaleICO) {
            if (tokenAmount > privateSaleICOQuantity) {
                revert(
                    "privateSAleICO: Token Amount is more than remaining token"
                );
            }
            privateSaleICOQuantity = (privateSaleICOQuantity.sub(tokenAmount));
            if (privateSaleICOQuantity == 0) {
                stage = (ICOStage.presaleICO);
            }
        } else if (stage == ICOStage.presaleICO) {
            if (tokenAmount > preSaleICOQuantity) {
                revert("preSAleICO: Token Amount is more than remaining token");
            }
            preSaleICOQuantity = (preSaleICOQuantity.sub(tokenAmount));
            if (preSaleICOQuantity == 0) {
                stage = (ICOStage.publicsaleICO);
            }
        } else if (stage == ICOStage.publicsaleICO) {
            if (tokenAmount > publicSaleICOQuantity) {
                revert(
                    "publicSAleICO: Token Amount is more than remaining token"
                );
            }
            publicSaleICOQuantity = (publicSaleICOQuantity.sub(tokenAmount));
        }
        super._processPurchase(beneficiary, tokenAmount);
    }
}