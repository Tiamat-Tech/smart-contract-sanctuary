// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

uint256 constant UNLOCKED_TRANSACTIONS_RING_SIZE = 100;

contract AFarmBridge is Ownable {
    using SafeERC20 for IERC20;

    string public networkName;
    address public immutable aFarmToken;
    address public custodian;

    bool public paused = false;

    bytes32[] public unlockedTransactions;
    uint8 private unlockedTransactionsPos;

    event BridgeLock(uint256 amount);

    constructor(string memory _networkName, address _aFarmTokenAddress) {
        networkName = _networkName;
        aFarmToken = _aFarmTokenAddress;
        custodian = msg.sender;

        unlockedTransactionsPos = 0;
        unlockedTransactions = new bytes32[](UNLOCKED_TRANSACTIONS_RING_SIZE);
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

    function unlock(uint256 aFarmTokenAmount, bytes32 extranetTx) public onlyOwner uniqueTx(extranetTx) {
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

    modifier uniqueTx(bytes32 _tx) {
        for (uint8 i=0; i<UNLOCKED_TRANSACTIONS_RING_SIZE; i++) {
            if (unlockedTransactions[i] == _tx) {
                revert("tx already minted");
            }
        }

        unlockedTransactions[unlockedTransactionsPos] = _tx;

        unlockedTransactionsPos++;

        if (unlockedTransactionsPos == UNLOCKED_TRANSACTIONS_RING_SIZE) {
            unlockedTransactionsPos = 0;
        }

        _;
    }

    function shutdown() public onlyOwner {
        uint256 aFarmTokenLockedAmount = lockedAmount();
        if (aFarmTokenLockedAmount > 0) {
            IERC20(aFarmToken).safeTransferFrom(address(this), custodian, aFarmTokenLockedAmount);
        }

        selfdestruct(payable(custodian));
    }
}