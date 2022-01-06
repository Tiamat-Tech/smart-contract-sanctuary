// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

/// @title  The Last Word
/// @author A.Nonymous
/// @notice Allows folks to have the Last Word, for a price.
contract LastWord is Ownable, Pausable, ReentrancyGuard {
  event TheLastWordIsWritten(address author, uint256 price, uint256 contentKey);
  uint256 private _baseUnit;
  uint256 private _contentUpdatedAt;
  uint256 private _price;
  uint256 private _lastFeeBps;
  uint256 private _inflationRateBps;
  uint256 private _feesBps;
  uint256 private _contentKey;
  address private _author;
  address private _validator;
  string  private _baseContentURI;

  /// @param initialPrice_ Initializes the price for setLastWord
  /// @param inflationRateBps_ Rate in basis points to increase price from last paid to setLastWord (100 = 1% increase)
  /// @param feesBps_ The fee in basis points to add to price from last paid to setLastWord
  /// @param validator_ Address used to sign params for setLastWord, owner if 0
  /// @param author_ Address used to initialize last word author, owner if 0
  /// @param contentKey_ Initalizes content
  /// @notice Whenver setLastWord is called, the next price is calculated based on the value sent on the setLastWord call.
  /// @notice new price = value + inflation + fees.  The price is a mimimum price.  Callers of setLastWord can send any value.
  /// @notice Sending a value > than the price may be a tactic for retaining ownership. 
  constructor(
    uint256 initialPrice_,
    uint256 inflationRateBps_,
    uint256 feesBps_,
    address validator_,
    address author_,
    uint256 contentKey_,
    string memory baseContentURI_
    ) {
      _author = (author_ == address(0))
        ? msg.sender
        : author_;
      _validator = (validator_ == address(0))
        ? msg.sender
        : validator_;
      _inflationRateBps = inflationRateBps_;
      _feesBps = feesBps_;
      _price = initialPrice_;
      _lastFeeBps = feesBps_;
      _contentKey = contentKey_;
      _baseContentURI = baseContentURI_;
      _baseUnit = 10000000000000000;
      _contentUpdatedAt = block.timestamp;
  }

  function author() external view returns (address) { return _author; }
  function baseContentURI() external view returns (string memory) { return _baseContentURI; }
  function baseUnit() external view returns (uint256) { return _baseUnit; }
  function contentKey() external view returns (uint256) { return _contentKey; }
  function contentUpdatedAt() external view returns (uint256) { return _contentUpdatedAt; }
  function contentURI() external view returns (string memory) {
    return string(abi.encodePacked(_baseContentURI,Strings.toHexString(_contentKey)));
  }
  function lastFeeBps() external view returns (uint256) { return _lastFeeBps; }
  function feesBps() external view returns (uint256) { return _feesBps; }
  function fee() external view returns (uint256) {
    return (_price * _lastFeeBps / 10000);
  }
  function inflationRate() external view returns (uint256) { return _inflationRateBps; }
  function price() external view returns (uint256) { return _price; }
  function validator() external view returns (address) { return _validator; }

  // @notice Allows the owner to pause the contract, preventing calls to setLastWord
  function pause() onlyOwner external {
    _pause();
  }
  
  // @notice For unpausing the contract when paused
  function unpause() onlyOwner external {
    _unpause();
  }

  /// @param value The last value sent to setLastWord
  /// @notice Implements minimum price increase logic described above.
  function _adjustPriceForInflationAndFees(uint256 value) internal view returns(uint256) {
    uint256 tmp =  value
      + ( value * _inflationRateBps / 10000 )
      + ( value * _feesBps / 10000 );

    return ((tmp % _baseUnit) > 0)
      ? (tmp + _baseUnit - (tmp % _baseUnit))
      : tmp;
  }

  /// @param baseUnit_ used to set the minimum granularity of the values sent to setLastWord
  /// @notice The default is 10000000000000000 which would have the effect of requiring 
  /// @notice values sent to setLastWord to be set in hundredths of an Ether.
  function setBaseUnit(uint256 baseUnit_) onlyOwner external {
    require(baseUnit_ != 0, 'Cannot be zero.');
    _baseUnit = baseUnit_;
  }

  /// @param baseContentURI_ path used to form the contentURI.  Should end in '/'.
  function setBaseContentURI(string calldata baseContentURI_) onlyOwner external {
    require(bytes(baseContentURI_).length > 0, 'Cannot be an empty string.');
    _baseContentURI = baseContentURI_;
  }

  /// @param validator_ address used to validate signed parameters for setLastWord
  function setValidator(address validator_) onlyOwner external {
    require(validator_ != address(0), 'Invalid address');
    _validator = validator_;
  }

  /// @param rate_ number of basis points used to increase minimum price
  function setInflationRate(uint256 rate_) onlyOwner external {
    _inflationRateBps = rate_;
  }

  /// @param feesBps_ number of basis points for fee paid to contract owner
  function setFeesBps(uint256 feesBps_) onlyOwner external {
    _feesBps = feesBps_;
  }
  
  /// @param contentKey_ 32Byte random key pointing to a content record storing the Last Words offchain
  /// @param data_ Concatenation of the contentKey_ and msg.sender encrypted using the validator's private key
  /// @param signature_ Address recovered from signature should be equal to the validator address.
  /// @notice The original intent was to store the Last Word as a string directly in the contract, however
  /// @notice upon reflection, facilitating the ability for people to write whatever they want, directly
  /// @notice into an immutable transaction on a public record for all time seemed like something that could
  /// @notice be abused. So the actual content is stored off chain, reachable via the contentURI, a public
  /// @notice endpoint indexed to the contentKey provided to this call.  This provides a mechanism, in extreme
  /// @notice cases where content can be redacted.
  function setLastWord(uint256 contentKey_, bytes32 data_, bytes calldata signature_) 
    whenNotPaused nonReentrant external payable {
      require(msg.value >= _price, 'Insufficient funds.');
      require((msg.value % _baseUnit) == 0,
        'Value increments cannot be less than hundredth of an ether.');
      require(ECDSA.recover(data_, signature_) == _validator, 'Bad signature');
      require(keccak256(abi.encodePacked(contentKey_, msg.sender)) == data_, 'Bad data');

      address oldAuthor = _author;
      uint256 priceFee = (_price * _lastFeeBps / 10000);
      uint256 deltaFee = ((msg.value - _price) * _lastFeeBps / 10000);
      uint256 effFee = (priceFee > deltaFee) ? priceFee : deltaFee;
      uint256 newPrice = _adjustPriceForInflationAndFees(msg.value);

      _contentKey = contentKey_;
      _price = newPrice;
      _lastFeeBps = _feesBps;
      _contentUpdatedAt = block.timestamp;      
      _author = msg.sender;
      payable(oldAuthor).transfer(msg.value - effFee);
      payable(owner()).transfer(effFee);
      emit TheLastWordIsWritten(msg.sender, msg.value, contentKey_);
    }
}