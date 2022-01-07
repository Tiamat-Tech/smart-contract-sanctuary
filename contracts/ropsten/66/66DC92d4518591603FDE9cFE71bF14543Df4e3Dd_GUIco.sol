pragma solidity ^0.5.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/ownership/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/crowdsale/distribution/RefundablePostDeliveryCrowdsale.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/crowdsale/Crowdsale.sol";

contract GUIco is Ownable, Crowdsale, RefundablePostDeliveryCrowdsale {
    using SafeMath for uint256;
    uint256 public publicSaleICOQuantity = 1000000000 * 10**9;
    uint256 constant denominator = 10**9;
    uint256 currentRate;

    IERC20 private tokens;

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
        currentRate = 25;
    }

    function changeRate(uint256 price) external onlyOwner returns (bool) {
        currentRate = price;
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
        return (weiAmount.mul(currentRate)).div(denominator);
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