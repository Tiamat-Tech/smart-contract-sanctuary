pragma solidity ^0.5.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/crowdsale/distribution/RefundablePostDeliveryCrowdsale.sol";
import "@openzeppelin/contracts/crowdsale/Crowdsale.sol";

contract GUIco is Ownable, Crowdsale, RefundablePostDeliveryCrowdsale {
    using SafeMath for uint256;
    uint256 public publicSaleICOQuantity = 1000000000 * 10**9;
    uint256 constant DENOMINATOR = 10**9;
    uint256 currentRate;

    IERC20 private tokens;

    event ChangeRate(uint256 price);

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
        // currentRate = 25;
        currentRate = 40000;
    }

    function changeRate(uint256 price) external onlyOwner returns (bool) {
        currentRate = price;
        emit ChangeRate(currentRate);
        return true;
    }

    function rate() public view returns (uint256) {
        return currentRate;
    }

    function _getTokenAmount(uint256 weiAmount)
        internal
        view
        returns (uint256)
    {
        return (weiAmount.mul(currentRate)).div(DENOMINATOR);
    }

    function _processPurchase(address beneficiary, uint256 tokenAmount)
        internal
    {
        if (tokenAmount > publicSaleICOQuantity) {
            revert("publicSAleICO: Token Amount is more than remaining token");
        }
        publicSaleICOQuantity = (publicSaleICOQuantity.sub(tokenAmount));

        super._processPurchase(beneficiary, tokenAmount);
    }
}