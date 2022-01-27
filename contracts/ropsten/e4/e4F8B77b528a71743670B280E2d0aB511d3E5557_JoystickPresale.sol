// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./libraries/Authorizable.sol";

contract JoystickPresale is Context, Ownable, Authorizable {
    using SafeMath for uint256;

    // Info of each coin like USDT, USDC
    struct CoinInfo {
        address addr;
        uint256 rate;
    }

    // Sale start block number and time.
    bool public SALE_FLAG;
    uint256 public START_BLOCK;
    uint256 public START_TIME;
    uint256 public SALE_DURATION;

    // Coin Info list
    mapping(uint => CoinInfo) public coinInfos;
    uint public coinInfoCount;

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

    // Events.
    event TokensPurchased(address indexed purchaser, uint256 coinAmount, uint256 tokenAmount);

    // Modifiers.
    modifier whenSale() {
        bool flag = SALE_FLAG && block.timestamp > START_TIME && block.timestamp <= START_TIME.add(SALE_DURATION);
        require(flag, "Sale isn't allowed.");
        _;
    }

    constructor()
    {
        SALE_FLAG = false;
        START_TIME = block.timestamp;
        START_BLOCK = block.number;
        SALE_DURATION = 3 days;
    }

    // start sale
    function startSale(uint256 duration) public onlyAuthorized {
        SALE_FLAG = true;
        START_TIME = block.timestamp;
        START_BLOCK = block.number;
        SALE_DURATION = duration;
    }

    // stop sale
    function stopSale() public onlyAuthorized {
        SALE_FLAG = false;
    }

    // set duration
    function setSaleDuration(uint256 duration) public onlyAuthorized {
        SALE_DURATION = duration;
    }

    // add coin info
    function addCoinInfo(address addr, uint256 rate) public onlyAuthorized {
        coinInfos[coinInfoCount] = CoinInfo(addr, rate);
        coinInfoCount++;
    }

    // set coin info
    function setCoinInfo(address addr, uint256 rate, uint8 index) public onlyAuthorized {
        coinInfos[index] = CoinInfo(addr, rate);
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
    function deposit(uint256 coinAmount) external whenSale {
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