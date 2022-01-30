pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Crowdsale.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract AngelTokenCrowdsale is Pausable, Crowdsale, Ownable {
    using SafeMath for uint256;

    IERC20 public _token; //the token being sold
    uint256 public _crowdSaleAmount; //tokens availabe for sale
    uint256 public _vestingStartTime; //vesting starting time
    uint256 public _tokensSold; //amount of tokens sold

    struct Buyer {
        uint256 amountBought;
        uint256 amountClaimed;
        uint256 buyingDate;
    }

    //store the buyers address in accordance to his personal inforamation
    mapping(address => Buyer) public claimInfo;

    //discount format(ex:for 4.2 ether you receive 2300 tokens with a rate of 500 and discount of 10% on 2000 tokens )
    struct Discounts {
        uint256 etherAmount;
        uint256 discount;
    }

    //array of discounts
    Discounts[] public discountRates;

    constructor(
        uint256 rate,
        IERC20 token,
        uint256 vestingStartTime
    ) public Crowdsale(rate, token) {
        setRate(rate);
        _token = token;
        _vestingStartTime = vestingStartTime;
    }

    //fallback function for receiving eth
    receive() external payable {
        buyTokens(_msgSender());
    }

    function getDiscountsLength() public view returns (uint256) {
        return discountRates.length;
    }

    //get crowdSaleAmount
    function get_crowdSaleAmount() public view returns (uint256) {
        return _crowdSaleAmount;
    }

    //tokens left for a buyer to claim
    function tokensToClaim(address beneficiary) public view returns (uint256) {
        return
            claimInfo[beneficiary].amountBought -
            claimInfo[beneficiary].amountClaimed;
    }

    //allow admin to add a discount
    function add_discount(uint256 etherAmount, uint256 discountPercentage)
        public
        onlyOwner
    {
        require(etherAmount > 0, "Can not discount 0 tokens.");
        require(
            discountPercentage >= 1 && discountPercentage < 10000,
            "Must be a valid discount range."
        );
        Discounts memory discount = Discounts(etherAmount, discountPercentage);
        discountRates.push(discount);
    }

    //allow admin to select a starting time for the vesting
    function set_VestingStartTime(uint256 startVestingTime) public onlyOwner {
        _vestingStartTime = startVestingTime;
    }

    //allow admin to withdraw all ETH in the contract
    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    //allow admin to manually send tokens to someone
    function grantTokens(address beneficiary, uint256 tokenAmount)
        public
        onlyOwner
    {
        claimInfo[beneficiary].amountBought += tokenAmount;
        claimInfo[beneficiary].buyingDate = block.timestamp;
    }

    //allow admin to send tokens to the contract
    function addSaleSupply(uint256 tokenAmount) public onlyOwner {
        require(tokenAmount > 0, "Can not sent negative tokens.");
        _token.transferFrom(msg.sender, address(this), tokenAmount);
        _crowdSaleAmount += tokenAmount;
    }

    //allow admin to withdraw tokens but can now go over crowdSaleAmount
    function removeSaleSupply(uint256 tokenAmount) public onlyOwner {
        require(
            tokenAmount <= _crowdSaleAmount,
            "Can not withdraw more tokens then the current amount."
        );
        _crowdSaleAmount -= tokenAmount;
        _token.transferFrom(address(this), msg.sender, tokenAmount);
    }

    // can not buy more then the crowdSaleAmount
    function _preValidatePurchase(address beneficiary, uint256 weiAmount)
        internal
        view
        override
        whenNotPaused
    {
        require(
            _tokensSold + getTokenAmount(weiAmount) <= _crowdSaleAmount,
            "The total supply has been all sold out."
        );
        super._preValidatePurchase(beneficiary, weiAmount);
    }

    function getDiscount(uint256 weiAmount) public view returns (uint256) {
        uint256 discount;

        if (discountRates.length > 0) {
            //check for discount
            for (uint256 i = discountRates.length - 1; i >= 0; i--) {
                if (weiAmount >= discountRates[i].etherAmount) {
                    if (discountRates[i].discount >= discount) {
                        discount = discountRates[i].discount;
                    }
                }
            }
        }
        return discount;
    }

    //calculate the tokens with the discount
    function getTokenAmount(uint256 weiAmount) public view returns (uint256) {
        uint256 tokens = rate().mul(weiAmount).div(10**18);

        uint256 discount = getDiscount(weiAmount);
        tokens += rate().mul(weiAmount).mul(discount).div(10**22);

        return tokens;
    }

    function buyTokens(address beneficiary) public payable nonReentrant {
        uint256 weiAmount = msg.value;
        _preValidatePurchase(beneficiary, weiAmount);

        uint256 tokens = getTokenAmount(weiAmount);

        //5% of the bought tokens to send
        uint256 tokensToSend = tokens.mul(5).div(100);

        super._processPurchase(beneficiary, tokensToSend);

        //update tokens sold
        _tokensSold += tokens;

        //complete the buyer info
        claimInfo[msg.sender].amountBought += tokens;
        claimInfo[msg.sender].buyingDate = block.timestamp;
    }

    function getClaimableTokens() public view returns (uint256) {
        uint256 currentTime = block.timestamp;
        uint256 monthsPassed = ((currentTime - _vestingStartTime).div(1 weeks))
            .div(4);

        monthsPassed = monthsPassed.sub(3);
        if (monthsPassed > 12) {
            monthsPassed = 12;
        }
        //calculate how many tokens the buyer should receive
        uint256 amountOfTokensWithdrawable = (
            claimInfo[msg.sender].amountBought.mul(monthsPassed.mul(7916))
        ).div(100000);

        //how many token he can withdraw now  --- add separte function
        uint256 amountOfTokensClaimable = amountOfTokensWithdrawable.sub(
            claimInfo[msg.sender].amountClaimed
        );

        return amountOfTokensClaimable;
    }

    function claim() public {
        require(tokensToClaim(msg.sender) > 0, "Nothing more to claim!");
        uint256 currentTime = block.timestamp;
        require(
            currentTime >= _vestingStartTime,
            "Vesting has not started yet"
        );

        //get claimable tokens
        uint256 amountOfTokensClaimable = getClaimableTokens();

        //update buyer info
        claimInfo[msg.sender].amountClaimed += amountOfTokensClaimable;

        //transfer tokens to users
        _token.transferFrom(address(this), msg.sender, amountOfTokensClaimable);
    }
}