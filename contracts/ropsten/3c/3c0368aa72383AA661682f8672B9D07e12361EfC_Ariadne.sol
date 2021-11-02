// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract AFarmBridge is Ownable {
    using SafeERC20 for IERC20;

    string public networkName;
    address public immutable aFarmToken;
    address public custodian;

    bool public paused = false;

    mapping (bytes32 => bool) public unlockTransactions;

    event BridgeLock(uint256 amount);

    constructor(string memory _networkName, address _aFarmTokenAddress) {
        networkName = _networkName;
        aFarmToken = _aFarmTokenAddress;
        custodian = msg.sender;
    }

    function lockedAmount() public view returns (uint256) {
        return IERC20(aFarmToken).balanceOf(address(this));
    }

    function lock(uint256 aFarmTokenAmount) public {
        require(!paused, "paused");
        require(msg.sender == custodian, "only custodian");

        IERC20(aFarmToken).safeTransferFrom(custodian, address(this), aFarmTokenAmount);
        emit BridgeLock(aFarmTokenAmount);
    }

    function unlock(uint256 aFarmTokenAmount, bytes32 extranetTx) public onlyOwner {
        require(!unlockTransactions[extranetTx], "tx already unlocked");
        unlockTransactions[extranetTx] = true;

        IERC20(aFarmToken).safeTransfer(custodian, aFarmTokenAmount);
    }

    function setCustodian(address _custodian) public onlyOwner {
        custodian = _custodian;
    }

    function pause() public onlyOwner {
        paused = true;
    }

    function unpause() public onlyOwner {
        paused = false;
    }

    function shutdown() public onlyOwner {
        uint256 aFarmTokenLockedAmount = lockedAmount();
        if (aFarmTokenLockedAmount > 0) {
            IERC20(aFarmToken).safeTransferFrom(address(this), custodian, aFarmTokenLockedAmount);
        }

        selfdestruct(payable(custodian));
    }
}