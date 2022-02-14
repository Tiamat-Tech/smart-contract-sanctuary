//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PurchaseGiftcard is Ownable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  struct Purchase {
    string voucherID;
    string fromFiatID;
    string toCryptoID;
    address purchasedByCrypto;
    uint256 fiatDenomination;
    uint256 cryptoAmount;
  }

  address public wrapCurrency;
  mapping(address => bool) public operators;
  mapping(address => Purchase[]) public history;
  mapping(address => bool) public tokens;

  constructor(address _wrapCurrency) {
    wrapCurrency = _wrapCurrency;
    tokens[wrapCurrency] = true;
  }

  event SetupOperator(address operatorAddress);
  event PurchaseByCurrency(
    string voucherID,
    string fromFiatID,
    string toCryptoID,
    uint256 fiatDenomination,
    uint256 cryptoAmount,
    address purchaseByCrypto
  );
  event PurchaseByToken(
    string voucherID,
    string fromFiatID,
    string toCryptoID,
    uint256 fiatDenomination,
    uint256 cryptoAmount,
    address purchaseByCrypto
  );

  // For owner
  function setupOperator(address operatorAddress)
    external
    onlyOwner
    isValidAddress(operatorAddress)
  {
    require(!operators[operatorAddress], "Operator already exists.");
    operators[operatorAddress] = true;

    emit SetupOperator(operatorAddress);
  }

  // For operator
  function setupTokens(address _token) external onlyOperater {
    require(!tokens[_token], "Token already setup.");

    tokens[_token] = true;
  }

  function purchaseByCurrency(
    string memory _voucherID,
    string memory _fromFiatID,
    string memory _toCryptoID,
    uint256 _fiatDenomination
  ) external payable {
    require(msg.value >= 0, "Transfer amount invalid.");

    Purchase memory purchase = Purchase({
      voucherID: _voucherID,
      fromFiatID: _fromFiatID,
      toCryptoID: _toCryptoID,
      purchasedByCrypto: wrapCurrency,
      fiatDenomination: _fiatDenomination,
      cryptoAmount: msg.value
    });

    history[msg.sender].push(purchase);

    emit PurchaseByCurrency(
      _voucherID,
      _fromFiatID,
      _toCryptoID,
      _fiatDenomination,
      msg.value,
      wrapCurrency
    );
  }

  function purchaseByToken(
    string memory _voucherID,
    string memory _fromFiatID,
    string memory _toCryptoID,
    uint256 _fiatDenomination,
    uint256 _cryptoAmount,
    address token
  ) external isTokenExist(token) {
    require(_cryptoAmount >= 0, "Transfer amount invalid.");

    require(
      IERC20(token).balanceOf(msg.sender) >= _cryptoAmount,
      "Insufficient token balance."
    );

    IERC20(token).safeTransferFrom(msg.sender, address(this), _cryptoAmount);

    Purchase memory purchase = Purchase({
      voucherID: _voucherID,
      fromFiatID: _fromFiatID,
      toCryptoID: _toCryptoID,
      purchasedByCrypto: token,
      fiatDenomination: _fiatDenomination,
      cryptoAmount: _cryptoAmount
    });

    history[msg.sender].push(purchase);

    emit PurchaseByToken(
      _voucherID,
      _fromFiatID,
      _toCryptoID,
      _fiatDenomination,
      _cryptoAmount,
      token
    );
  }

  modifier onlyOperater() {
    require(operators[msg.sender], "You are not Operator");
    _;
  }

  modifier isValidAddress(address _address) {
    require(_address != address(0), "Invalid address.");
    _;
  }

  modifier isTokenExist(address _address) {
    require(tokens[_address] == true, "Token is not exist.");
    _;
  }
}