// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "solidity-bytes-utils/contracts/BytesLib.sol";

import "../interface/structs.sol";
import "../interface/IQNFT.sol";
import "../interface/IQNFTGov.sol";
import "../interface/IQNFTSettings.sol";
import "../interface/IQSettings.sol";
import "../interface/IQAirdrop.sol";

/**
 * @author fantasy
 */
contract QNFT is
    IQNFT,
    ContextUpgradeable,
    ERC721Upgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using BytesLib for bytes;

    // events
    event AddFreeAllocation(address indexed user, uint256 amount);
    event RemoveFreeAllocation(address indexed user, uint256 amount);
    event DepositQstk(address indexed owner, uint256 amount);
    event WithdrawQstk(address indexed owner, uint256 amount);
    event SetTotalSupply(address indexed owner, uint256 totalSupply);
    event MintNFT(
        address indexed user,
        uint256 indexed nftId,
        uint256 imageId,
        uint256 bgImageId,
        uint256 favCoinId,
        uint256 lockDuration,
        uint256 defaultImageIndex,
        string metaUrl
    );
    event UpgradeNftImage(
        address indexed user,
        uint256 indexed nftId,
        uint256 oldImageId,
        uint256 newImageId
    );
    event UpgradeNftBackground(
        address indexed user,
        uint256 indexed nftId,
        uint256 oldBgImageId,
        uint256 newBgImageId
    );
    event UpgradeNftCoin(
        address indexed user,
        uint256 indexed nftId,
        uint256 oldFavCoinId,
        uint256 newFavCoinId
    );
    event UnlockQstkFromNft(
        address indexed user,
        uint256 indexed nftId,
        uint256 amount
    );

    // constants
    uint256 public constant FOUNDATION_PERCENTAGE = 30; // 30%
    uint256 public constant PERCENT_MAX = 100;

    // qstk
    uint256 public override totalAssignedQstk; // total qstk balance assigned to nfts
    mapping(address => uint256) public override qstkBalances; // locked qstk balances per user

    // nft
    string private _baseTokenURI;
    uint256 public totalSupply; // maximum mintable nft count
    mapping(uint256 => NFTData) public nftData;
    mapping(uint256 => uint256) private nftHashToId; // Mapping from token hash to token id
    uint256 private nftCount; // circulating supply - minted nft counts

    IQNFTGov public governance;
    IQSettings public settings; // QSettings contract address
    IQNFTSettings public nftSettings; // QNFTSettings contract address
    IQAirdrop public airdrop;

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyManager() {
        require(
            settings.manager() == msg.sender,
            "QNFTSettings: caller is not the manager"
        );
        _;
    }

    receive() external payable {}

    fallback() external payable {}

    function initialize(
        address _settings,
        address _nftSettings,
        address _governance,
        address _airdrop,
        string memory _quiverBaseUrl
    ) external initializer {
        __Context_init();
        __ERC721_init("Quiver NFT", "QNFT");
        __ReentrancyGuard_init();

        settings = IQSettings(_settings);
        nftSettings = IQNFTSettings(_nftSettings);
        governance = IQNFTGov(_governance);
        airdrop = IQAirdrop(_airdrop);
        _baseTokenURI = _quiverBaseUrl;
    }

    // qstk

    function qstk() public view returns (address) {
        return settings.qstk();
    }

    /**
     * @dev returns the total qstk balance locked on the contract
     */
    function totalQstkBalance() public view returns (uint256) {
        return IERC20Upgradeable(qstk()).balanceOf(address(this));
    }

    /**
     * @dev returns remaining qstk balance of the contract
     */
    function remainingQstk() public view returns (uint256) {
        return totalQstkBalance() - totalAssignedQstk;
    }

    /**
     * @dev updates baseURL
     */
    function updateBaseUrl(string memory _quiverBaseUrl) external {
        _baseTokenURI = _quiverBaseUrl;
    }

    /**
     * @dev deposits qstk tokens to the contract
     */
    function depositQstk(uint256 _amount) external onlyManager {
        IERC20Upgradeable(qstk()).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        emit DepositQstk(msg.sender, _amount);
    }

    /**
     * @dev withdraws qstk token from the contract - only remaing balance available
     */
    function withdrawQstk(uint256 _amount) external onlyManager {
        require(remainingQstk() >= _amount, "QNFT: not enough balance");
        IERC20Upgradeable(qstk()).safeTransfer(msg.sender, _amount);

        emit WithdrawQstk(msg.sender, _amount);
    }

    // NFT

    /**
     * @dev returns minted nft count
     */
    function circulatingSupply() public view returns (uint256) {
        return nftCount;
    }

    /**
     * @dev sets the maximum mintable count
     */
    function setTotalSupply(uint256 _totalSupply) external onlyManager {
        totalSupply = _totalSupply;
        emit SetTotalSupply(msg.sender, totalSupply);
    }

    /**
     * @dev returns token if based on the given options
     */
    function getTokenId(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _lockDuration
    ) public view returns (uint256) {
        return
            _getTokenIdForMintOptions(
                _imageId,
                _bgImageId,
                _favCoinId,
                _lockDuration
            );
    }

    /**
     * @dev mint nft with given mint options
     */
    function mintNft(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _lockOptionId,
        uint256 _lockAmount,
        uint256 _defaultImageIndex,
        string memory _metaUrl
    ) external payable {
        require(!nftSettings.onlyAirdropUsers(), "QNFT: not available");

        _mintNft(
            _imageId,
            _bgImageId,
            _favCoinId,
            _lockOptionId,
            _lockAmount,
            _defaultImageIndex,
            _metaUrl,
            0
        );
    }

    function mintNftForAirdropUser(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _lockOptionId,
        uint256 _lockAmount,
        uint256 _defaultImageIndex,
        string memory _metaUrl,
        uint256 _airdropAmount,
        bytes memory _signature
    ) external payable {
        airdrop.withdrawLockedQStk(msg.sender, _airdropAmount, _signature);

        _mintNft(
            _imageId,
            _bgImageId,
            _favCoinId,
            _lockOptionId,
            _lockAmount,
            _defaultImageIndex,
            _metaUrl,
            _airdropAmount
        );
    }

    /**
     * @dev updates nft image of a given nft
     */
    function upgradeNftImage(uint256 _nftId, uint256 _imageId)
        external
        payable
    {
        require(
            _nftId != uint256(0) && nftCount >= _nftId,
            "QNFT: invalid nft id"
        );
        require(ownerOf(_nftId) == msg.sender, "QNFT: invalid owner");
        require(nftSettings.imageCount() >= _imageId, "QNFT: invalid image id");

        NFTData storage data = nftData[_nftId];

        require(
            getTokenId(
                _imageId,
                data.bgImageId,
                data.favCoinId,
                data.lockDuration
            ) == uint256(0),
            "QNFT: nft already exists"
        );

        uint256 mintPrice = nftSettings.imagePrices(_imageId);
        require(
            msg.value >= mintPrice,
            "QNFT: insufficient image upgrade price"
        );

        // transfer remaining to user
        payable(msg.sender).transfer(msg.value - mintPrice);

        uint256 oldImageId = data.imageId;
        data.imageId = _imageId;

        _setTokenIdForMintOptions(
            oldImageId,
            data.bgImageId,
            data.favCoinId,
            data.lockDuration,
            uint256(0)
        );
        _setTokenIdForMintOptions(
            _imageId,
            data.bgImageId,
            data.favCoinId,
            data.lockDuration,
            _nftId
        );

        // transfer to foundation wallet
        _transferToFoundation(
            (mintPrice * FOUNDATION_PERCENTAGE) / PERCENT_MAX
        );
        _transferGovernance();

        emit UpgradeNftImage(msg.sender, _nftId, oldImageId, _imageId);
    }

    /**
     * @dev updates background of a given nft
     */
    function upgradeNftBackground(uint256 _nftId, uint256 _bgImageId) external {
        require(
            _nftId != uint256(0) && nftCount >= _nftId,
            "QNFT: invalid nft id"
        );
        require(ownerOf(_nftId) == msg.sender, "QNFT: invalid owner");
        require(
            nftSettings.bgImageCount() >= _bgImageId,
            "QNFT: invalid background image id"
        );

        NFTData storage data = nftData[_nftId];

        require(
            getTokenId(
                data.imageId,
                _bgImageId,
                data.favCoinId,
                data.lockDuration
            ) == uint256(0),
            "QNFT: nft already exists"
        );

        uint256 oldBgImageId = data.bgImageId;
        data.bgImageId = _bgImageId;

        _setTokenIdForMintOptions(
            data.imageId,
            oldBgImageId,
            data.favCoinId,
            data.lockDuration,
            uint256(0)
        );
        _setTokenIdForMintOptions(
            data.imageId,
            _bgImageId,
            data.favCoinId,
            data.lockDuration,
            _nftId
        );

        emit UpgradeNftBackground(msg.sender, _nftId, oldBgImageId, _bgImageId);
    }

    /**
     * @dev updates favorite coin of a given nft
     */
    function upgradeNftCoin(uint256 _nftId, uint256 _favCoinId)
        external
        payable
    {
        require(
            _nftId != uint256(0) && nftCount >= _nftId,
            "QNFT: invalid nft id"
        );
        require(ownerOf(_nftId) == msg.sender, "QNFT: invalid owner");
        require(
            nftSettings.favCoinsCount() >= _favCoinId,
            "QNFT: invalid image id"
        );

        NFTData storage data = nftData[_nftId];

        require(
            getTokenId(
                data.imageId,
                data.bgImageId,
                _favCoinId,
                data.lockDuration
            ) == uint256(0),
            "QNFT: nft already exists"
        );

        uint256 mintPrice = nftSettings.favCoinPrices(_favCoinId);
        require(
            msg.value >= mintPrice,
            "QNFT: insufficient coin upgrade price"
        );

        // transfer remaining to user
        payable(msg.sender).transfer(msg.value - mintPrice);

        uint256 oldFavCoinId = data.favCoinId;
        data.favCoinId = _favCoinId;

        _setTokenIdForMintOptions(
            data.imageId,
            data.bgImageId,
            oldFavCoinId,
            data.lockDuration,
            uint256(0)
        );
        _setTokenIdForMintOptions(
            data.imageId,
            data.bgImageId,
            _favCoinId,
            data.lockDuration,
            _nftId
        );

        // transfer to foundation wallet
        _transferToFoundation(
            (mintPrice * FOUNDATION_PERCENTAGE) / PERCENT_MAX
        );
        _transferGovernance();

        emit UpgradeNftCoin(msg.sender, _nftId, oldFavCoinId, _favCoinId);
    }

    /**
     * @dev unlocks/withdraws qstk from contract
     */
    function unlockQstkFromNft(uint256 _nftId) external nonReentrant {
        require(
            _nftId != uint256(0) && nftCount >= _nftId,
            "QNFT: invalid nft id"
        );
        require(ownerOf(_nftId) == msg.sender, "QNFT: invalid owner");

        NFTData storage item = nftData[_nftId];

        require(item.withdrawn == false, "QNFT: already withdrawn");
        require(
            item.createdAt + item.lockDuration >= block.timestamp,
            "QNFT: not able to unlock"
        );

        uint256 unlockAmount = item.lockAmount;
        IERC20Upgradeable(qstk()).safeTransfer(msg.sender, unlockAmount);

        _updateQStkBalance(msg.sender, unlockAmount, 0);

        item.withdrawn = true;

        emit UnlockQstkFromNft(msg.sender, _nftId, unlockAmount);
    }

    // internal functions

    function _mintNft(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _lockOptionId,
        uint256 _lockAmount,
        uint256 _defaultImageIndex,
        string memory _metaUrl,
        uint256 _freeAllocation
    ) internal {
        require(nftSettings.mintStarted(), "QNFT: mint not started");
        require(!nftSettings.mintPaused(), "QNFT: mint paused");
        require(!nftSettings.mintFinished(), "QNFT: mint finished");

        require(
            nftCount < totalSupply,
            "QNFT: nft count reached the total supply"
        );

        require(_defaultImageIndex < 5, "QNFT: invalid image index");

        uint256 mintPrice =
            nftSettings.calcMintPrice(
                _imageId,
                _bgImageId,
                _favCoinId,
                _lockOptionId,
                _lockAmount,
                _freeAllocation
            );
        require(msg.value >= mintPrice, "QNFT: insufficient mint price");
        // transfer remaining to user
        payable(msg.sender).transfer(msg.value - mintPrice);

        uint256 qstkAmount = _lockAmount + _freeAllocation;

        require(
            totalAssignedQstk + qstkAmount <= totalQstkBalance(),
            "QNFT: insufficient qstk balance"
        );

        uint256 lockDuration =
            nftSettings.lockOptionLockDuration(_lockOptionId);

        require(
            getTokenId(_imageId, _bgImageId, _favCoinId, lockDuration) ==
                uint256(0),
            "QNFT: nft already exists"
        );

        nftCount++;
        nftData[nftCount] = NFTData(
            _imageId,
            _favCoinId,
            _bgImageId,
            lockDuration,
            qstkAmount,
            _defaultImageIndex,
            block.timestamp,
            false,
            _metaUrl
        );
        _setTokenIdForMintOptions(
            _imageId,
            _bgImageId,
            _favCoinId,
            lockDuration,
            nftCount
        );

        _updateQStkBalance(msg.sender, 0, qstkAmount);

        // transfer to foundation wallet
        _transferToFoundation(
            (mintPrice * FOUNDATION_PERCENTAGE) / PERCENT_MAX
        );
        _transferGovernance();

        _mint(msg.sender, nftCount);

        emit MintNFT(
            msg.sender,
            nftCount,
            _imageId,
            _bgImageId,
            _favCoinId,
            _lockOptionId,
            _defaultImageIndex,
            _metaUrl
        );
    }

    /**
     * @dev returns the nft id of a given mint option
     */
    function _getTokenIdForMintOptions(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _lockDuration
    ) internal view returns (uint256) {
        uint256 nftHash =
            _getHashFromMintOptions(
                _imageId,
                _bgImageId,
                _favCoinId,
                _lockDuration
            );

        return nftHashToId[nftHash];
    }

    /**
     * @dev sets nft id for given mint options
     */
    function _setTokenIdForMintOptions(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _lockDuration,
        uint256 _nftId
    ) internal {
        uint256 nftHash =
            _getHashFromMintOptions(
                _imageId,
                _bgImageId,
                _favCoinId,
                _lockDuration
            );

        nftHashToId[nftHash] = _nftId;
    }

    /**
     * @dev returns the hash of the given mint options
     */
    function _getHashFromMintOptions(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _lockDuration
    ) internal pure returns (uint256) {
        return
            abi
                .encodePacked(
                uint64(_imageId),
                uint64(_bgImageId),
                uint64(_favCoinId),
                uint64(_lockDuration)
            )
                .toUint256(0);
    }

    /**
     * @dev transfers given amount of qstk token to foundation wallet
     */
    function _transferToFoundation(uint256 _amount) internal {
        // transfer to foundation wallet
        address payable foundation = payable(settings.foundation());
        foundation.transfer(_amount);
    }

    /**
     * @dev transfers given amount of qstk token to governance
     */
    function _transferGovernance() internal {
        // transfer to governance
        payable(address(governance)).transfer(address(this).balance);
    }

    /**
     * @dev returns base URL
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev transfer nft
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        super._transfer(from, to, tokenId);

        uint256 qstkAmount = nftData[tokenId].lockAmount;

        // Update QstkBalance
        _updateQStkBalance(from, qstkAmount, 0);
        _updateQStkBalance(to, 0, qstkAmount);
    }

    function _updateQStkBalance(
        address user,
        uint256 minusAmount,
        uint256 plusAmount
    ) internal {
        uint256 originAmount = qstkBalances[user];
        qstkBalances[user] = qstkBalances[user] + plusAmount - minusAmount;
        totalAssignedQstk = totalAssignedQstk + plusAmount - minusAmount;

        IQNFTGov(governance).updateVote(user, originAmount, qstkBalances[user]);
    }
}