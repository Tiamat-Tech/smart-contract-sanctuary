// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import './EBlockStockACL.sol';

/// @author Blockben
/// @title EBlockStock
/// @notice EBlockStock implementation
contract EBlockStock is ERC20, EBlockStockACL {
  using SafeMath for uint256;

  constructor() ERC20('EBlockStock', 'EBSO') {}

  /**
   * Set the decimals of token to 4.
   */
  function decimals() public view virtual override returns (uint8) {
    return 4;
  }

  /**
   * @param _to Recipient address
   * @param _value Value to send to the recipient from the caller account
   */
  function transfer(address _to, uint256 _value) public override whenNotPaused returns (bool) {
    _transfer(_msgSender(), _to, _value);
    return true;
  }

  /**
   * @param _from Sender address
   * @param _to Recipient address
   * @param _value Value to send to the recipient from the sender account
   */
  function transferFrom(
    address _from,
    address _to,
    uint256 _value
  ) public override whenNotPaused returns (bool) {
    return super.transferFrom(_from, _to, _value);
  }

  /**
   * @param _spender Spender account
   * @param _value Value to approve
   */
  function approve(address _spender, uint256 _value) public override whenNotPaused returns (bool) {
    require((_value == 0) || (allowance(_msgSender(), _spender) == 0), 'Approve: zero first');
    return super.approve(_spender, _value);
  }

  /**
   * @param _spender Account that allows the spending
   * @param _addedValue Amount which will increase the total allowance
   */
  function increaseAllowance(address _spender, uint256 _addedValue) public override whenNotPaused returns (bool) {
    return super.increaseAllowance(_spender, _addedValue);
  }

  /**
   * @param _spender Account that allows the spending
   * @param _subtractValue Amount which will decrease the total allowance
   */
  function decreaseAllowance(address _spender, uint256 _subtractValue) public override whenNotPaused returns (bool) {
    return super.decreaseAllowance(_spender, _subtractValue);
  }

  /**
   * @notice Only account with TREASURY_ADMIN is able to mint!
   * @param _account Mint eBSO to this account
   * @param _amount The mintig amount
   */
  function mint(address _account, uint256 _amount) external onlyRole(TREASURY_ADMIN) whenNotPaused returns (bool) {
    _mint(_account, _amount);
    return true;
  }

  /**
   * Burn eBSO from treasury account
   * @notice Only account with TREASURY_ADMIN is able to burn!
   * @param _amount The burning amount
   */
  function burn(uint256 _amount) external onlyRole(TREASURY_ADMIN) whenNotPaused {
    require(getSourceAccountBL(treasuryAddress) == false, 'Blacklist: treasury');
    _burn(treasuryAddress, _amount);
  }

  /**
   * @param _toCashOut The receiver of the leftover eBSO
   */
  function kill(address payable _toCashOut) external onlyRole(EBSO_ADMIN) whenPaused {
    selfdestruct(_toCashOut);
  }

  /**
   * @notice Account must not be on blacklist
   * @param _account Mint eBSO to this account
   * @param _amount The minting amount
   */
  function _mint(address _account, uint256 _amount) internal override {
    require(getDestinationAccountBL(_account) == false, 'Blacklist: target');
    super._mint(_account, _amount);
  }

  /**
   * Transfer token between accounts, based on eBSO TOS.
   * - bsoFee% of the transferred amount is going to bsoPoolAddress
   * - generalFee% of the transferred amount is going to amountGeneral
   *
   * @param _sender The address from where the token sent
   * @param _recipient Recipient address
   * @param _amount The amount to be transferred
   */
  function _transfer(
    address _sender,
    address _recipient,
    uint256 _amount
  ) internal override {
    require(getSourceAccountBL(_sender) == false, 'Blacklist: sender');
    require(getDestinationAccountBL(_recipient) == false, 'Blacklist: recipient');

    if ((_sender == treasuryAddress) || (_recipient == treasuryAddress)) {
      super._transfer(_sender, _recipient, _amount);
    } else {
      require(getDestinationAccountBL(feeAddress) == false, 'Blacklist: general fee');
      require(getDestinationAccountBL(bsoPoolAddress) == false, 'Blacklist: BSO pool');

      uint256 decimalCorrection = 10000;
      uint256 generalFee256 = generalFee;
      uint256 bsoFee256 = bsoFee;
      uint256 totalFee = generalFee256.add(bsoFee256);

      uint256 amountTotal = totalFee > 0
        ? _amount.mul(totalFee).div(decimalCorrection).add(5).div(10)
        : _amount.div(decimalCorrection).add(5).div(10); // have to round anyway
      uint256 amountBso = bsoFee256 > 0
        ? _amount.mul(bsoFee256).div(decimalCorrection).add(5).div(10)
        : _amount.div(decimalCorrection).add(5).div(10); // have to round anyway
      uint256 amountGeneral = generalFee256 > 0 ? amountTotal.sub(amountBso) : 0;

      uint256 amountRest = _amount.sub(amountTotal);

      super._transfer(_sender, _recipient, amountRest);

      if (generalFee256 > 0) {
        super._transfer(_sender, feeAddress, amountGeneral);
      }

      if (bsoFee256 > 0) {
        super._transfer(_sender, bsoPoolAddress, amountBso);
      }
    }
  }
}