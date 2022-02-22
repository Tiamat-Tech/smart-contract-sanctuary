// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;
import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ExchangeToken {
  ERC20 public token;

  uint256 public tokenBalance;
  uint256 public weiBalance;
  uint private rate;
  uint private rateDecimal;

  constructor(ERC20 _token, uint _rate, uint8 _rateDecimal) public {
    token = _token;
    rate = _rate;
    rateDecimal = _rateDecimal;
  }

  event Deposit(address user, uint256 value, uint256 tokenAmount, uint tokenDecimal);
  event BuyTokens(address user, uint256 value, uint256 tokenAmount);
  event SellTokens(address user, uint256 value, uint256 tokenAmount, uint tokenDecimal);

  function deposit(uint _tokenAmount, uint8 _tokenDecimals) public payable {
    uint256 tokenAmountUnit = _tokenAmount * (10 ** (uint256)(18 - _tokenDecimals));
    require(token.transferFrom(msg.sender, address(this), tokenAmountUnit));

    tokenBalance += tokenAmountUnit;
    weiBalance += msg.value;

    emit Deposit(msg.sender, msg.value, _tokenAmount, _tokenDecimals);
  }

  function getTokenPrice() public view returns (uint256) {
    return rate * (10 ** (18 - rateDecimal));
  }

  function buyTokens() public payable {
    uint256 weiAmount = msg.value;

    uint256 tokenAmount = weiAmount * rate / (10 ** rateDecimal);

    tokenBalance -= tokenAmount;
    weiBalance +=weiAmount;

    require(token.transfer(msg.sender, tokenAmount));

    uint returnweiAmount = weiAmount - (tokenAmount * (10 ** rateDecimal) / rate);
    if(returnweiAmount > 0) {
      require(msg.sender.send(returnweiAmount));
    }

    emit BuyTokens(msg.sender, msg.value, tokenAmount);
  }

  function sellTokens(uint256 _tokenAmount, uint8 _tokenDecimals) public {
    uint256 tokenAmountUnit = _tokenAmount * (10 ** (uint256)(18 - _tokenDecimals));
    require(token.transferFrom(msg.sender, address(this), tokenAmountUnit));

    uint256 weiAmount = tokenAmountUnit * (10 ** rateDecimal) / rate;

    tokenBalance += tokenAmountUnit;
    weiBalance -= weiAmount;

    msg.sender.transfer(weiAmount);

    emit SellTokens(msg.sender, weiBalance, _tokenAmount, _tokenDecimals);
  }
}