pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import "./RewardsStaking.sol";

/// @author Max Campbell (https://github.com/maxall41), RafaCypherpunk (https://github.com/RafaCypherpunk)
contract Property is ERC1155 {
  mapping(uint256 => uint256) public pricePerShare_;
  mapping(address => uint256) public valueLocked_;
  mapping(uint256 => address) public tokenDeployers_;
  mapping(uint256 => uint256) public sellingTokens_;
  mapping(uint256 => uint256) public buyingTokens_;

  event MintProperty(uint256 id);

  constructor() ERC1155("ipfs://f0{id}") {}

  receive() external payable {
    valueLocked_[msg.sender] = valueLocked_[msg.sender] + msg.value;
  }

  function mintProperty(
    uint256 _shares,
    uint256 _pricePerShare,
    uint256 _sharesForSale,
    uint256 _id
  ) public {
    _mint(msg.sender, _id, _shares, "");
    pricePerShare_[_id] = _pricePerShare;
    tokenDeployers_[_id] = msg.sender;
    sellingTokens_[_id] = _sharesForSale;
    emit MintProperty(_id);
  }

  function getTokenOwner(uint256 _id) public view returns (address payable) {
    return payable(tokenDeployers_[_id]);
  }

  function getPricePerShare(uint256 _id) public view returns (uint256) {
    return pricePerShare_[_id];
  }

  /// @dev Used to purchase shares
  function purchaseShares(uint256 _shares, uint256 _id) public payable {
    /// @dev Get the owner of this token
    address payable owner = getTokenOwner(_id);
    /// @dev Get the price per share of this token
    uint256 _pricePerShare = getPricePerShare(_id);
    /// @dev Make sure the purchaser has enough shares
    require(msg.value >= _pricePerShare * _shares, "Not enough");
    /// @dev Make sure there are shares available for purchase
    require(sellingTokens_[_id] >= _shares, "No more shares available");
    /// @dev Charges seller for shares
    owner.transfer(_pricePerShare * _shares);
    /// @dev Transfers purchased shares to purchaser
    /// @note This will fail if the owner has no more shares they want to sell
    this.safeTransferFrom(owner, msg.sender, _id, _shares, "");
  }

  function setSellingShares(uint256 _newSharesToSell, uint256 _id) public {
    require(msg.sender == tokenDeployers_[_id], "You are not the owner");
    sellingTokens_[_id] = _newSharesToSell;
  }

  function setBuyingShares(uint256 _newSharesToSell, uint256 _id) public {
    require(msg.sender == tokenDeployers_[_id], "You are not the owner");
    buyingTokens_[_id] = _newSharesToSell;
  }

  function sellShares(uint256 shares_, uint256 _id) public {
    /// @dev Get the price per share
    uint256 _pricePerShare = getPricePerShare(_id);
    ///@dev Get the owner
    address _owner = getTokenOwner(_id);
    /// @dev Make sure the owner wants to sell these shares
    require(buyingTokens_[_id] >= shares_, "No buyback capacity");
    /// @dev Make sure the sender has enough shares
    require(
      this.balanceOf(msg.sender, _id) >= shares_,
      "Not enough shares to sell"
    );
    /// @dev Make sure the owner can afford this
    require(
      valueLocked_[_owner] >= shares_ * _pricePerShare,
      "Seller does not have enough assets"
    );
    /// @dev Charge purchaser shares
    this.safeTransferFrom(msg.sender, _owner, _id, shares_, "");
    /// @dev Send the purchaser the native token
    payable(msg.sender).transfer(shares_ * _pricePerShare);
  }

  function uint2hexstr(uint256 i) public pure returns (string memory) {
    if (i == 0) return "0";
    uint256 j = i;
    uint256 length;
    while (j != 0) {
      length++;
      j = j >> 4;
    }
    uint256 mask = 15;
    bytes memory bstr = new bytes(length);
    uint256 k = length;
    while (i != 0) {
      uint256 curr = (i & mask);
      bstr[--k] = curr > 9
        ? bytes1(uint8(55 + curr))
        : bytes1(uint8(48 + curr)); // 55 = 65 - 10
      i = i >> 4;
    }
    return string(bstr);
  }

  function uri(uint256 _tokenID) public view override returns (string memory) {
    string memory hexstringtokenID;
    hexstringtokenID = uint2hexstr(_tokenID);

    return string(abi.encodePacked("ipfs://f0", hexstringtokenID));
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