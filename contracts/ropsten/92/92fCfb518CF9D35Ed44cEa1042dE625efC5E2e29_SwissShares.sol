//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "./lib/EIP3009.sol";
import "./lib/EIP2612.sol";
import "./lib/EIP712.sol";
import "./lib/Admin.sol";
import "./lib/Whitelist.sol";
import "hardhat/console.sol";

contract SwissShares is ERC20Pausable, EIP2612, EIP3009, Admin, Whitelist {
  uint256 private constant MAX_AMOUNT = 10000000;
  uint256 private constant MIN_AMOUNT = 1;

  mapping(address => uint256) private _tokenHolders;
  address[] private _holders;

  constructor(uint256 initialSupply)
    ERC20("SwissShares", "SSI")
    Admin()
    Whitelist()
  {
    _mint(_msgSender(), initialSupply);

    DOMAIN_SEPARATOR = EIP712.makeDomainSeparator("SwissShares", "1");
  }

  /**
   * @dev returns the number of decimals used to get the user representation
   *
   * See {ERC20-decimals}.
   */
  function decimals() public pure override returns (uint8) {
    return 0;
  }

  /**
   * @dev Creates `amount` of new tokens and assigns them to the caller.
   *
   * See {ERC20-_mint}.
   */
  function mint(uint256 amount) public virtual onlyAdmin {
    _mint(_msgSender(), amount);
  }

  /**
   * @dev Destroys `amount` tokens from the caller.
   *
   * See {ERC20-_burn}.
   */
  function burn(uint256 amount) public virtual onlyAdmin {
    _burn(_msgSender(), amount);
  }

  /**
   * @dev Adds an `account` to Whitlisted account list
   *
   * See {Whitelist-_add}.
   */
  function addWalletToWhitelist(address account) public onlyAdmin {
    _add(account);
  }

  /**
   * @dev Removes an `account` to Whitlisted account list
   *
   * See {Whitelist-_remove}.
   */
  function removeWalletFromWhitelist(address account) public onlyAdmin {
    _remove(account);
  }

  function getAllTokenHolders()
    public
    view
    returns (address[] memory)
  {
    return _holders;
  }

  /**
   * @dev Pause all token transfers
   *
   * See {Pause-_pause}.
   */
  function pauseTransfers() public onlyAdmin {
    _pause();
  }

  /**
   * @dev Unpause all token transfers
   *
   * See {Pause-_unpause}.
   */
  function unPauseTransfers() public onlyAdmin {
    _unpause();
  }

  function freezeTransfersFromWallet(address account) public onlyAdmin {
    // Not checking for allowance as Admin will execute this function
    // when token holder's private key is lost

    // Get the total balance of the given wallet
    uint256 amount = balanceOf(account);
    _burn(account, amount);
    // Remove this wallet from the whitelist
    removeWalletFromWhitelist(account);
  }

  function find(address addr) internal view returns (uint256) {
    uint256 i = 0;
    while (_holders[i] != addr) {
      i++;
    }
    return i;
  }

  function remove(uint256 index) internal {
    require(index < _holders.length, "SwissShares: Index out of bound");
    if (index == _holders.length) {
      _holders.pop();
    } else {
      // Swap the address of removal with the last address and remove the last element
      address removalAddress = _holders[index];
      _holders[index] = _holders[_holders.length - 1];
      _holders[_holders.length - 1] = removalAddress;
      _holders.pop();
    }
  }

  /**
   * @dev Override this method in order to check some conditions before any transfer
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override {
    super._beforeTokenTransfer(from, to, amount);
    require(amount >= MIN_AMOUNT, "SwissShares: Minimum amount error");
    require(amount <= MAX_AMOUNT, "SwissShares: Maximum amount error");
    require(amount % 1 == 0, "SwissShares: Can't transfer fractional amount");
    if (from == address(0)) {
      // Mint call
      require(
        isWalletWhitelisted(to),
        "SwissShares: Receiver is not whitelisted"
      );
    } else if (to == address(0)) {
      // Burn call
      require(
        isWalletWhitelisted(from),
        "SwissShares: Sender is not whitelisted"
      );
    } else {
      require(
        isWalletWhitelisted(from),
        "SwissShares: Sender is not whitelisted"
      );
      require(
        isWalletWhitelisted(to),
        "SwissShares: Receiver is not whitelisted"
      );
    }
  }

  function _afterTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override {
    super._afterTokenTransfer(from, to, amount);

    if (_tokenHolders[to] == 0) {
      // Add the wallet to token holder list
      _holders.push(to);
    }

    if (_tokenHolders[from] != 0 && _tokenHolders[from] - amount == 0) {
      // Remove the wallet from token holder list
      uint256 index = find(from);
      remove(index);
    }
    // Update the token holdings
    if (to != address(0)) _tokenHolders[to] += amount;
    if (from != address(0)) _tokenHolders[from] -= amount;
  }

  function authTransfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal virtual override {
    _transfer(sender, recipient, amount);
  }

  function permitApprove(
    address owner,
    address spender,
    uint256 amount
  ) internal virtual override {
    _approve(owner, spender, amount);
  }
}