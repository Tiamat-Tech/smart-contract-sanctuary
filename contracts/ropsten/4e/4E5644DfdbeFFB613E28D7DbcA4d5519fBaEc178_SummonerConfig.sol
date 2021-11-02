// SPDX-License-Identifier: MIT


pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IMosaicNFT.sol";
import "./MosaicNFT.sol";
import "./ISummonerConfig.sol";

contract SummonerConfig is Ownable, ISummonerConfig {

    /// @notice check if a specific network is paused or not
    mapping(uint256 => bool) public pausedNetwork;
    uint256 transferLockupTime;

    address public vault;

    // remote network id => fee token address => fee amount
    mapping(uint256 => mapping(address => uint256)) private feeAmounts;

    event LockupTimeChanged(
        address indexed _owner,
        uint256 _oldVal,
        uint256 _newVal,
        string valType
    );

    event PauseNetwork(address admin, uint256 networkID);
    event UnpauseNetwork(address admin, uint256 networkID);

    constructor() {
        transferLockupTime = 1 days;
    }

    function setVault(address _vault) external onlyOwner {
        vault = _vault;
    }

    function setTransferLockupTime(uint256 lockupTime) external onlyOwner {
        emit LockupTimeChanged(
            msg.sender,
            transferLockupTime,
            lockupTime,
            "Transfer"
        );
        transferLockupTime = lockupTime;
    }

    function getTransferLockupTime() external view override returns (uint256) {
        return transferLockupTime;
    }

    function setFeeToken(uint256 remoteNetworkId, address _feeToken, uint256 _feeAmount) external onlyOwner {
        require(_feeAmount > 0, "AMT");
        // address(0) is special for the native token of the chain
        feeAmounts[remoteNetworkId][_feeToken] = _feeAmount;
    }

    function removeFeeToken(uint256 remoteNetworkId, address _feeToken) external onlyOwner {
        delete feeAmounts[remoteNetworkId][_feeToken];
    }

    function getFeeTokenAmount(uint256 remoteNetworkId, address feeToken) external view override returns (uint256) {
        return feeAmounts[remoteNetworkId][feeToken];
    }

    /// @notice External callable function to pause the contract
    function pauseNetwork(uint256 networkID) external onlyOwner {
        pausedNetwork[networkID] = true;
        emit PauseNetwork(msg.sender, networkID);
    }

    /// @notice External callable function to unpause the contract
    function unpauseNetwork(uint256 networkID) external onlyOwner {
        pausedNetwork[networkID] = false;
        emit UnpauseNetwork(msg.sender, networkID);
    }

    function getPausedNetwork(uint256 networkId) external view override returns (bool) {
        return pausedNetwork[networkId];
    }
}