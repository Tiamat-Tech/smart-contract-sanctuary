// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Treasury is
    Initializable,
    ContextUpgradeable,
    OwnableUpgradeable,
    IERC721Receiver
{
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct ERC721Asset {
        address owner;
        uint8 serverId;
        address contractAddress;
        uint256 tokenId;
    }

    // Map from user address and server and nft
    // map[serverId]map[userAddress][]ERC721Asset
    // mapping(bytes32 => mapping(address => ERC721Asset[])) public nftTreasury;
    mapping(address => mapping(uint256 => ERC721Asset)) public nftTreasury;

    IERC20 public lfwToken;

    // 1e3
    uint256 public conversionRate;

    // event list
    event AssetERC20Deposit(address indexed owner, uint8 serverID, uint256 amount);
    event AssetNFTDeposit(address indexed owner, uint8 serverId, address indexed contractAddress,uint256 tokenId);
    event AssetNFTWithdraw(address indexed owner, uint8 serverId, address indexed contractAddress, uint256 tokenId);
    event SwapGem(address indexed swapper, uint256 amountInLFW, uint256 amountInGem, uint256 serverId);
    event ConversionRateChange(uint256 newConversion);

    // constructor
    function initialize() public initializer {
        __Context_init();
        __Ownable_init();
    }

    function depositNFT(address _nftAddress, uint256 _tokenId, uint8 serverId) external {
        require(_nftAddress != address(0) && _nftAddress != address(this));
        require(msg.sender != address(0) && msg.sender != address(this));
        IERC721 nft = _getNftContract(_nftAddress);
        require(nft.ownerOf(_tokenId) == msg.sender);

        // write to state
        ERC721Asset memory _asset = ERC721Asset(
            msg.sender,
            serverId,
            _nftAddress,
            _tokenId
        );
        nftTreasury[msg.sender][_tokenId] = _asset;

        // do transfer
        nft.safeTransferFrom(msg.sender, address(this), _tokenId);

        emit AssetNFTDeposit(msg.sender, serverId, _nftAddress, _tokenId);
    }

    function withdrawNFT(address _nftAddress, uint256 _tokenId, uint8 serverId) external {
        require(_nftAddress != address(0) && _nftAddress != address(this));
        require(msg.sender != address(0) && msg.sender != address(this));

        // check state
        ERC721Asset memory asset = nftTreasury[msg.sender][_tokenId];
        require(asset.owner == msg.sender);
        require(asset.serverId == serverId);

        _getNftContract(_nftAddress).safeTransferFrom(
            address(this),
            msg.sender,
            asset.tokenId
        );
        delete nftTreasury[msg.sender][_tokenId];

        emit AssetNFTWithdraw(msg.sender, serverId, _nftAddress, _tokenId);
    }

    function swapGem(uint256 amount, uint256 serverId) external {
        require(amount > 0, "SZ");
        // lfwToken.safeTransferFrom(msg.sender, address(this), amount);
        // TODO: ...
        emit SwapGem(msg.sender, amount, amount, serverId);
    }

    function setLFWTokenAddress(address _lfwToken) external onlyOwner {
        lfwToken = IERC20(_lfwToken);
    }

    function setConversionRate(uint256 newConversion) external onlyOwner {
        conversionRate = newConversion;
        emit ConversionRateChange(newConversion);
    }

    // TODO: function withdrawLFW

    /// @dev Gets the NFT object from an address, validating that implementsERC721 is true.
    /// @param _nftAddress - Address of the NFT.
    function _getNftContract(address _nftAddress)
        internal
        pure
        returns (IERC721)
    {
        IERC721 candidateContract = IERC721(_nftAddress);
        return candidateContract;
    }

    /// implement for IERC721Receiver
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}