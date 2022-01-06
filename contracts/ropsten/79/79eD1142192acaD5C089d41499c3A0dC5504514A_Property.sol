pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "./Math.sol";

/// @author Max Campbell (https://github.com/maxall41), RafaCypherpunk (https://github.com/RafaCypherpunk)
/// @dev DeFi property trading contract. That provides rewards to people who provide liqudity.
contract Property is ERC1155, ERC1155Holder, ERC1155Burnable {
  using Counters for Counters.Counter;
  /// @dev Used for math
  using ABDKMath64x64 for *;
  /// @dev Keeps track of the deployers for tokens
  mapping(uint256 => address) public tokenDeployers_;
  /// @dev The time at wich a token was minted
  mapping(uint256 => uint256) public mintTimes_;
  /// @dev URI's for tokens
  mapping(uint256 => string) private uris_;
  /// @dev Maximum INTEGER
  uint256 constant MAX_INT = 2**256 - 1;
  /// @dev Token ID => Liqudity
  mapping(uint256 => Liqudity) public liqudity_;
  /// @dev Keeps track of the providers for the liqudity of tokens
  mapping(uint256 => mapping(address => Provider[])) public providers_;
  /// @dev Total amount of providers
  uint256 public providerCount_;
  /// @dev Current accrued token fees
  uint256 public tokenFees_;
  /// @dev Current accrued native fees
  uint256 public nativeFees_;
  /// @dev The percentage of tokens that will be burned if a staking reward is withdrawn before the withdraw period end
  uint256 public cancellationBurnRate_;
  /// @dev The length of one year in seconds
  uint256 public constant ONE_YEAR = 31560000;
  /// @dev Stores data for the liqudity of a token
  struct Liqudity {
    uint256 native;
    uint256 token;
    uint256 fee;
  }
  /// @dev Stores data for a provider of a token
  struct Provider {
    uint256 nativeProvided;
    uint256 tokenProvided;
    uint256 endDate;
    address beneficiary;
  }
  /// @dev Keeps track of token Ids
  Counters.Counter public id_;
  /// @dev Called when a property is minted
  event MintProperty(uint256 id);

  /// @dev Deploy's this contract
  constructor(uint256 _cancellationBurnRate) ERC1155("ipfs://{id}") {
    cancellationBurnRate_ = _cancellationBurnRate;
  }

  /// @dev Used to get the timestamp at wich a token was minted
  function getMintTimestamp(uint256 _id) public view returns (uint256) {
    return mintTimes_[_id];
  }

  /// @dev Used to mint a property
  function mintProperty(uint256 _shares, string memory _uri) public {
    uint256 _id = id_.current();
    id_.increment();
    _mint(msg.sender, _id, _shares, "");
    tokenDeployers_[_id] = msg.sender;
    uris_[_id] = _uri;
    mintTimes_[_id] = block.timestamp;
    emit MintProperty(_id);
  }

  /// @dev Get the owner of a token
  function getTokenOwner(uint256 _id) public view returns (address payable) {
    return payable(tokenDeployers_[_id]);
  }

  /// @dev Set the URI of a token
  function setTokenURI(uint256 _id, string memory _uri) public {
    address owner = getTokenOwner(_id);
    require(msg.sender == owner, "You are not the owner");
    uris_[_id] = _uri;
  }

  /// @dev Get the URI of a token
  function uri(uint256 _tokenID) public view override returns (string memory) {
    return uris_[_tokenID];
  }

  /// @dev Remove liqudity from a token
  function removeLiquidity(
    uint256 _id,
    uint256 _tokenAmount,
    uint256 _ethAmount
  ) public {
    require(liqudity_[_id].token > 0, "Please initialize the pool first");
    address owner = getTokenOwner(_id);
    if (msg.sender == owner) {
      require(
        block.timestamp > getMintTimestamp(_id) + ONE_YEAR,
        "The owner can not remove liquidity before 1 year has past"
      );
    }
    uint256 totalTokenByProvider = calculateTotalTokenLiquidityOfAddress(
      _id,
      msg.sender
    );
    uint256 totalNativeByProvider = calculateTotalETHLiquidityOfAddress(
      _id,
      msg.sender
    );
    require(
      totalTokenByProvider >= _tokenAmount,
      "Not enough (TOKEN) to withdraw"
    );
    require(
      totalNativeByProvider >= _ethAmount,
      "Not enough (NATIVE) to withdraw"
    );
    payable(msg.sender).transfer(_ethAmount);
    _safeTransferFrom(address(this), msg.sender, _id, _tokenAmount, "");
  }

  /// @dev Get the providers created by an address
  function findProvidersFromAddress(address _address, uint256 _id)
    public
    view
    returns (Provider[] memory)
  {
    return providers_[_id][_address];
  }

  /// @dev Used to add liqudity to a token
  function addLiquidity(
    uint256 _id,
    uint256 _amount,
    uint256 _endDate
  ) public payable {
    require(liqudity_[_id].token > 0, "Please initialize the pool first");
    _safeTransferFrom(msg.sender, address(this), _id, _amount, "");
    _addLiquidity(_id, _amount, msg.value, _endDate, msg.sender);
  }

  /// @dev Internal function for adding liquidity
  function _addLiquidity(
    uint256 _id,
    uint256 _amountToken,
    uint256 _amountETH,
    uint256 _endDate,
    address sender
  ) private {
    liqudity_[_id].token = liqudity_[_id].token + _amountToken;
    liqudity_[_id].native = liqudity_[_id].native + _amountETH;
    providers_[_id][sender].push(
      Provider(_amountETH, _amountToken, _endDate, sender)
    );
    providerCount_ = providerCount_ + 1;
  }

  /// @dev Used to purchase tokens
  function purchaseTokens(uint256 _shares, uint256 _id) public payable {
    require(
      getSharePriceFromNative(_id) * _shares == msg.value,
      "Incorrect value"
    );
    require(liqudity_[_id].token >= _shares, "Insufficent Liqudity (TOKEN)");
    require(
      liqudity_[_id].native >= msg.value,
      "Insufficent Liqudity (NATIVE)"
    );
    nativeFees_ = nativeFees_ + getNativeFee(_id, _shares);
    _safeTransferFrom(address(this), msg.sender, _id, _shares, "");
    liqudity_[_id].token = liqudity_[_id].token - _shares;
    liqudity_[_id].native = liqudity_[_id].native + msg.value;
  }

  /// @dev Used to sell tokens
  function sellTokens(uint256 _shares, uint256 _id) public {
    require(
      liqudity_[_id].native >= getSharePriceFromNative(_id) * _shares,
      "Insufficent Liqudity (NATIVE)"
    );
    tokenFees_ = tokenFees_ + getTokenFee(_id, _shares);
    _safeTransferFrom(msg.sender, address(this), _id, _shares, "");
    uint256 transferAmount = (_shares * getSharePriceFromNative(_id));
    liqudity_[_id].token = liqudity_[_id].token + _shares;
    liqudity_[_id].native = liqudity_[_id].native - transferAmount;
    payable(msg.sender).transfer(transferAmount);
  }

  /// @dev Get the native fee rate
  function getNativeFee(uint256 _id, uint256 _shares)
    public
    view
    returns (uint256)
  {
    return
      ((_shares * getSharePriceFromNative(_id)) * liqudity_[_id].fee) / 1000;
  }

  /// @dev Get the token fee rate
  function getTokenFee(uint256 _id, uint256 _shares)
    public
    view
    returns (uint256)
  {
    int128 total = ABDKMath64x64.mul(
      ABDKMath64x64.fromUInt(_shares),
      getSharePriceFromToken(_id)
    );
    // Math is hard... but i think this will work as long as i have not mixed up wich ones are signed and not signed...
    return
      uint256(
        ABDKMath64x64.toUInt(
          ABDKMath64x64.divu(
            ABDKMath64x64.mulu(total, liqudity_[_id].fee),
            1000
          )
        )
      );
  }

  /// @dev Withdraw rewards for a provider
  function withdrawRewards(uint256 _id) public {
    address owner = getTokenOwner(_id);
    require(msg.sender != owner, "The owner can not get rewards");
    _withdrawRewards(_id, msg.sender);
  }

  /// @dev Handles recieving the native currency of the network
  receive() external payable {}

  /// @dev Internal function for withdrawing rewards
  function _withdrawRewards(uint256 _id, address sender) private {
    Provider[] memory providers = findProvidersFromAddress(sender, _id);
    uint256 totalNativeLiqudity = calculateTotalETHLiquidityOfToken(_id);
    uint256 totalTokenLiqudity = calculateTotalTokenLiquidityOfToken(_id);
    for (uint256 i = 0; i < providers.length; i++) {
      Provider memory provider = providers[i];
      uint256 nFee = ABDKMath64x64.mulu(
        ABDKMath64x64.divu(
          provider.nativeProvided,
          (totalNativeLiqudity - provider.nativeProvided)
        ),
        nativeFees_
      );
      uint256 tFee = ABDKMath64x64.mulu(
        ABDKMath64x64.divu(
          provider.tokenProvided,
          (totalTokenLiqudity - provider.tokenProvided)
        ),
        tokenFees_
      );
      require(tokenFees_ >= tFee, "Not enough liqudity (TOKEN)");
      require(nativeFees_ >= nFee, "Not enough liqudity (NATIVE)");
      tokenFees_ = tokenFees_ - tFee;
      nativeFees_ = nativeFees_ - nFee;
      if (block.timestamp > provider.endDate) {
        payable(sender).transfer(nFee);
        _safeTransferFrom(address(this), sender, _id, tFee, "");
      } else {
        uint256 burnRate = (tFee * cancellationBurnRate_) / 1000;
        uint256 remaining = tFee - burnRate;
        burn(address(this), _id, burnRate);
        _addLiquidity(_id, remaining, nFee, 0, address(this));
      }
    }
  }

  ///@dev Used to get the liqudity provided by a given address as providers
  function getLiqudity(uint256 _id, address _address)
    public
    view
    returns (Provider[] memory)
  {
    return providers_[_id][_address];
  }

  /// @dev Get the amount of ETH as liqudity provided to a token
  function calculateTotalETHLiquidityOfAddress(uint256 _id, address _address)
    public
    view
    returns (uint256)
  {
    Provider[] memory ethRewards = getLiqudity(_id, _address);
    uint256 total = 0;
    for (uint256 i = 0; i < ethRewards.length; i++) {
      total = total + ethRewards[i].nativeProvided;
    }
    return total;
  }

  /// @dev Get the total amount of ETH liqudity for a token
  function calculateTotalETHLiquidityOfToken(uint256 _id)
    public
    view
    returns (uint256)
  {
    return liqudity_[_id].native;
  }

  /// @dev Get the total amount of Token liqudity for a token
  function calculateTotalTokenLiquidityOfToken(uint256 _id)
    public
    view
    returns (uint256)
  {
    return liqudity_[_id].token;
  }

  /// @dev Get the amount of Token liqudity provided to a token
  function calculateTotalTokenLiquidityOfAddress(uint256 _id, address _address)
    public
    view
    returns (uint256)
  {
    Provider[] memory tokenRewards = getLiqudity(_id, _address);
    uint256 total = 0;
    for (uint256 i = 0; i < tokenRewards.length; i++) {
      total = total + tokenRewards[i].tokenProvided;
    }
    return total;
  }

  /// @dev Get the price of a single share of a property
  function getSharePriceFromNative(uint256 _id) public view returns (uint256) {
    return liqudity_[_id].native / liqudity_[_id].token;
  }

  /// @dev Do the reverse of getSharePriceFromNative
  function getSharePriceFromToken(uint256 _id) public view returns (int128) {
    int128 v = ABDKMath64x64.divu(
      //TODO: Is this right?
      liqudity_[_id].token * (10**18),
      liqudity_[_id].native
    );
    return v;
  }

  /// @dev Used to burn tokens
  function burn(
    address account,
    uint256 id,
    uint256 value
  ) public virtual override {
    require(
      account == _msgSender() ||
        isApprovedForAll(account, _msgSender()) ||
        account == address(this),
      "ERC1155: caller is not owner nor approved"
    );

    _burn(account, id, value);
  }

  /// @dev Used to initalize a liqudity pool
  function initializePool(
    uint256 _fee,
    uint256 _id,
    uint256 _amount
  ) public payable {
    _safeTransferFrom(msg.sender, address(this), _id, _amount, "");
    liqudity_[_id] = Liqudity(0, 0, _fee);
    _addLiquidity(_id, _amount, msg.value, MAX_INT, msg.sender); // This liqudity's rewards can never be withdrawn
  }

  /// @dev Allows others to figure out what this contract supports
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC1155, ERC1155Receiver)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  /// @dev Approve this contract to transfer the user's tokens by default
  function safeTransferFrom(
    address from,
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) public virtual override {
    require(
      from == _msgSender() ||
        isApprovedForAll(from, _msgSender()) ||
        _msgSender() == address(this),
      "ERC1155: caller is not owner nor approved"
    );
    _safeTransferFrom(from, to, id, amount, data);
  }
}