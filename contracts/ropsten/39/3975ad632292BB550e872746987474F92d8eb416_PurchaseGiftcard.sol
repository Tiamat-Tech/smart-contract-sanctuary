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
    string orderID;
    string voucherID;
    string fromFiatID;
    string toCryptoID;
    uint256 fiatDenomination;
    uint256 cryptoAmount;
    uint256 purchaseTime;
  }

  address public adminAddress;
  mapping(address => bool) public operators;
  mapping(address => Purchase[]) public history;
  mapping(address => bool) public tokens;

  event SetupOperator(address operatorAddress);
  event PurchaseByCurrency(
    string voucherID,
    string fromFiatID,
    string toCryptoID,
    uint256 fiatDenomination,
    uint256 cryptoAmount,
    string orderID,
    uint256 purchaseTime
  );
  event PurchaseByToken(
    string voucherID,
    string fromFiatID,
    string toCryptoID,
    uint256 fiatDenomination,
    uint256 cryptoAmount,
    string orderID,
    uint256 purchaseTime
  );
  event WithdrawCurrency(address adminAddress, uint256 currencyAmount);
  event WithdrawToken(
    address adminAddress,
    uint256 tokenAmount,
    address tokenAddress
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

  function setAdminAddress(address _adminAddress)
    external
    onlyOwner
    isValidAddress(_adminAddress)
  {
    adminAddress = _adminAddress;
  }

  // For operator
  function setupToken(address _token) external onlyOperater {
    require(!tokens[_token], "Token already setup.");

    tokens[_token] = true;
  }

  function removeToken(address _token) external onlyOperater {
    require(tokens[_token], "Token not setup yet.");

    tokens[_token] = false;
  }

  function withdrawCurrency(uint256 currencyAmount) external onlyOperater {
    require(currencyAmount > 0, "Withdraw amount invalid.");

    require(
      currencyAmount <= address(this).balance,
      "Not enough amount to withdraw."
    );

    require(adminAddress != address(0), "Invalid admin address.");

    payable(adminAddress).transfer(currencyAmount);

    emit WithdrawCurrency(adminAddress, currencyAmount);
  }

  function withdrawToken(uint256 tokenAmount, address tokenAddress)
    external
    onlyOperater
    isTokenExist(tokenAddress)
  {
    require(tokenAmount > 0, "Withdraw amount invalid.");

    require(
      tokenAmount <= IERC20(tokenAddress).balanceOf(address(this)),
      "Not enough amount to withdraw."
    );

    require(adminAddress != address(0), "Invalid admin address.");

    IERC20(tokenAddress).safeTransfer(adminAddress, tokenAmount);

    emit WithdrawToken(adminAddress, tokenAmount, tokenAddress);
  }

  // For user
  function purchaseByCurrency(
    string memory _voucherID,
    string memory _fromFiatID,
    string memory _toCryptoID,
    uint256 _fiatDenomination,
    string memory _orderID
  ) external payable {
    require(msg.value >= 0, "Transfer amount invalid.");

    require(msg.sender.balance >= msg.value, "Insufficient token balance.");

    Purchase memory purchase = Purchase({
      orderID: _orderID,
      voucherID: _voucherID,
      fromFiatID: _fromFiatID,
      toCryptoID: _toCryptoID,
      fiatDenomination: _fiatDenomination,
      cryptoAmount: msg.value,
      purchaseTime: block.timestamp
    });

    history[msg.sender].push(purchase);

    emit PurchaseByCurrency(
      _voucherID,
      _fromFiatID,
      _toCryptoID,
      _fiatDenomination,
      msg.value,
      _orderID,
      block.timestamp
    );
  }

  function purchaseByToken(
    string memory _voucherID,
    string memory _fromFiatID,
    string memory _toCryptoID,
    uint256 _fiatDenomination,
    uint256 _cryptoAmount,
    address token,
    string memory _orderID
  ) external isTokenExist(token) {
    require(_cryptoAmount >= 0, "Transfer amount invalid.");

    require(
      IERC20(token).balanceOf(msg.sender) >= _cryptoAmount,
      "Insufficient token balance."
    );

    IERC20(token).safeTransferFrom(msg.sender, address(this), _cryptoAmount);

    Purchase memory purchase = Purchase({
      orderID: _orderID,
      voucherID: _voucherID,
      fromFiatID: _fromFiatID,
      toCryptoID: _toCryptoID,
      fiatDenomination: _fiatDenomination,
      cryptoAmount: _cryptoAmount,
      purchaseTime: block.timestamp
    });

    history[msg.sender].push(purchase);

    emit PurchaseByToken(
      _voucherID,
      _fromFiatID,
      _toCryptoID,
      _fiatDenomination,
      _cryptoAmount,
      _orderID,
      block.timestamp
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