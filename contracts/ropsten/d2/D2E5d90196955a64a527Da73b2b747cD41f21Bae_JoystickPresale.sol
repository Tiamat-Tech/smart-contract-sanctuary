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

    // Info of each Purchaser
    struct UserInfo {
        uint256 depositedAmount;       // How many Coins amount the user has deposited.
        uint256 purchasedAmount;      // How many JOY tokens the user has purchased.
        uint256 withdrawnAmount;      // Withdrawn amount
    }

    // Sale start block number and time.
    bool public SALE_FLAG;
    uint256 public START_BLOCK;
    uint256 public START_TIME;
    uint256 public SALE_DURATION;

    // Coin Info list
    mapping(uint => CoinInfo) public coinInfo;
    uint public coinInfoCount;
    // The JOY Token
    IERC20 public govToken;
    // The xJOY Token
    IERC20 public xGovToken;
    // User address => UserInfo
    mapping(address => UserInfo) public userInfo;

    // total tokens amounts
    uint256 public totalSaleAmount;
    uint256 public totalDepositedAmount;
    uint256 public totalPurchasedAmount;

    // Amount of fund raised
    uint256 private _coinsRaised;
    // Amount of token sold
    uint256 private _tokensSold;
    // Amount of token for sale
    uint256 private _tokensForSale;
    // purchased address and tokens
    address[] private _allPurchaser;
    mapping (address => uint256) private _purchasedTokens;

    // Events.
    event TokensPurchased(address indexed purchaser, uint256 coinAmount, uint256 tokenAmount);

    // Modifiers.
    modifier whenSale() {
        bool flag = SALE_FLAG && block.timestamp > START_TIME && block.timestamp <= START_TIME.add(SALE_DURATION);
        require(flag, "Sale isn't allowed.");
        _;
    }

    constructor(IERC20 _govToken, IERC20 _xGovToken, CoinInfo[] memory _coinInfo)
    {
        govToken = _govToken;
        xGovToken = _xGovToken;

        for (uint i=0; i<_coinInfo.length; i++) {
            addCoinInfo(_coinInfo[i].addr, _coinInfo[i].rate);
        }

        SALE_FLAG = true;
        START_TIME = block.timestamp;
        START_BLOCK = block.number;
        SALE_DURATION = 3 days;

        addAuthorized(_msgSender());
    }

    // Start sale
    function startSale(uint256 duration) public onlyAuthorized {
        SALE_FLAG = true;
        START_TIME = block.timestamp;
        START_BLOCK = block.number;
        SALE_DURATION = duration;
    }

    // Stop sale
    function stopSale() public onlyAuthorized {
        SALE_FLAG = false;
    }

    // Set duration
    function setSaleDuration(uint256 duration) public onlyAuthorized {
        SALE_DURATION = duration;
    }

    // Add coin info
    function addCoinInfo(address addr, uint256 rate) public onlyAuthorized {
        coinInfo[coinInfoCount] = CoinInfo(addr, rate);
        coinInfoCount++;
    }

    // Set coin info
    function setCoinInfo(address addr, uint256 rate, uint8 index) public onlyAuthorized {
        coinInfo[index] = CoinInfo(addr, rate);
    }

    // Set total sale amount
    function setTotalSaleAmount(uint256 amount) public onlyAuthorized {
        totalSaleAmount = amount;
    }

    // deposit
    function deposit(uint256 coinAmount, uint8 coinIndex) external whenSale {
        CoinInfo storage _coinInfo = coinInfo[coinIndex];
        IERC20 coin = IERC20(_coinInfo.addr);

        // calculate token amount to be created
        uint256 tokenAmount = getTokenAmount(coinAmount, coinIndex);

        // validate purchasing
        _preValidatePurchase(_msgSender(), tokenAmount, coinAmount, coinIndex);

        // transfer coin and token
        coin.transferFrom(_msgSender(), address(this), coinAmount);
        xGovToken.transfer(_msgSender(), tokenAmount);

        // // update state
        // _coinsRaised = _coinsRaised.add(coinAmount);
        // _tokensSold = _tokensSold.add(tokenAmount);

        // // update purchased token list
        // if (_purchasedTokens[_msgSender()] == 0) {
        //     _allPurchaser.push(_msgSender());
        // }
        // _purchasedTokens[_msgSender()] = _purchasedTokens[_msgSender()] + tokenAmount;

        emit TokensPurchased(_msgSender(), coinAmount, tokenAmount);
    }

    // Get token amount by coin amount
    function getTokenAmount(uint256 coinAmount, uint8 coinIndex) public view returns (uint256) {
        require( coinInfoCount >= coinIndex, "coinInfoCount >= coinIndex");

        CoinInfo storage _coinInfo = coinInfo[coinIndex];
        ERC20 coin = ERC20(_coinInfo.addr);
        uint256 rate = _coinInfo.rate;

        return
        coinAmount
        .mul(rate)
        .div(10**coin.decimals())
        .mul(10**ERC20(address(govToken)).decimals());
    }

    // Validate purchase
    function _preValidatePurchase(address purchaser, uint256 tokenAmount, uint256 coinAmount, uint8 coinIndex) internal view {
        CoinInfo storage _coinInfo = coinInfo[coinIndex];
        IERC20 coin = IERC20(_coinInfo.addr);

        require(purchaser != address(0), "purchaser is the zero address");
        require(coinAmount != 0, "coinAmount is 0");
        require(tokenAmount != 0, "tokenAmount is 0");
        require( coinInfoCount >= coinIndex, "coinInfoCount >= coinIndex");

        require(govToken.balanceOf(address(this)) >= tokenAmount, "factory's token amount is lack!");
        require(coin.balanceOf(msg.sender) >= coinAmount, "purchaser's coin amount is lack!");
        require(coin.allowance(msg.sender, address(this)) >= coinAmount, "purchaser's allownce is lack!");

        this;
    }
////////////////////////////////////////////////////////////////////////////////////////////

    // /**
    //  * @return the amount of coin raised.
    //  */
    // function coinsRaised() public view returns (uint256) {
    //     return _coinsRaised;
    // }

    // /**
    //  * @return the amount of coin raised.
    //  */
    // function tokensSold() public view returns (uint256) {
    //     return _tokensSold;
    // }

    // /**
    //  * @return the amount of tokens for sale.
    //  */
    // function tokensForSale() public view returns (uint256) {
    //     return _tokensForSale;
    // }

    // /**
    //  * @return the purched address list
    //  */
    // function purchasedAddresses() public view returns (address[] memory) {
    //     address[] memory returnData = new address[](_allPurchaser.length);
    //     for (uint i=0; i<_allPurchaser.length; i++) {
    //         returnData[i] = _allPurchaser[i];
    //     }
    //     return returnData;
    // }

    // /**
    // * @return the purched token list
    // */
    // function purchasedTokens() public view returns (uint256[] memory) {
    //     uint256[] memory returnData = new uint256[](_allPurchaser.length);
    //     for (uint i=0; i<_allPurchaser.length; i++) {
    //         returnData[i] = _purchasedTokens[_allPurchaser[i]];
    //     }
    //     return returnData;
    // }

    // /**
    //  * update tokens for sale
    //  */
    // function updateTokensForSale(uint256 tokensForSale_) public onlyOwner {
    //     _tokensForSale = tokensForSale_;
    // }

    // /**
    //  * withdraw all coins
    //  */
    // function withdrawAllCoins(address treasury) public onlyOwner {
    //     uint256 coinAmount = _coin.balanceOf(address(this));
    //     _coin.transfer(treasury, coinAmount);
    // }

    // /**
    //  * withdraw all tokens
    //  */
    // function withdrawAllTokens(address treasury) public onlyOwner {
    //     uint256 tokenAmount = _token.balanceOf(address(this));
    //     _token.transfer(treasury, tokenAmount);
    // }
}