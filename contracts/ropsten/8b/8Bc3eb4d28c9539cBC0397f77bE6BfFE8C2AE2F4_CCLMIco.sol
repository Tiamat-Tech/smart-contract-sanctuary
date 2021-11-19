pragma solidity ^0.5.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/crowdsale/distribution/RefundablePostDeliveryCrowdsale.sol";
import "@openzeppelin/contracts/crowdsale/Crowdsale.sol";

contract CCLMIco is Ownable, Crowdsale, RefundablePostDeliveryCrowdsale {
    using SafeMath for uint256;

    uint256 public privateICOQuantity = 1000000 * 10**9;
    uint256 public presaleICOQuantity = 2500000 * 10**9;
    uint256 public presaleICO1Quantity = 2500000 * 10**9;
    uint256 public presaleICO2Quantity = 4000000 * 10**9;
    uint256 public publicLaunchICOQuantity = 3000000 * 10**9;
    uint256 constant softCap = 1000000 * 10**9;
    uint256 constant denominator = 10**8;
    uint256 public constant minTokenPurchase = 1000 * 10**9;

    IERC20 private tokens;

    enum ICOStage {
        privateICO,
        presaleICO,
        presaleICO1,
        presaleICO2,
        publicLaunchICO
    }

    ICOStage public stage = ICOStage.privateICO;

    constructor(
        uint256 _rate,
        address payable _wallet,
        IERC20 _token,
        uint256 openingTime,
        uint256 closingTime,
        uint256 _goal
    )
        public
        Crowdsale(_rate, _wallet, _token)
        TimedCrowdsale(openingTime, closingTime)
        RefundableCrowdsale(_goal)
    {}

    event BuyToken(
        address beneficiary,
        uint256 tokenAmount,
        uint256 privateICOQuantity
    );

    function rate() public view returns (uint256) {
        return calculateRate();
    }

    function changeStage() public onlyOwner onlyWhileOpen {
        stage = ICOStage(uint256(ICOStage.privateICO).add(1));
        // stage = _stage + 1;
    }

    // Calculate Rate according to Stage
    function calculateRate() internal view returns (uint256) {
        if (stage == ICOStage.privateICO) {
            return 800;
        } else if (stage == ICOStage.presaleICO) {
            return 670;
        } else if (stage == ICOStage.presaleICO1) {
            return 570;
        } else if (stage == ICOStage.presaleICO2) {
            return 530;
        } else {
            return 400;
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
        require(tokenAmount >= minTokenPurchase);
        if (stage == ICOStage.privateICO) {
            if (tokenAmount > privateICOQuantity) {
                revert("Token Amount is more than remaining token");
            }
            privateICOQuantity = (privateICOQuantity.sub(tokenAmount));

            if (privateICOQuantity == 0) {
                stage = (ICOStage.presaleICO);
            }
        } else if (stage == ICOStage.presaleICO) {
            if (tokenAmount > presaleICOQuantity) {
                revert("Token Amount is more than remaining token");
            }
            presaleICOQuantity = (presaleICOQuantity.sub(tokenAmount));
            if (presaleICOQuantity == 0) {
                stage = (ICOStage.presaleICO1);
            }
        } else if (stage == ICOStage.presaleICO1) {
            if (tokenAmount > presaleICO1Quantity) {
                revert("Token Amount is more than remaining token");
            }
            presaleICO1Quantity = (presaleICO1Quantity.sub(tokenAmount));
            if (presaleICO1Quantity == 0) {
                stage = (ICOStage.presaleICO2);
            }
        } else if (stage == ICOStage.presaleICO2) {
            if (tokenAmount > presaleICO2Quantity) {
                revert("Token Amount is more than remaining token");
            }
            presaleICO2Quantity = (presaleICO2Quantity.sub(tokenAmount));
            if (presaleICO2Quantity == 0) {
                stage = (ICOStage.publicLaunchICO);
            }
        } else if (stage == ICOStage.publicLaunchICO) {
            if (tokenAmount > publicLaunchICOQuantity) {
                revert("Token Amount is more than remaining token");
            }
            publicLaunchICOQuantity = (
                publicLaunchICOQuantity.sub(tokenAmount)
            );
        }
        emit BuyToken(beneficiary, tokenAmount, privateICOQuantity);
        super._processPurchase(beneficiary, tokenAmount);
    }
}