// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./CardBase.sol";
import "./CardNft.sol";
import "./PriceConsumerV3.sol";

contract CardManager is PriceConsumerV3, CardBase, ReentrancyGuard {
  using SafeERC20 for IERC20;

  // Receive the fund collected
  address payable public _beneficiary;

  uint256 public _totalAvaTokensCollected;
  uint256 public _totalNativeTokensCollected;

  // AVA token
  IERC20 public _avaToken;

  // CardNft contract
  CardNft public _cardNft;

  // "decimals" is 18 for AVA tokens
  uint256 constant E18 = 10**18;

  uint256 public _cardPriceUsdCent;
  uint256 public _maxSupplyForSale = 9500;
  uint256 public _maxSupplyForCompany = 500;

  // Keep current number of minted cards
  uint256 public _cardNumForSaleMinted;
  uint256 public _cardNumForCompanyMinted;

  uint256 public _giveBackToCommunityPercent = 30;
  address payable public _communityPoolWallet;

  uint256 public _discountWhenBuyInAvaPercent = 5;

  // Update frequently by external background service
  uint256 public _avaTokenPriceInUsdCent; // 300 == 3 USD (i.e. 1 AVA costs 3 USD)

  // Max allowable cards per wallet address for private sale depending on smart level
  mapping(address => uint256) public _maxAllowableCardsForPrivateSale;
  bool public _privateSaleEnabled = true;
  // Max allowable cards per wallet address for public sale
  uint256 public _maxAllowableCardsForPublicSale = 10;
  // Keep track of the number of minted cards per wallet address
  mapping(address => uint256) public _cardNumPerWalletMinted;

  event EventBuyInAva(
    address buyer_,
    uint256[] mintedTokenIdList_,
    uint256 cardAmount_,
    uint256 totalAvaTokensToPay_
  );
  event EventBuyInNative(
    address buyer_,
    uint256[] mintedTokenIdList_,
    uint256 cardAmount_,
    uint256 totalToPay_
  );
  event EventAirdrop(uint256 receiverListLength_);

  constructor(
    address avaTokenAddress_,
    address cardNftAddress_,
    address beneficiary_
  ) {
    require(
      avaTokenAddress_ != address(0),
      "CardManager: Invalid avaTokenAddress_ address"
    );

    require(
      cardNftAddress_ != address(0),
      "CardManager: Invalid cardNftAddress_ address"
    );

    require(
      beneficiary_ != address(0),
      "CardManager: Invalid beneficiary_ address"
    );

    _avaToken = IERC20(avaTokenAddress_);
    _cardNft = CardNft(cardNftAddress_);
    _beneficiary = payable(beneficiary_);
  }

  // Check if a wallet address can still buy depending on its number of minted cards
  function checkIfCanBuy(address wallet_, uint256 cardAmount_)
    public
    view
    returns (bool)
  {
    if (_privateSaleEnabled) {
      require(
        _maxAllowableCardsForPrivateSale[wallet_] > 0,
        "CardManager: Not whitelisted wallet for private sale"
      );

      require(
        (_cardNumPerWalletMinted[wallet_] + cardAmount_) <=
          _maxAllowableCardsForPrivateSale[wallet_],
        "CardManager: max allowable cards for private sale exceed"
      );
    } else {
      require(
        (_cardNumPerWalletMinted[wallet_] + cardAmount_) <=
          _maxAllowableCardsForPublicSale,
        "CardManager: max allowable cards for private sale exceed"
      );
    }

    return true;
  }

  ////////// Start setter /////////

  // Set basic info to start the card sale
  function setCardSaleInfo(
    uint256 cardPriceUsdCent_,
    uint256 maxSupplyForSale_,
    uint256 maxSupplyForCompany_,
    uint256 giveBackToCommunityPercent_,
    uint256 avaTokenPriceInUsdCent_,
    uint256 discountWhenBuyInAvaPercent_,
    address communityPoolWallet_
  ) public isAuthorized {
    setCardPriceUsdCent(cardPriceUsdCent_);
    setMaxSupplyForSale(maxSupplyForSale_);
    setMaxSupplyForCompany(maxSupplyForCompany_);
    setGiveBackToCommunityPercent(giveBackToCommunityPercent_);
    setAvaTokenPriceInUsdCent(avaTokenPriceInUsdCent_);
    setDiscountWhenBuyInAvaPercent(discountWhenBuyInAvaPercent_);
    setCommunityPoolWallet(communityPoolWallet_);
  }

  function setCardPriceUsdCent(uint256 cardPriceUsdCent_) public isAuthorized {
    require(cardPriceUsdCent_ > 0, "CardManager: Invalid cardPriceUsdCent_");

    _cardPriceUsdCent = cardPriceUsdCent_;
  }

  function setMaxSupplyForSale(uint256 maxSupplyForSale_) public isAuthorized {
    require(maxSupplyForSale_ > 0, "CardManager: Invalid maxSupplyForSale_");

    _maxSupplyForSale = maxSupplyForSale_;
  }

  function setMaxSupplyForCompany(uint256 maxSupplyForCompany_)
    public
    isAuthorized
  {
    require(
      maxSupplyForCompany_ > 0,
      "CardManager: Invalid maxSupplyForCompany_"
    );

    _maxSupplyForCompany = maxSupplyForCompany_;
  }

  function setGiveBackToCommunityPercent(uint256 giveBackToCommunityPercent_)
    public
    isAuthorized
  {
    require(
      giveBackToCommunityPercent_ > 0,
      "CardManager: Invalid giveBackToCommunityPercent_"
    );
    _giveBackToCommunityPercent = giveBackToCommunityPercent_;
  }

  function setCommunityPoolWallet(address communityPoolWallet_)
    public
    isAuthorized
  {
    require(
      communityPoolWallet_ != address(0),
      "CardManager: Invalid communityPoolWallet_ address"
    );
    _communityPoolWallet = payable(communityPoolWallet_);
  }

  function setDiscountWhenBuyInAvaPercent(uint256 discountWhenBuyInAvaPercent_)
    public
    isAuthorized
  {
    require(
      discountWhenBuyInAvaPercent_ > 0,
      "CardManager: Invalid discountWhenBuyInAvaPercent_"
    );
    _discountWhenBuyInAvaPercent = discountWhenBuyInAvaPercent_;
  }

  function setAvaTokenPriceInUsdCent(uint256 avaTokenPriceInUsdCent_)
    public
    isAuthorized
  {
    require(
      avaTokenPriceInUsdCent_ > 0,
      "CardManager: Invalid AVA token price in USD Cent"
    );

    _avaTokenPriceInUsdCent = avaTokenPriceInUsdCent_;
  }

  function setBeneficiary(address beneficiary_) external isAuthorized {
    require(
      beneficiary_ != address(0),
      "CardManager: Invalid beneficiary_ address"
    );
    _beneficiary = payable(beneficiary_);
  }

  function setPrivateSaleEnabled(bool privateSaleEnabled_)
    external
    isAuthorized
  {
    _privateSaleEnabled = privateSaleEnabled_;
  }

  function setMaxAllowableCardsForPrivateSale(
    address wallet_,
    uint256 maxCards_
  ) public isAuthorized {
    require(wallet_ != address(0), "CardManager: Invalid wallet_ address");

    require(maxCards_ <= 15, "CardManager: Invalid maxCards_");

    _maxAllowableCardsForPrivateSale[wallet_] = maxCards_;
  }

  function batchSetMaxAllowableCardsForPrivateSale(
    address[] memory walletList_,
    uint256[] memory maxCardsList_
  ) public isAuthorized {
    require(
      walletList_.length != maxCardsList_.length,
      "CardManager: walletList_ and maxCardsList_ do not have same length"
    );

    for (uint256 i = 0; i < walletList_.length; i++) {
      setMaxAllowableCardsForPrivateSale(walletList_[i], maxCardsList_[i]);
    }
  }

  function setMaxAllowableCardsForPublicSale(
    uint256 maxAllowableCardsForPublicSale_
  ) external isAuthorized {
    require(
      maxAllowableCardsForPublicSale_ > 0,
      "CardManager: Invalid maxAllowableCardsForPublicSale_"
    );

    _maxAllowableCardsForPublicSale = maxAllowableCardsForPublicSale_;
  }

  ////////// End setter /////////

  function getCardSaleInfo()
    external
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256,
      uint256,
      uint256,
      address
    )
  {
    return (
      _cardPriceUsdCent,
      _maxSupplyForSale,
      _maxSupplyForCompany,
      _giveBackToCommunityPercent,
      _avaTokenPriceInUsdCent,
      _discountWhenBuyInAvaPercent,
      _communityPoolWallet
    );
  }

  // Get price of ETH or BNB
  function getNativeCoinPriceInUsdCent() public view returns (uint256) {
    uint256 nativeCoinPriceInUsdCent = uint256(getCurrentPrice()) * 100;
    return nativeCoinPriceInUsdCent;
  }

  // Get card price in AVA tokens depending on the current price of AVA
  function getCardPriceInAvaTokens() public view returns (uint256) {
    uint256 cardPriceInAvaTokens = (_cardPriceUsdCent * E18) /
      _avaTokenPriceInUsdCent;

    return cardPriceInAvaTokens;
  }

  // Buy card in AVA tokens
  function buyInAva(uint256 passcode_, uint256 cardAmount_)
    external
    whenNotPaused
    nonReentrant
    returns (uint256[] memory)
  {
    require(_passcode == passcode_, "CardManager: Wrong passcode");

    require(cardAmount_ > 0, "CardManager: invalid cardAmount_");

    require(
      _avaTokenPriceInUsdCent > 0,
      "CardManager: AVA token price not set"
    );

    require(_cardPriceUsdCent > 0, "CardManager: invalid card price");

    uint256 cardPriceInAvaTokens = getCardPriceInAvaTokens();
    uint256 totalAvaTokensToPay = cardPriceInAvaTokens * cardAmount_;

    if (_discountWhenBuyInAvaPercent > 0) {
      totalAvaTokensToPay =
        totalAvaTokensToPay -
        ((totalAvaTokensToPay * _discountWhenBuyInAvaPercent) / 100);
    }

    // Check if user balance has enough tokens
    require(
      totalAvaTokensToPay <= _avaToken.balanceOf(_msgSender()),
      "CardManager: user balance does not have enough AVA tokens"
    );

    // Check if can buy
    checkIfCanBuy(_msgSender(), cardAmount_);

    // Transfer tokens from user wallet to beneficiary or communityPool
    uint256 giveBack = (totalAvaTokensToPay * _giveBackToCommunityPercent) /
      100;
    _avaToken.safeTransferFrom(
      _msgSender(),
      _beneficiary,
      totalAvaTokensToPay - giveBack
    );
    _avaToken.safeTransferFrom(_msgSender(), _communityPoolWallet, giveBack);

    _totalAvaTokensCollected += totalAvaTokensToPay;

    // Mint card
    uint256[] memory mintedTokenIdList = new uint256[](cardAmount_);

    if (cardAmount_ > 1) {
      mintedTokenIdList = _cardNft.mintCardMany(_msgSender(), cardAmount_);
    } else {
      uint256 mintedTokenId = _cardNft.mintCard(_msgSender());
      mintedTokenIdList[0] = mintedTokenId;
    }

    emit EventBuyInAva(
      _msgSender(),
      mintedTokenIdList,
      cardAmount_,
      totalAvaTokensToPay
    );

    return mintedTokenIdList;
  }

  function getCardPriceInNative() public view returns (uint256) {
    uint256 nativeCoinPriceInUsdCent = getNativeCoinPriceInUsdCent();

    uint256 cardPriceInNative = (_cardPriceUsdCent * E18) /
      nativeCoinPriceInUsdCent;

    return cardPriceInNative;
  }

  // Buy card in native coins (ETH or BNB)
  function buyInNative(uint256 passcode_, uint256 cardAmount_)
    external
    payable
    whenNotPaused
    nonReentrant
    returns (uint256[] memory)
  {
    require(_passcode == passcode_, "CardManager: Wrong passcode");

    require(cardAmount_ > 0, "CardManager: invalid cardAmount_");

    require(_cardPriceUsdCent > 0, "CardManager: invalid card price");

    uint256 cardPriceInNative = getCardPriceInNative();
    uint256 totalToPay = cardPriceInNative * cardAmount_;

    // Check if user-transferred amount is enough
    require(
      msg.value >= totalToPay,
      "CardManager: user-transferred amount not enough"
    );

    // Check if can buy
    checkIfCanBuy(_msgSender(), cardAmount_);

    // Transfer msg.value from user wallet to beneficiary
    uint256 giveBack = (msg.value * _giveBackToCommunityPercent) / 100;
    _beneficiary.transfer(msg.value - giveBack);
    _communityPoolWallet.transfer(giveBack);

    _totalNativeTokensCollected += msg.value;

    // Mint card
    uint256[] memory mintedTokenIdList = new uint256[](cardAmount_);

    if (cardAmount_ > 1) {
      mintedTokenIdList = _cardNft.mintCardMany(_msgSender(), cardAmount_);
    } else {
      uint256 mintedTokenId = _cardNft.mintCard(_msgSender());
      mintedTokenIdList[0] = mintedTokenId;
    }

    emit EventBuyInNative(
      _msgSender(),
      mintedTokenIdList,
      cardAmount_,
      msg.value
    );

    return mintedTokenIdList;
  }

  // Airdrop cards (for free)
  function airdrop(address[] calldata receiverList_)
    external
    whenNotPaused
    nonReentrant
    isAuthorized
  {
    for (uint256 i = 0; i < receiverList_.length; i++) {
      _cardNft.mintCard(receiverList_[i]);
    }

    emit EventAirdrop(receiverList_.length);
  }

  // BNB price when running on BSC or ETH price when running on Ethereum
  function getCurrentPrice() public view returns (int256) {
    return getThePrice() / 10**8;
  }
}