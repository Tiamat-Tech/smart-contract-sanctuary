// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./BaseSale.sol";

contract Presale is BaseSale {
  // Maximum mint amount per one wallet
  uint8 public maxMintPerAddress = 3;

  // wallet address => whitelisted status
  mapping(address => bool) public whitelist;
  // wallet address => minted amount
  mapping(address => uint8) public mintedAmountPerAddress;

  event LogWhitelistAdded(address indexed account);
  event LogWhitelistRemoved(address indexed account);

  constructor(address _baseNFT) BaseSale(_baseNFT) { }

  /**
   * @dev Set `maxMintPerAddress`
   * Only `owner` can call
   * `maxMintPerAddress` must not be zero
   */
  function setMaxMintPerAddress(uint8 _maxMintPerAddress) external onlyOwner {
    require(_maxMintPerAddress > 0, "Presale: MAX_MINT_INVALID");
    maxMintPerAddress = _maxMintPerAddress;
  }

  /**
   * @dev Add wallet to whitelist
   * `_account` must not be zero address
   */
  function addWhitelist(address[] memory _accounts) external onlyOwner {
    for (uint256 i = 0; i < _accounts.length; i++) {
      if (_accounts[i] != address(0) && !whitelist[_accounts[i]]) {
        whitelist[_accounts[i]] = true;

        emit LogWhitelistAdded(_accounts[i]);
      }
    }
  }

  /**
   * @dev Remove wallet from whitelist
   */
  function removeWhitelist(address[] memory _accounts) external onlyOwner {
    for (uint256 i = 0; i < _accounts.length; i++) {
      if (whitelist[_accounts[i]]) {
        whitelist[_accounts[i]] = false;

        emit LogWhitelistRemoved(_accounts[i]);
      }
    }
  }

  /**
   * @dev Purchase `_amount` of tokens
   * Any whitelisted wallet can call
   */
  function purchase(uint8 _amount) public override whenNotPaused payable {
    require(whitelist[msg.sender], "Presale: CALLER_NO_WHITELIST");
    // check if minted amount for `msg.sender` exceeds `maxMintPerAddress` limit
    uint8 _mintedAmount = mintedAmountPerAddress[msg.sender];
    require(_mintedAmount + _amount <= maxMintPerAddress, "Presale: PURCHASE_LIMIT_EXCEED");

    mintedAmountPerAddress[msg.sender] = _mintedAmount + _amount;
    _purchase(msg.sender, _amount);
  }
}