// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract JDAOPresaler is Context, Ownable {
    using SafeMath for uint256;

    // The coin being paid
    IERC20 private _coin;

    // The token being sold
    IERC20 private _token;

    // Address where funds are collected
    address private _wallet;

    // How many token units a buyer gets per fund.
    uint256 private _rate;

    // Amount of fund raised
    uint256 private _coinRaised;

    // purchased balances
    mapping ( address => uint256) public _purchasedBalances;

    /**
     * Event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param coinAmount con paid for purchase
     * @param tokenAmount amount of tokens purchased
     */
    event TokensPurchased(address indexed purchaser, uint256 coinAmount, uint256 tokenAmount);

    constructor(uint256 rate_, address wallet_, IERC20 coin_, IERC20 token_)
    {
        require(rate_ > 0, "PresaleFactory: rate is 0");
        require(wallet_ != address(0), "PresaleFactory: wallet is the zero address");
        require(address(coin_) != address(0), "PresaleFactory: coin is the zero address");
        require(address(token_) != address(0), "PresaleFactory: token is the zero address");

        _rate = rate_;
        _wallet = wallet_;
        _coin = coin_;
        _token = token_;
    }

    /**
     * @return the token being paid.
     */
    function coin() public view returns (IERC20) {
        return _coin;
    }

    /**
     * @return the token being sold.
     */
    function token() public view returns (IERC20) {
        return _token;
    }

    /**
     * @return the address where funds are collected.
     */
    function wallet() public view returns (address) {
        return _wallet;
    }

    /**
     * @return the number of token units a buyer gets per coin.
     */
    function rate() public view returns (uint256) {
        return _rate;
    }

    /**
     * @return the amount of coin raised.
     */
    function coinRaised() public view returns (uint256) {
        return _coinRaised;
    }

    /**
     * update wallet
     */
    function updateWallet(address wallet_) public onlyOwner {
        _wallet = wallet_;
    }

    /**
     * update rate
     */
    function updateRate(uint256 rate_) public onlyOwner {
        _rate = rate_;
    }

    /**
     * This function has a non-reentrancy guard, so it shouldn't be called by
     * another `nonReentrant` function.
     * @param coinAmount Value in coin involved in the purchase
     */
    function buyTokens(uint256 coinAmount) external {
        // calculate token amount to be created
        uint256 tokenAmount = getTokenAmount(coinAmount);

        // validate purchasing
        _preValidatePurchase(_msgSender(), coinAmount, tokenAmount);

        // transfer coin and token
        _coin.transferFrom(_msgSender(), address(this), coinAmount);
        _token.transfer(_msgSender(), tokenAmount);

        // update state
        _coinRaised = _coinRaised.add(coinAmount);

        emit TokensPurchased(_msgSender(), coinAmount, tokenAmount);
    }

    /**
     * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met.
     * Use `super` in contracts that inherit from Crowdsale to extend their validations.
     * Example from CappedCrowdsale.sol's _preValidatePurchase method:
     *     super._preValidatePurchase(purchaser, coinAmount);
     *     require(weiRaised().add(coinAmount) <= cap);
     * @param purchaser Address performing the token purchase
     * @param coinAmount Value in coin involved in the purchase
     */
    function _preValidatePurchase(address purchaser, uint256 coinAmount, uint256 tokenAmount) internal view {
        require(purchaser != address(0), "PresaleFactory: purchaser is the zero address");
        require(coinAmount != 0, "PresaleFactory: coinAmount is 0");
        require(tokenAmount != 0, "PresaleFactory: coinAmount is 0");

        require(_token.balanceOf(address(this)) >= tokenAmount, "factory's token amount is lack!");
        require(_coin.balanceOf(msg.sender) >= coinAmount, "purchaser's coin amount is lack!");

        require(_coin.allowance(msg.sender, address(this)) >= coinAmount, "purchaser's allownce is lack!");

        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
    }

    /**
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param coinAmount Value in wei to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _coinAmount
     */
    function getTokenAmount(uint256 coinAmount) public view returns (uint256) {
        return
        coinAmount
        .mul(_rate)
        .div(10**ERC20(address(_coin)).decimals())
        .mul(10**ERC20(address(_token)).decimals());
    }
}