// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./BaseSale.sol";

contract Sale is BaseSale {
  // Maximum mint amount per one transaction
  uint8 public maxMintPerTx = 3;

  constructor(address _baseNFT) BaseSale(_baseNFT) { }

  /**
   * @dev Set `maxMintPerTx`
   * Only `owner` can call
   * `maxMintPerTx` must not be zero
   */
  function setMaxMintPerTx(uint8 _maxMintPerTx) external onlyOwner {
    require(_maxMintPerTx > 0, "Sale: MAX_MINT_INVALID");
    maxMintPerTx = _maxMintPerTx;
  }

  /**
   * @dev Purchase `_amount` of tokens
   * Any wallet can call
   */
  function purchase(uint8 _amount) public override whenNotPaused payable {
    require(_amount <= maxMintPerTx, "Sale: PURCHASE_LIMIT_EXCEED");
    _purchase(msg.sender, _amount);
  }
}