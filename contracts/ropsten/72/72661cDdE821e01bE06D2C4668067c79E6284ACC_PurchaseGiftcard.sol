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
    address purchasedByCryptoAddress;
    uint256 fiatDenomination;
    uint256 cryptoAmount;
  }

  address public wrapCurrency;
  mapping(address => bool) public operators;
  mapping(address => Purchase[]) public history;
  mapping(address => bool) public tokens;

  event SetupOperator(address operatorAddress);
  event TopupByCurrency(
    address sender,
    string voucherID,
    string fromFiatID,
    string toCryptoID,
    uint256 fiatDenomination
  );

  function setupOperator(address operatorAddress)
    external
    onlyOwner
    isValidAddress(operatorAddress)
  {
    require(!operators[operatorAddress], "Operator already exists.");
    operators[operatorAddress] = true;

    emit SetupOperator(operatorAddress);
  }

  function topupByCurrency(
    string memory _voucherID,
    string memory _fromFiatID,
    string memory _toCryptoID,
    uint256 _fiatDenomination,
    uint256 _cryptoAmount
  ) external payable {
    require(_cryptoAmount > 0, "Amount must be greater than zero");

    require(msg.value >= _cryptoAmount, "Transfer amount invalid.");

    if (msg.value > _cryptoAmount) {
      uint256 remainCurrency = msg.value.sub(_cryptoAmount);
      payable(msg.sender).transfer(remainCurrency);
    }

    Purchase memory purchase = Purchase({
      voucherID: _voucherID,
      fromFiatID: _fromFiatID,
      toCryptoID: _toCryptoID,
      purchasedByCryptoAddress: wrapCurrency,
      fiatDenomination: _fiatDenomination,
      cryptoAmount: _cryptoAmount
    });

    history[msg.sender].push(purchase);

    emit TopupByCurrency(
      msg.sender,
      _voucherID,
      _fromFiatID,
      _toCryptoID,
      _fiatDenomination
    );
  }

  modifier onlyOperater() {
    require(operators[msg.sender], "You are not Operator");
    _;
  }

  modifier isValidAddress(address _address) {
    require(_address != address(0), "Invalid address - ZERO_ADDRESS provider.");
    _;
  }

  modifier isTokenExist(address _address) {
    require(tokens[_address] == true, "Token is not exist.");
    _;
  }
}