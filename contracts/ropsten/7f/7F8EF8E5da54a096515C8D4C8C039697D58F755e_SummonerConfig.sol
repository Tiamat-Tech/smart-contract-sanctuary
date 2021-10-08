// SPDX-License-Identifier: MIT
// @unsupported: ovm

pragma solidity ^0.6.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/introspection/ERC165Checker.sol";
import "./IMosaicNFT.sol";
import "./MosaicNFT.sol";
import "./ISummonerConfig.sol";

contract SummonerConfig is Ownable, ISummonerConfig {

    using ERC165Checker for address;

    bytes4 private constant _INTERFACE_ID_MOSAIC_NFT = type(IMosaicNFT).interfaceId;

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

    constructor() public {
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

    function isMosaicNft(address _addr) external view override returns (bool) {
        return _addr.supportsInterface(_INTERFACE_ID_MOSAIC_NFT);
    }

    function deployMosaicNft(
        address originalNftAddress,
        uint256 originalNetworkId,
        string calldata name,
        string calldata symbol
    ) external override returns (address) {
        require(msg.sender == vault, "ONLY VAULT");
        MosaicNFT mosaicNft = new MosaicNFT(originalNftAddress, originalNetworkId, name, symbol);
        return address(mosaicNft);
    }

    function mintMosaicNft(
        address mosaicNftAddress,
        address _to,
        string calldata _tokenURI,
        uint256 nftId
    ) external override {
        require(msg.sender == vault, "ONLY VAULT");
        MosaicNFT(mosaicNftAddress).mintNewNFT(_to, _tokenURI, nftId);
    }

}