// SPDX-License-Identifier: MIT


pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "./IMosaicNFT.sol";
import "./ISummonerConfig.sol";

// @title: Composable Finance L2 ERC721 Vault
contract Summoner is
IERC721ReceiverUpgradeable,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable
{

    struct Fee {
        address tokenAddress;
        uint256 amount;
    }

    ISummonerConfig public config;
    address public mosaicNftAddress;
    address public relayer;

    uint256 nonce;

    uint256[] private preMints;

    mapping(address => uint256) public lastTransfer;
    mapping(bytes32 => bool) public hasBeenSummoned; //hasBeenWithdrawn
    mapping(bytes32 => bool) public hasBeenReleased; //hasBeenUnlocked
    bytes32 public lastSummonedID; //lastWithdrawnID
    bytes32 public lastReleasedID; //lastUnlockedID

    // stores the fee collected by the contract against a transfer id
    mapping(bytes32 => Fee) private feeCollection;

    event TransferInitiated(
        address indexed sourceNftOwner,
        address indexed sourceNftAddress,
        uint256 indexed sourceNFTId,
        address destinationAddress,
        uint256 destinationNetworkID,
        address originalNftAddress,
        uint256 originalNetworkID,
        uint256 originalNftId,
        uint256 transferDelay,
        bool isRelease,
        bytes32 id
    );

    event SealReleased(
        address indexed nftOwner,
        address indexed nftContract,
        uint256 indexed nftId,
        bytes32 id
    );

    event SummonCompleted(
        address indexed nftOwner,
        address indexed destinationNftContract,
        string nftUri,
        bytes32 id
    );

    event FeeTaken(
        address indexed owner,
        address indexed nftAddress,
        uint256 indexed nftId,
        bytes32 id,
        uint256 remoteNetworkId,
        address feeToken,
        uint256 feeAmount
    );

    event FeeRefunded(
        address indexed owner,
        address indexed nftAddress,
        uint256 indexed nftId,
        bytes32 id,
        address feeToken,
        uint256 feeAmount
    );

    function initialize(address _config) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        nonce = 0;
        config = ISummonerConfig(_config);
    }

    function setConfig(address _config) external onlyOwner {
        config = ISummonerConfig(_config);
    }

    function setMosaicNft(address _mosaicNftAddress) external onlyOwner {
        mosaicNftAddress = _mosaicNftAddress;
    }

    function setRelayer(address _relayer) external onlyOwner {
        relayer = _relayer;
    }

    /// @notice External callable function to pause the contract
    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    /// @notice External callable function to unpause the contract
    function unpause() external whenPaused onlyOwner {
        _unpause();
    }

    function transferERC721ToLayer(
        address sourceNFTAddress,
        uint256 sourceNFTId,
        address destinationAddress,
        uint256 destinationNetworkID,
        uint256 transferDelay,
        address feeToken
    )
    external
    payable
    nonReentrant
    {
        require(mosaicNftAddress != address(0), "MOSAIC NFT NOT SET");
        require(sourceNFTAddress != address(0), "NFT ADDRESS");
        require(destinationAddress != address(0), "DEST ADDRESS");
        require(paused() == false, "CONTRACT PAUSED");
        require(config.getPausedNetwork(destinationNetworkID) == false, "NETWORK PAUSED");
        require(lastTransfer[msg.sender] + config.getTransferLockupTime() < block.timestamp, "TIMESTAMP");
        require(config.getFeeTokenAmount(destinationNetworkID, feeToken) > 0, "FEE TOKEN");

        IERC721Upgradeable(sourceNFTAddress).safeTransferFrom(msg.sender, address(this), sourceNFTId);
        lastTransfer[msg.sender] = block.timestamp;

        uint256 originalNetworkId;
        uint256 originalNftId;
        bytes32 _id = _generateId(_chainId());
        bool isRelease;
        address originalNftAddress;

        if (sourceNFTAddress == mosaicNftAddress) {
            (originalNftAddress, originalNetworkId, originalNftId) = IMosaicNFT(mosaicNftAddress).getOriginalNftInfo(sourceNFTId);
        } else {
            originalNftAddress = sourceNFTAddress;
            originalNetworkId = _chainId();
            originalNftId = sourceNFTId;
        }

        if (destinationNetworkID == originalNetworkId && mosaicNftAddress == sourceNFTAddress) {
            // mosaicNftAddress is being transferred to the original network
            // in this case release the original nft instead of summoning
            // the relayer will read this event and call releaseSeal on the original layer
            isRelease = true;
        }

        // the relayer will read this event and call summonNFT or releaseSeal
        // based on the value of isRelease
        emit TransferInitiated(
            msg.sender,
            sourceNFTAddress,
            sourceNFTId,
            destinationAddress,
            destinationNetworkID,
            originalNftAddress,
            originalNetworkId,
            originalNftId,
            transferDelay,
            isRelease,
            _id
        );

        // take fees
        _takeFees(sourceNFTAddress, sourceNFTId, _id, destinationNetworkID, feeToken);
    }

    function _takeFees(
        address nftContract,
        uint256 nftId,
        bytes32 _id,
        uint256 remoteNetworkID,
        address feeToken
    ) private {
        uint256 fee = config.getFeeTokenAmount(remoteNetworkID, feeToken);
        if (feeToken != address(0)) {
            require(IERC20Upgradeable(feeToken).balanceOf(msg.sender) >= fee, "LOW BAL");
            SafeERC20Upgradeable.safeTransferFrom(
                IERC20Upgradeable(feeToken),
                msg.sender,
                address(this),
                fee
            );
        } else {
            require(msg.value >= fee, "FEE");
        }
        // store the collected fee
        feeCollection[_id] = Fee(feeToken, fee);
        emit FeeTaken(
            msg.sender,
            nftContract,
            nftId,
            _id,
            remoteNetworkID,
            feeToken,
            fee
        );
    }

    // either summon failed or it's a transfer of the NFT back to the original layer
    function releaseSeal(
        address nftOwner,
        address nftContract,
        uint256 nftId,
        bytes32 id,
        bool isFailure
    ) public nonReentrant onlyOwnerOrRelayer {
        require(paused() == false, "CONTRACT PAUSED");
        require(hasBeenReleased[id] == false, "RELEASED");
        require(IERC721Upgradeable(nftContract).ownerOf(nftId) == address(this), "NOT LOCKED");

        hasBeenReleased[id] = true;
        lastReleasedID = id;

        IERC721Upgradeable(nftContract).safeTransferFrom(address(this), nftOwner, nftId);

        emit SealReleased(nftOwner, nftContract, nftId, id);

        // refund fee in case of a failed transaction only
        if (isFailure == true) {
            _refundFees(nftOwner, nftContract, nftId, id);
        }

    }

    function _refundFees(
        address nftOwner,
        address nftContract,
        uint256 nftId,
        bytes32 id
    ) private {
        Fee memory fee = feeCollection[id];
        // refund the fee
        if (fee.tokenAddress != address(0)) {
            SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(fee.tokenAddress), nftOwner, fee.amount);
        } else {
            (bool success,) = nftOwner.call{value : fee.amount}("");
            if (success == false) {
                revert("FAILED REFUND");
            }
        }
        emit FeeRefunded(
            msg.sender,
            nftContract,
            nftId,
            id,
            fee.tokenAddress,
            fee.amount
        );
    }

    function withdrawFees(address feeToken, address withdrawTo, uint256 amount)
    external
    nonReentrant
    onlyOwner
    {
        if (feeToken != address(0)) {
            require(IERC20Upgradeable(feeToken).balanceOf(address(this)) >= amount, "LOW BAL");
            SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(feeToken), withdrawTo, amount);
        } else {
            require(address(this).balance >= amount, "LOW BAL");
            (bool success,) = withdrawTo.call{value : amount}("");
            if (success == false) {
                revert("FAILED");
            }
        }
    }

    /// @notice method called by the relayer to summon the NFT
    function summonNFT(
        string memory nftUri,
        address destinationAddress,
        address originalNftAddress,
        uint256 originalNetworkID,
        uint256 originalNftId,
        bytes32 id
    )
    public
    nonReentrant
    onlyOwnerOrRelayer
    {

        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        // summon NFT cannot be called on the original network
        // the transfer method will always emit release event for this
        require(chainId != originalNetworkID, "SUMMONED ON ORIGINAL NETWORK");
        require(originalNftAddress != address(0), "ORIGINAL NFT ADDRESS");
        require(paused() == false, "CONTRACT PAUSED");
        require(hasBeenSummoned[id] == false, "SUMMONED");

        hasBeenSummoned[id] = true;
        lastSummonedID = id;

        uint256 mosaicNFTId = IMosaicNFT(mosaicNftAddress).getNftId(originalNftAddress, originalNetworkID, originalNftId);

        // original NFT is first time getting transferred
        if (mosaicNFTId == 0) {

            // use a pre minted nft and set the meta data
            mosaicNFTId = getPreMintedNftId();
            if (mosaicNFTId != 0) {
                IMosaicNFT(mosaicNftAddress).setNFTMetadata(
                    mosaicNFTId,
                    nftUri,
                    originalNftAddress,
                    originalNetworkID,
                    originalNftId
                );
            } else {
                // if no pre mint found mint a new one
                IMosaicNFT(mosaicNftAddress).mintNFT(
                    destinationAddress,
                    nftUri,
                    originalNftAddress,
                    originalNetworkID,
                    originalNftId
                );
            }

        } else {
            // the original nft is locked from a previous transfer from another layer
            // so we need to transfer the NFT instead of minting a new one
            IERC721Upgradeable(mosaicNftAddress).safeTransferFrom(address(this), destinationAddress, mosaicNFTId);
        }

        emit SummonCompleted(destinationAddress, mosaicNftAddress, nftUri, id);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function _generateId(uint256 chainId) private returns (bytes32) {
        return keccak256(abi.encodePacked(block.number, chainId, address(this), nonce++));
    }

    function preMintNFT(uint256 n) external onlyOwnerOrRelayer {
        require(mosaicNftAddress != address(0), "MOSAIC NFT NOT SET");
        for (uint256 i = 0; i < n; i++) {
            uint256 nftId = IMosaicNFT(mosaicNftAddress).preMintNFT();
            preMints.push(nftId);
        }
    }

    function getPreMintedNftId() private returns (uint256) {
        uint256 nftId;
        if (preMints.length > 0) {
            nftId = preMints[preMints.length - 1];
            preMints.pop();
        }
        return nftId;
    }

    function getPreMintedCount() external view returns (uint256) {
        return preMints.length;
    }

    function _chainId() private view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }

    modifier onlyOwnerOrRelayer() {
        require(_msgSender() == owner() || _msgSender() == relayer, "ONLY OWNER OR RELAYER");
        _;
    }

}