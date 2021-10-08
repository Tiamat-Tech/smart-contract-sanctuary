// SPDX-License-Identifier: MIT
// @unsupported: ovm

pragma solidity ^0.6.8;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "./IMosaicNFT.sol";
import "./ISummonerConfig.sol";

//@title: Composable Finance L2 ERC721 Vault
contract Summoner is
IERC721ReceiverUpgradeable,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable
{
    using SafeMathUpgradeable for uint256;

    ISummonerConfig public config;

    uint256 nonce;

    /// @notice nft ids for each NFT contract address (each ERC721 can have a list of NFTs locked);
    /// @dev nft contract => nft id => pending/not
    mapping(address => mapping(uint256 => bool)) public transferStatus;

    // @dev original network id => original nft address => mosaic nft address
    mapping(uint256 => mapping(address => address)) public mosaicNftMapping;

    mapping(address => uint256) public lastTransfer;
    mapping(bytes32 => bool) public hasBeenSummoned; //hasBeenWithdrawn
    mapping(bytes32 => bool) public hasBeenReleased; //hasBeenUnlocked
    bytes32 public lastSummonedID; //lastWithdrawnID
    bytes32 public lastReleasedID; //lastUnlockedID

    struct Fee {
        address tokenAddress;
        uint256 amount;
    }
    // stores the fee collected by the contract against a transfer id
    mapping(bytes32 => Fee) private feeCollection;

    event SealReleased(
        address indexed nftOwner,
        address indexed nftContract,
        uint256 indexed nftId,
        bytes32 id
    );

    event SummoningInitiated(
        address indexed sourceNftOwner,
        address indexed sourceNftAddress,
        uint256 indexed nftId,
        address remoteNFTOwner,
        uint256 remoteNetworkID,
        bytes32 id,
        uint256 transferDelay
    );
    event OriginalNftInfo(
        address indexed originalNftAddress,
        uint256 originalNetworkID,
        string name,
        string symbol,
        bytes32 id
    );
    event ReleaseInitiated(
        address indexed nftOwner,
        address indexed nftContract,
        uint256 indexed nftId,
        address remoteNftAddress,
        address remoteDestinationOwner,
        uint256 remoteNetworkID,
        uint256 transferDelay,
        bytes32 id
    );

    event MosaicNFTDeployed(
        address indexed sourceNftContract,
        uint256 sourceNetworkID,
        address indexed mosaicNftContract,
        uint256 currentNetworkID,
        address originalNftContract,
        uint256 originalNetworkId,
        bytes32 id
    );
    event SummonCompleted(
        address indexed nftOwner,
        address indexed sourceNftContract,
        address indexed destinationNftContract,
        uint256 sourceNetworkId,
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

    /// @notice External callable function to pause the contract
    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    /// @notice External callable function to unpause the contract
    function unpause() external whenPaused onlyOwner {
        _unpause();
    }

    function transferERC721ToLayer(
        address nftContract,
        uint256 nftId,
        address remoteDestinationOwner,
        uint256 remoteNetworkID,
        uint256 transferDelay,
        address feeToken
    )
    external
    payable
    nonReentrant
    {
        require(nftContract != address(0), "CONTRACT ADDRESS");
        require(remoteDestinationOwner != address(0), "DEST ADDRESS");
        require(paused() == false, "CONTRACT PAUSED");
        require(config.getPausedNetwork(remoteNetworkID) == false, "NETWORK PAUSED");
        require(lastTransfer[msg.sender].add(config.getTransferLockupTime()) < block.timestamp, "TIMESTAMP");
        require(IERC721Upgradeable(nftContract).ownerOf(nftId) == msg.sender, "NOT OWNER");
        require(transferStatus[nftContract][nftId] == false, "LOCKED");
        require(config.getFeeTokenAmount(remoteNetworkID, feeToken) > 0, "FEE TOKEN");

        IERC721Upgradeable(nftContract).safeTransferFrom(msg.sender, address(this), nftId);
        lastTransfer[msg.sender] = block.timestamp;
        transferStatus[nftContract][nftId] = true;

        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        bytes32 _id = _generateId();

        address originalNftAddress;
        uint256 originalNetworkId;
        string memory name;
        string memory symbol;

        if (config.isMosaicNft(nftContract)) {
            (originalNftAddress, originalNetworkId, name, symbol) = IMosaicNFT(nftContract).getOriginalNftInfo();
        } else {
            originalNftAddress = nftContract;
            originalNetworkId = chainId;
            name = IERC721MetadataUpgradeable(nftContract).name();
            symbol = IERC721MetadataUpgradeable(nftContract).symbol();
        }

        if (remoteNetworkID == originalNetworkId
            && mosaicNftMapping[originalNetworkId][originalNftAddress] == nftContract) {
            // MosaicNFT is being transferred to the original network
            // in this case release the original nft instead of summoning
            // the relayer will read this event and call releaseSeal on the original layer
            emit ReleaseInitiated(
                msg.sender,
                nftContract,
                nftId,
                originalNftAddress,
                remoteDestinationOwner,
                originalNetworkId,
                transferDelay,
                _id
            );
        } else {
            // the relayer will read this event and call summonNFT on the destination layer
            emit SummoningInitiated(
                msg.sender,
                nftContract,
                nftId,
                remoteDestinationOwner,
                remoteNetworkID,
                _id,
                transferDelay
            );
            // for the relayer to use in the summonNFT method
            emit OriginalNftInfo(
                originalNftAddress,
                originalNetworkId,
                name,
                symbol,
                _id
            );
        }
        // take fees
        _takeFees(nftContract, nftId, _id, remoteNetworkID, feeToken);
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
            require(IERC20Upgradeable(feeToken).balanceOf(msg.sender) >= fee,
                "LOW BAL");
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

    // either summon failed or it's a tranfer of the NFT back to the original layer
    function releaseSeal(
        address nftOwner,
        address nftContract,
        uint256 nftId,
        bytes32 id,
        bool isFailure
    ) public nonReentrant onlyOwner {
        require(paused() == false, "CONTRACT PAUSED");
        require(hasBeenReleased[id] == false, "RELEASED");
        require(transferStatus[nftContract][nftId] == true, "NOT LOCKED");

        hasBeenReleased[id] = true;
        lastReleasedID = id;

        transferStatus[nftContract][nftId] = false;

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

    function withdrawFees(address feeToken, address withdrawTo)
    external
    nonReentrant
    onlyOwner
    {
        if (feeToken != address(0)) {
            uint256 tokenBalance = IERC20Upgradeable(feeToken).balanceOf(address(this));
            SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(feeToken), withdrawTo, tokenBalance);
        } else {
            (bool success,) = withdrawTo.call{value : address(this).balance}("");
            if (success == false) {
                revert("FAILED");
            }
        }
    }

    /// @notice method called by the relayer to summon the NFT
    function summonNFT(
        uint256 sourceNetworkID,
        address sourceNftAddress,
        uint256 nftID,
        string memory nftUri,
        address nftOwner,
        address originalNftAddress,
        uint256 originalNetworkID,
        string memory name,
        string memory symbol,
        bytes32 id
    )
    public
    nonReentrant
    onlyOwner
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

        address mosaicNftAddress;

        // check mosaic nft address for the original nft on the original network
        // this prevents creation of a new mosaic nft for the same original nft
        if (mosaicNftMapping[originalNetworkID][originalNftAddress] == address(0)) {

            // deploy new mosaic nft contract
            mosaicNftAddress = config.deployMosaicNft(originalNftAddress, originalNetworkID, name, symbol);
            mosaicNftMapping[originalNetworkID][originalNftAddress] = mosaicNftAddress;

            emit MosaicNFTDeployed(
                sourceNftAddress,
                sourceNetworkID,
                mosaicNftAddress,
                chainId,
                originalNftAddress,
                originalNetworkID,
                id
            );
        } else {
            mosaicNftAddress = mosaicNftMapping[originalNetworkID][originalNftAddress];
        }

        if (transferStatus[mosaicNftAddress][nftID] == true) {
            // the nft is locked from a previous transfer from another layer
            // the same id is being summoned again on this layer
            // so we need to transfer the NFT instead of minting a new one
            IERC721Upgradeable(mosaicNftAddress).safeTransferFrom(address(this), nftOwner, nftID);
            transferStatus[mosaicNftAddress][nftID] = false;
        } else {
            // mint NFT against the transferred NFT
            config.mintMosaicNft(mosaicNftAddress, nftOwner, nftUri, nftID);
        }

        emit SummonCompleted(
            nftOwner,
            sourceNftAddress,
            mosaicNftAddress,
            sourceNetworkID,
            nftUri,
            id
        );
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function _generateId() private returns (bytes32) {
        return keccak256(abi.encodePacked(block.number, address(this), nonce++));
    }

}