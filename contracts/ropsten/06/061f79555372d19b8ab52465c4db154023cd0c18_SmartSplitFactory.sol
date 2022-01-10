// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "./SmartSplit.sol";

contract SmartSplitFactory is OwnableUpgradeable {
  address public smartSplit;

  event SmartSplitCreated(
    address _splitContract,
    address _owner,
    address[] _payees,
    uint256[] _shares
  );

  constructor() {
    SmartSplit _smartSplit = new SmartSplit();
    smartSplit = address(_smartSplit);
  }

  function setSmartSplit(address _smartSplit) public onlyOwner {
    require(
      _smartSplit != address(0),
      "setSmartSplit::cannot update to zero address"
    );
    smartSplit = _smartSplit;
  }

  function deploySmartSplit(
    address[] calldata _payees,
    uint256[] calldata _shares
  ) public {
    address split = ClonesUpgradeable.clone(smartSplit);
    SmartSplit(payable(split)).init(_payees, _shares);
    emit SmartSplitCreated(split, _msgSender(), _payees, _shares);
  }
}