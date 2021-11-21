// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract GenericERC20 is ERC20 {
  constructor(uint256 _initialSupply) ERC20('zeroTx-labs', 'ZTXL') {
    /// @dev _initialSupply is in units of the token, we could remove it from the constructor
    /// and set it in the constructor of the contract as a fixed value then we won't
    /// be able to mint more tokens because _mint is an internal function
    /// see: https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#ERC20-_mint-address-uint256-
    _mint(msg.sender, _initialSupply);
  }

  /// @dev  It is important to understand that decimals is only used for display purposes.
  /// All arithmetic inside the contract is still performed on integers, and it is
  /// the different user interfaces (wallets, exchanges, etc.) that must adjust
  /// the displayed values according to decimals. The total token supply and balance
  /// of each account are not specified in GLD: you need to divide by 10^decimals
  /// to get the actual GLD amount.
  /// see: https://docs.openzeppelin.com/contracts/4.x/erc20#a-note-on-decimals
  function decimals() public view virtual override returns (uint8) {
    // By default ERC20 Tokens have 18 decimals but you can override this value
    return 13;
  }

  // /// @notice Mints miner's reward
  // /// @dev We could have a function that mints the reward to the miner
  // /// see: https://docs.openzeppelin.com/contracts/4.x/erc20-supply#rewarding-miners
  // function _mintMinerReward() internal {
  //     _mint(block.coinbase, 1000);
  // }

  // /// @dev Adding to the supply mechanism from previous sections, we can use this
  // /// hook to mint a miner reward for every token transfer that is included in the blockchain.
  // /// ERC20 also allows us to extend the core functionality of the token through the _beforeTokenTransfer
  // /// hook (see Using Hooks).
  // /// see: https://docs.openzeppelin.com/contracts/4.x/extending-contracts#using-hooks
  // function _beforeTokenTransfer(address from, address to, uint256 value) internal virtual override {
  //     if (!(from == address(0) && to == block.coinbase)) {
  //       _mintMinerReward();
  //     }
  //     super._beforeTokenTransfer(from, to, value);
  // }
}