// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

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
    ERC721EnumerableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using StringsUpgradeable for uint256;

    // events
    event AddFreeAllocation(address indexed user, uint256 amount);
    event RemoveFreeAllocation(address indexed user, uint256 amount);
    event DepositQstk(uint256 amount);
    event WithdrawQstk(uint256 amount);
    event SetMaxSupply(uint256 maxSupply);
    event MintNFT(
        address indexed user,
        uint256 indexed nftId,
        uint32 characterId,
        uint32 favCoinId,
        uint32 metaId,
        uint256 lockDuration,
        uint256 mintAmount
    );
    event UpgradeNftCoin(
        address indexed user,
        uint256 indexed nftId,
        uint32 oldFavCoinId,
        uint32 newFavCoinId
    );
    event UnlockQstkFromNft(
        address indexed user,
        uint256 indexed nftId,
        uint256 amount
    );

    // qstk
    uint256 public override totalAssignedQstk; // total qstk balance assigned to nfts
    mapping(address => uint256) public override qstkBalances; // locked qstk balances per user

    // nft
    uint256 public maxSupply; // maximum supply of NFTs
    string private _baseTokenURI;
    mapping(uint256 => NFTData) public nftData;
    mapping(uint256 => uint256) public nftCountByCharacter; // mapping from character id to number of minted nft for the given character

    // contract addresses
    IQNFTGov public governance;
    IQSettings public settings;
    IQNFTSettings public nftSettings;
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
        string memory _quiverBaseUrl,
        uint256 _maxSupply
    ) external initializer {
        __Context_init();
        __ERC721_init("Quiver NFT", "QNFT");
        __ReentrancyGuard_init();

        settings = IQSettings(_settings);
        nftSettings = IQNFTSettings(_nftSettings);
        governance = IQNFTGov(_governance);
        airdrop = IQAirdrop(_airdrop);
        _baseTokenURI = _quiverBaseUrl;

        maxSupply = _maxSupply;
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
    function updateBaseUrl(string memory _quiverBaseUrl) external onlyManager {
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

        emit DepositQstk(_amount);
    }

    /**
     * @dev withdraws qstk token from the contract - only remaing balance available
     */
    function withdrawQstk(uint256 _amount) external onlyManager {
        require(remainingQstk() >= _amount, "QNFT: not enough balance");
        IERC20Upgradeable(qstk()).safeTransfer(msg.sender, _amount);

        emit WithdrawQstk(_amount);
    }

    // NFT

    /**
     * @dev sets the maximum mintable count
     */
    function setMaxSupply(uint256 _maxSupply) external onlyManager {
        require(totalSupply() <= _maxSupply, "QNFT: invalid max supply");

        maxSupply = _maxSupply;
        emit SetMaxSupply(maxSupply);
    }

    /**
     * @dev mint nft with given mint options
     */
    function mintNft(
        uint32 _characterId,
        uint32 _favCoinId,
        uint32 _lockOptionId,
        uint32 _metaId,
        uint256 _lockAmount
    ) external payable {
        require(!nftSettings.onlyAirdropUsers(), "QNFT: not available");

        _mintNft(
            _characterId,
            _favCoinId,
            _lockOptionId,
            _metaId,
            _lockAmount,
            0
        );
    }

    function mintNftForAirdropUser(
        uint32 _characterId,
        uint32 _favCoinId,
        uint32 _lockOptionId,
        uint32 _metaId,
        uint256 _lockAmount,
        uint256 _airdropAmount,
        bytes memory _signature
    ) external payable {
        airdrop.withdrawLockedQStk(msg.sender, _airdropAmount, _signature);

        _mintNft(
            _characterId,
            _favCoinId,
            _lockOptionId,
            _metaId,
            _lockAmount,
            _airdropAmount
        );
    }

    /**
     * @dev updates favorite coin of a given nft
     */
    function upgradeNftCoin(uint256 _nftId, uint32 _favCoinId)
        external
        payable
    {
        require(_nftId != 0 && totalSupply() >= _nftId, "QNFT: invalid nft id");
        require(ownerOf(_nftId) == msg.sender, "QNFT: invalid owner");
        require(
            nftSettings.favCoinsCount() >= _favCoinId,
            "QNFT: invalid favCoin id"
        );

        NFTData storage data = nftData[_nftId];

        uint256 mintPrice =
            (nftSettings.favCoinPrices(_favCoinId) *
                nftSettings.upgradePriceMultiplier()) / 100;
        require(
            msg.value >= mintPrice,
            "QNFT: insufficient coin upgrade price"
        );

        // transfer remaining to user
        (bool sent, ) =
            payable(msg.sender).call{value: msg.value - mintPrice}("");
        require(sent, "QNFT: failed to transfer remaining eth");

        uint32 oldFavCoinId = data.favCoinId;
        data.favCoinId = _favCoinId;

        // transfer to foundation wallet
        _transferToFoundation(mintPrice);

        emit UpgradeNftCoin(msg.sender, _nftId, oldFavCoinId, _favCoinId);
    }

    /**
     * @dev unlocks/withdraws qstk from contract
     */
    function unlockQstkFromNft(uint256 _nftId) external nonReentrant {
        require(_nftId != 0 && totalSupply() >= _nftId, "QNFT: invalid nft id");
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

    /**
     * @dev sets QSettings contract address
     */
    function setSettings(IQSettings _settings) external onlyManager {
        settings = _settings;
    }

    /**
     * @dev sets QNFTSettings contract address
     */
    function setNFTSettings(IQNFTSettings _nftSettings) external onlyManager {
        nftSettings = _nftSettings;
    }

    /**
     * @dev sets QNFTGov contract address
     */
    function setGovernance(IQNFTGov _governance) external onlyManager {
        governance = _governance;
    }

    /**
     * @dev sets QAirdrop contract address
     */
    function setAirdrop(IQAirdrop _airdrop) external onlyManager {
        airdrop = _airdrop;
    }

    // internal functions

    function _mintNft(
        uint32 _characterId,
        uint32 _favCoinId,
        uint32 _lockOptionId,
        uint32 _metaId,
        uint256 _lockAmount,
        uint256 _freeAllocation
    ) internal nonReentrant {
        require(nftSettings.mintStarted(), "QNFT: mint not started");
        require(!nftSettings.mintPaused(), "QNFT: mint paused");
        require(!nftSettings.mintFinished(), "QNFT: mint finished");

        require(
            totalSupply() < maxSupply,
            "QNFT: nft count reached the total supply"
        );

        (uint256 totalPrice, , uint256 nonTokenPrice) =
            nftSettings.calcMintPrice(
                _characterId,
                _favCoinId,
                _lockOptionId,
                _lockAmount,
                _freeAllocation
            );
        require(msg.value >= totalPrice, "QNFT: insufficient mint price");

        require(
            nftCountByCharacter[_characterId] <
                nftSettings.characterMaxSupply(_characterId),
            "QNFT: character count reached at max supply"
        );

        uint256 qstkAmount = _lockAmount + _freeAllocation;

        require(
            totalAssignedQstk + qstkAmount <= totalQstkBalance(),
            "QNFT: insufficient qstk balance"
        );

        // transfer remaining to user
        (bool sent, ) =
            payable(msg.sender).call{value: msg.value - totalPrice}("");
        require(sent, "QNFT: failed to transfer remaining eth");

        uint256 lockDuration =
            nftSettings.lockOptionLockDuration(_lockOptionId);

        uint256 newId = totalSupply() + 1;
        nftData[newId] = NFTData(
            _characterId,
            _favCoinId,
            _metaId,
            lockDuration,
            qstkAmount,
            block.timestamp,
            false
        );

        nftCountByCharacter[_characterId]++;

        _updateQStkBalance(msg.sender, 0, qstkAmount);

        // transfer to foundation wallet
        _transferToFoundation(nonTokenPrice);
        _transferGovernance();

        _mint(msg.sender, newId);

        emit MintNFT(
            msg.sender,
            newId,
            _characterId,
            _favCoinId,
            _lockOptionId,
            qstkAmount,
            _metaId
        );
    }

    /**
     * @dev transfers given amount of ETH to foundation wallet
     */
    function _transferToFoundation(uint256 _amount) internal {
        // transfer to foundation wallet
        address payable foundationWallet = payable(settings.foundationWallet());
        (bool sent, ) = foundationWallet.call{value: _amount}("");
        require(sent, "QNFT: transfer failed");
    }

    /**
     * @dev transfers given amount of ETH to governance
     */
    function _transferGovernance() internal {
        // transfer to governance
        (bool sent, ) =
            payable(address(governance)).call{value: address(this).balance}("");
        require(sent, "QNFT: transfer failed");
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
    ) internal override nonReentrant {
        require(
            !nftData[tokenId].withdrawn ||
                nftSettings.transferAllowedAfterRedeem(),
            "QNFT: transfer not allowed for redeemed token"
        );

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