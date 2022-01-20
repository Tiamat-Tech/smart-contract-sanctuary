// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract JDAOPresaler is Context, Ownable, Pausable {
    using SafeMath for uint256;

    // Durations and timestamps are expressed in UNIX time, the same units as block.timestamp.
    uint256 private _start;
    uint256 private _duration;

    // The coin being paid
    IERC20 private _coin;

    // The token being sold
    IERC20 private _token;

    // How many token units a buyer gets per fund.
    uint256 private _rate;

    // Amount of fund raised
    uint256 private _coinsRaised;

    // Amount of token sold
    uint256 private _tokensSold;

    // Amount of token for sale
    uint256 private _tokensForSale;

    // purchased address and tokens
    address[] private _allPurchaser;
    mapping ( address => uint256) private _purchasedTokens;

    /**
     * Event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param coinAmount con paid for purchase
     * @param tokenAmount amount of tokens purchased
     */
    event TokensPurchased(address indexed purchaser, uint256 coinAmount, uint256 tokenAmount);

    constructor(uint256 rate_, IERC20 coin_, IERC20 token_)
    {
        require(rate_ > 0, "PresaleFactory: rate is 0");
        require(address(coin_) != address(0), "PresaleFactory: coin is the zero address");
        require(address(token_) != address(0), "PresaleFactory: token is the zero address");

        _start = block.timestamp;
        _duration = 72 hours;
        _rate = rate_;
        _coin = coin_;
        _token = token_;
    }

    modifier whenSaling() {
        require(isSalable(), "Saling is not allowed");
        _;
    }

    // pause and unpause buy and sell action
    function pause() external onlyOwner {
        super._pause();
    }

    function unpause() external onlyOwner {
        super._unpause();
    }

    function isSalable() public view returns (bool) {
        return block.timestamp > _start && block.timestamp <= _start.add(_duration);
    }

    /**
     * @return start time.
     */
    function start() public view returns (uint256) {
        return _start;
    }

    /**
     * @return duration time.
     */
    function duration() public view returns (uint256) {
        return _duration;
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
     * @return the number of token units a buyer gets per coin.
     */
    function rate() public view returns (uint256) {
        return _rate;
    }

    /**
     * @return the amount of coin raised.
     */
    function coinsRaised() public view returns (uint256) {
        return _coinsRaised;
    }

    /**
     * @return the amount of coin raised.
     */
    function tokensSold() public view returns (uint256) {
        return _tokensSold;
    }

    /**
     * @return the amount of tokens for sale.
     */
    function tokensForSale() public view returns (uint256) {
        return _tokensForSale;
    }

    /**
     * @return the purched address list
     */
    function purchasedAddresses() public view returns (address[] memory) {
        address[] memory returnData = new address[](_allPurchaser.length);
        for (uint i=0; i<_allPurchaser.length; i++) {
            returnData[i] = _allPurchaser[i];
        }
        return returnData;
    }

    /**
    * @return the purched token list
    */
    function purchasedTokens() public view returns (uint256[] memory) {
        uint256[] memory returnData = new uint256[](_allPurchaser.length);
        for (uint i=0; i<_allPurchaser.length; i++) {
            returnData[i] = _purchasedTokens[_allPurchaser[i]];
        }
        return returnData;
    }

    /**
     * update start
     */
    function updateStart(uint256 start_) public onlyOwner {
        _start = start_;
    }

    /**
     * update duration
     */
    function updateDuration(uint256 duration_) public onlyOwner {
        _duration = duration_;
    }

    /**
     * update rate
     */
    function updateRate(uint256 rate_) public onlyOwner {
        _rate = rate_;
    }

    /**
     * update tokens for sale
     */
    function updateTokensForSale(uint256 tokensForSale_) public onlyOwner {
        _tokensForSale = tokensForSale_;
    }

    /**
     * withdraw all coins
     */
    function withdrawAllCoins(address treasury) public onlyOwner {
        uint256 coinAmount = _coin.balanceOf(address(this));
        _coin.transfer(treasury, coinAmount);
    }

    /**
     * withdraw all tokens
     */
    function withdrawAllTokens(address treasury) public onlyOwner {
        uint256 tokenAmount = _token.balanceOf(address(this));
        _token.transfer(treasury, tokenAmount);
    }

    /**
     * @param coinAmount Value in coin involved in the purchase
     */
    function deposit(uint256 coinAmount) external whenNotPaused whenSaling {
        // calculate token amount to be created
        uint256 tokenAmount = getTokenAmount(coinAmount);

        // validate purchasing
        _preValidatePurchase(_msgSender(), coinAmount, tokenAmount);

        // transfer coin and token
        _coin.transferFrom(_msgSender(), address(this), coinAmount);
        _token.transfer(_msgSender(), tokenAmount);

        // update state
        _coinsRaised = _coinsRaised.add(coinAmount);
        _tokensSold = _tokensSold.add(tokenAmount);

        // update purchased token list
        if (_purchasedTokens[_msgSender()] == 0) {
            _allPurchaser.push(_msgSender());
        }
        _purchasedTokens[_msgSender()] = _purchasedTokens[_msgSender()] + tokenAmount;

        emit TokensPurchased(_msgSender(), coinAmount, tokenAmount);
    }

    /**
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