// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";

import "./library/TANSOMath_v1.sol";


contract TANSO_v1 is Initializable, ERC20CappedUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
  using TANSOMath_v1 for uint256;

  // The list of the token holder addresses.
  address[] private _tokenHolderAddresses;

  // For tracking the list of the token holder addresses.
  struct TokenHolderProperty {
    bool isInAddressArray;
    uint256 addressArrayIndex;
  }
  mapping(address => TokenHolderProperty) private _tokenHolderProperties;

  // The basic staking manager contract's address.
  address private _basicStakingManagerAddress;

  // The fee staking manager contract's address.
  address private _feeStakingManagerAddress;

  // The percentage of "fee / price".
  uint256 private _feePerPricePercentage;

  // The percentage of "fee staking / fee".
  uint256 private _feeStakingPerFeePercentage;

  function initialize(address basicStakingManagerAddress_, address feeStakingManagerAddress_) initializer public {
    // Initilizes all the parent contracts.
    __ERC20_init("TANSO", "TNS");
    __ERC20Capped_init(1000000000 * (10 ** decimals()));
    __Ownable_init();
    __UUPSUpgradeable_init();

    // Reserves the token contract's address as the 1st one in the list of the token holder addresses.
    _appendTokenHolderAddress(address(this));
    require(_tokenHolderAddresses[0] == address(this));
    require(_tokenHolderProperties[address(this)].addressArrayIndex == 0);

    // Reserves the basic staking manager contract's address as the 2nd one in the list of the token holder addresses,
    // and then sets the basic staking manager contract's address.
    _appendTokenHolderAddress(basicStakingManagerAddress_);
    require(_tokenHolderAddresses[1] == basicStakingManagerAddress_);
    require(_tokenHolderProperties[basicStakingManagerAddress_].addressArrayIndex == 1);
    _basicStakingManagerAddress = basicStakingManagerAddress_;

    // Reserves the fee staking manager contract's address as the 3rd one in the list of the token holder addresses,
    // and then sets the fee staking manager contract's address.
    _appendTokenHolderAddress(feeStakingManagerAddress_);
    require(_tokenHolderAddresses[2] == feeStakingManagerAddress_);
    require(_tokenHolderProperties[feeStakingManagerAddress_].addressArrayIndex == 2);
    _feeStakingManagerAddress = feeStakingManagerAddress_;

    // Reserves the owner's address as the 4th one in the list of the token holder addresses,
    // and then mints the whole tokens to the owner.
    _appendTokenHolderAddress(owner());
    require(_tokenHolderAddresses[3] == owner());
    require(_tokenHolderProperties[owner()].addressArrayIndex == 3);
    _mint(owner(), cap());

    // Sets parameters regarding to the fee calculation.
    _feePerPricePercentage = 2;  // [%]
    _feeStakingPerFeePercentage = 50;  // [%]
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  // See {UUPSUpgradeable-_authorizeUpgrade}.
  function _authorizeUpgrade(address) onlyOwner internal override {}

  function transfer(address recipient, uint256 amount) public override returns (bool) {
    if (_msgSender() == owner()) {
      require(_isBalanceOfOwnerLockedUp(amount) == false, "TANSO: The owner's balace is locked up.");
    }
    _appendTokenHolderAddress(recipient);
    super.transfer(recipient, amount);
    return true;
  }

  function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
    if (sender == owner()) {
      require(_isBalanceOfOwnerLockedUp(amount) == false, "TANSO: The owner's balace is locked up.");
    }
    _appendTokenHolderAddress(recipient);
    super.transferFrom(sender, recipient, amount);
    return true;
  }
  
  function tokenHolderAddresses() external view returns (address[] memory) {
    return _tokenHolderAddresses;
  }

  function basicStakingManagerAddress() external view returns (address) {
    return _basicStakingManagerAddress;
  }

  function feeStakingManagerAddress() external view returns (address) {
    return _feeStakingManagerAddress;
  }

  function feePerPricePercentage() external view returns (uint256) {
    return _feePerPricePercentage;
  }

  function feeStakingPerFeePercentage() external view returns (uint256) {
    return _feeStakingPerFeePercentage;
  }

  function setBasicStakingManagerAddress(address basicStakingManagerAddress_) onlyOwner external {
    require(basicStakingManagerAddress_ != address(0), "TANSO: The new address must not be zero address.");
    _basicStakingManagerAddress = basicStakingManagerAddress_;
  }

  function setFeeStakingManagerAddress(address feeStakingManagerAddress_) onlyOwner external {
    require(feeStakingManagerAddress_ != address(0), "TANSO: The new address must not be zero address.");
    _feeStakingManagerAddress = feeStakingManagerAddress_;
  }

  function setFeePerPricePercentage(uint256 feePerPricePercentage_) onlyOwner external {
    require(feePerPricePercentage_ <= 100, "TANSO: The new percentage must be less than or equal to 100%.");
    _feePerPricePercentage = feePerPricePercentage_;
  }

  function setFeeStakingPerFeePercentage(uint256 feeStakingPerFeePercentage_) onlyOwner external {
    require(feeStakingPerFeePercentage_ <= 100, "TANSO: The new percentage must be less than or equal to 100%.");
    _feeStakingPerFeePercentage = feeStakingPerFeePercentage_;
  }

  function buyItem(address seller, uint256 price, address feeRecipient) external {
    require(seller != address(0), "TANSO: The seller's address must not be zero address.");
    require(price <= balanceOf(_msgSender()), "TANSO: The msg.sender's balace is insufficient.");
    require(feeRecipient != _msgSender(), "TANSO: The fee recipient's address must not be the msg.sender's address.");

    require(_feePerPricePercentage <= 100, "TANSO: The `fee / price` percentage must be less than or equal to 100%.");
    require(_feeStakingPerFeePercentage <= 100, "TANSO: The `fee staking / fee` percentage must be less than or equal to 100%.");

    bool isCalculationSuccess = false;
    uint256 feeAmount = 0;
    uint256 feeStakingAmount = 0;

    // feeAmount = price * _feePerPricePercentage / 100
    (isCalculationSuccess, feeAmount) = price.tryAmulBdivC(_feePerPricePercentage, 100);
    require(isCalculationSuccess, "TANSO: Failed to calculate the fee amount.");
    require(feeAmount <= price, "TANSO: The fee amount must be less than or equal to the item price.");

    // feeStakingAmount = feeAmount * _feeStakingPerFeePercentage / 100
    (isCalculationSuccess, feeStakingAmount) = feeAmount.tryAmulBdivC(_feeStakingPerFeePercentage, 100);
    require(isCalculationSuccess, "TANSO: Failed to calculate the fee staking amount.");
    require(feeStakingAmount <= feeAmount, "TANSO: The fee staking amount must be less than or equal to the fee amount.");

    if (0 < price - feeAmount) {
      transfer(seller, price - feeAmount);
    }
    if (0 < feeAmount - feeStakingAmount) {
      transfer(feeRecipient, feeAmount - feeStakingAmount);
    }
    if (0 < feeStakingAmount) {
      transfer(_feeStakingManagerAddress, feeStakingAmount);
    }
  }

  function _appendTokenHolderAddress(address tokenHolderAddress) private {
    if (_tokenHolderProperties[tokenHolderAddress].isInAddressArray == false) {
      _tokenHolderProperties[tokenHolderAddress].isInAddressArray = true;
      _tokenHolderProperties[tokenHolderAddress].addressArrayIndex = _tokenHolderAddresses.length;
      _tokenHolderAddresses.push(tokenHolderAddress);
    }
  }

  function _isBalanceOfOwnerLockedUp(uint256 amount) private view returns (bool) {
    require(amount <= balanceOf(owner()), "TANSO: The owner's balace is insufficient.");

    uint256 lockUpTimestamp1 = 1672531200;  // [s] Unix timestamp: Jan. 1st 2023 00:00:00 UTC
    uint256 lockUpAmount1 = 300000000 * (10 ** decimals());  // 30% of the token cap.

    uint256 lockUpTimestamp2 = 1704067200;  // [s] Unix timestamp: Jan. 1st 2024 00:00:00 UTC
    uint256 lockUpAmount2 = 250000000 * (10 ** decimals());  // 25% of the token cap.

    uint256 lockUpTimestamp3 = 1735689600;  // [s] Unix timestamp: Jan. 1st 2025 00:00:00 UTC
    uint256 lockUpAmount3 = 200000000 * (10 ** decimals());  // 20% of the token cap.

    uint256 lockUpTimestamp4 = 1767225600;  // [s] Unix timestamp: Jan. 1st 2026 00:00:00 UTC
    uint256 lockUpAmount4 = 150000000 * (10 ** decimals());  // 15% of the token cap.

    uint256 lockUpTimestamp5 = 1798761600;  // [s] Unix timestamp: Jan. 1st 2027 00:00:00 UTC
    uint256 lockUpAmount5 = 100000000 * (10 ** decimals());  // 10% of the token cap.

    uint256 lockUpTimestamp6 = 1830297600;  // [s] Unix timestamp: Jan. 1st 2028 00:00:00 UTC
    uint256 lockUpAmount6 = 50000000 * (10 ** decimals());  // 5% of the token cap.

    uint256 ownerBalanceAfterTransfer = balanceOf(owner()) - amount;
    if (block.timestamp <= lockUpTimestamp1) {
      return (ownerBalanceAfterTransfer < lockUpAmount1);
    } else if (lockUpTimestamp1 < block.timestamp && block.timestamp <= lockUpTimestamp2) {
      return (ownerBalanceAfterTransfer < lockUpAmount2);
    } else if (lockUpTimestamp2 < block.timestamp && block.timestamp <= lockUpTimestamp3) {
      return (ownerBalanceAfterTransfer < lockUpAmount3);
    } else if (lockUpTimestamp3 < block.timestamp && block.timestamp <= lockUpTimestamp4) {
      return (ownerBalanceAfterTransfer < lockUpAmount4);
    } else if (lockUpTimestamp4 < block.timestamp && block.timestamp <= lockUpTimestamp5) {
      return (ownerBalanceAfterTransfer < lockUpAmount5);
    } else if (lockUpTimestamp5 < block.timestamp && block.timestamp <= lockUpTimestamp6) {
      return (ownerBalanceAfterTransfer < lockUpAmount6);
    }

    // If the current timestamp is after Jan. 1st 2028 00:00:00 UTC, then there is no lock up anymore.
    return false;
  }
}