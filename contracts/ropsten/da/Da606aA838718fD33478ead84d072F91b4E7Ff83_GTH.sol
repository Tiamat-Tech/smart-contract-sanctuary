//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "hardhat/console.sol";

contract GTH is Ownable, ERC20PresetMinterPauser, ReentrancyGuard {
  string public constant NAME = "Gather";
  string public constant SYMBOL = "GTH";
  uint32 public constant DECIMALS = 18;
  uint256 public maxMintLimit;

  event Mint(address indexed to, uint256 amount);

  constructor()
    ERC20PresetMinterPauser(NAME, SYMBOL)
  {
    maxMintLimit = 400000000 * (10**uint256(DECIMALS));
  }

  modifier canMint() {
    require(totalSupply() < maxMintLimit, "GTH: Total supply reached max.");
    _;
  }

  function setMinter(address minter) public onlyOwner {
    require(minter != owner(), "GTH: minter can NOT be owner.");
    grantRole(MINTER_ROLE, minter);
  }

  function mint(address to, uint256 amount) public override canMint {
    require(
      totalSupply() + amount <= maxMintLimit,
      "GTH: the minter reaches max mint limit"
    );
    mint(to, amount);
    emit Mint(to, amount);
  }

  function transfer(address recipient, uint256 amount)
    public
    override
    whenNotPaused
    nonReentrant
    returns (bool)
  {
    return super.transfer(recipient, amount);
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public override whenNotPaused nonReentrant returns (bool) {
    return super.transferFrom(sender, recipient, amount);
  }
}