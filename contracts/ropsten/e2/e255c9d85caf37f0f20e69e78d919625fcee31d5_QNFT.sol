// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
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

/**
 * @author fantasy
 */
contract QNFT is
    IQNFT,
    OwnableUpgradeable,
    ERC721Upgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;
    using BytesLib for bytes;

    // events
    event AddFreeAllocation(address indexed user, uint256 amount);
    event RemoveFreeAllocation(address indexed user, uint256 amount);
    event DepositQstk(address indexed owner, uint256 amount);
    event WithdrawQstk(address indexed owner, uint256 amount);
    event SetTotalSupply(address indexed owner, uint256 totalSupply);
    event StartMint(address indexed owner, uint256 startedAt);
    event PauseMint(address indexed owner, uint256 pausedAt);
    event UnpauseMint(address indexed owner, uint256 unPausedAt);
    event MintNFT(
        address indexed user,
        uint256 indexed nftId,
        uint256 imageId,
        uint256 bgImageId,
        uint256 favCoinId,
        uint256 lockOptionId,
        string creator_name,
        string color,
        string story
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
    event SetFoundationWallet(address indexed owner, address wallet);

    // constants
    uint256 public constant NFT_SALE_DURATION = 1209600; // 2 weeks
    uint256 public constant FOUNDATION_PERCENTAGE = 30; // 30%
    uint256 public constant MIN_VOTE_DURATION = 604800; // 1 week
    uint256 public constant SAFE_VOTE_END_DURATION = 1814400; // 3 weeks
    uint256 public constant PERCENT_MAX = 100;

    // qstk
    address public override qstk;
    uint256 public override totalAssignedQstk; // total qstk balance assigned to nfts
    mapping(address => uint256) public override qstkBalances; // locked qstk balances per user
    mapping(address => uint256) public freeAllocations; // free allocated qstk balances per user
    uint256 totalFreeAllocations; // total free allocated qstk balances
    uint256 distributedFreeAllocations; // total distributed amount of free allocations

    // nft
    IQNFTSettings settings; // QNFTSettings contract address
    address payable governance; // QNFTGov contract address
    uint256 public totalSupply; // maximum mintable nft count
    mapping(uint256 => NFTData) public nftData;
    mapping(uint256 => uint256) private nftIds;
    uint256 private nftCount; // circulating supply - minted nft counts

    bool unlocked; // if qstk is already unlocked/withdrawn

    // mint options set
    bool public override mintStarted;
    bool public mintPaused;
    uint256 public mintStartTime;

    // foundation
    address payable public foundationWallet; // periodically sends FOUNDATION_PERCENTAGE % of deposits to foundation wallet.

    receive() external payable {}

    fallback() external payable {}

    function initialize(
        address _qstk,
        IQNFTSettings _settings,
        address payable _governance,
        address payable _foundationWallet
    ) external initializer {
        __Ownable_init();
        __ERC721_init("Quiver NFT", "QNFT");
        __ReentrancyGuard_init();

        qstk = _qstk;
        settings = _settings;
        governance = _governance;

        // foundation
        foundationWallet = _foundationWallet;
    }

    // qstk

    /**
     * @dev returns the total qstk balance locked on the contract
     */
    function totalQstkBalance() public view returns (uint256) {
        return IERC20Upgradeable(qstk).balanceOf(address(this));
    }

    /**
     * @dev returns remaining qstk balance of the contract
     */
    function remainingQstk() public view returns (uint256) {
        return totalQstkBalance().sub(totalAssignedQstk);
    }

    /**
     * @dev deposits qstk tokens to the contract
     */
    function depositQstk(uint256 _amount) public onlyOwner {
        IERC20Upgradeable(qstk).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        emit DepositQstk(msg.sender, _amount);
    }

    /**
     * @dev withdraws qstk token from the contract - only remaing balance available
     */
    function withdrawQstk(uint256 _amount) public onlyOwner {
        require(remainingQstk() >= _amount, "QNFT: not enough balance");
        IERC20Upgradeable(qstk).safeTransfer(msg.sender, _amount);

        emit WithdrawQstk(msg.sender, _amount);
    }

    /**
     * @dev adds free allocation to the user
     */
    function addFreeAllocation(address _user, uint256 _amount)
        public
        onlyOwner
    {
        freeAllocations[_user] = freeAllocations[_user].add(_amount);
        totalFreeAllocations = totalFreeAllocations.add(_amount);

        emit AddFreeAllocation(_user, _amount);
    }

    /**
     * @dev removes free allocation from the user
     */
    function removeFreeAllocation(address _user, uint256 _amount)
        public
        onlyOwner
    {
        if (freeAllocations[_user] > _amount) {
            totalFreeAllocations = totalFreeAllocations.sub(_amount);
            freeAllocations[_user] = freeAllocations[_user].sub(_amount);
        } else {
            totalFreeAllocations = totalFreeAllocations.sub(
                freeAllocations[_user]
            );
            freeAllocations[_user] = 0;
        }
        emit RemoveFreeAllocation(_user, _amount);
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
    function setTotalSupply(uint256 _totalSupply) public onlyOwner {
        require(
            _totalSupply <
                settings.lockOptionsCount().mul(settings.nftImagesCount()).mul(
                    settings.favCoinsCount()
                ),
            "QNFT: too big"
        );

        totalSupply = _totalSupply;
        emit SetTotalSupply(msg.sender, totalSupply);
    }

    /**
     * @dev starts/restarts mint process
     */
    function startMint() public onlyOwner {
        require(!mintStarted || mintFinished(), "QNFT: mint in progress");

        mintStarted = true;
        mintStartTime = block.timestamp;

        emit StartMint(msg.sender, mintStartTime);
    }

    /**
     * @dev pause mint process
     */
    function pauseMint() public onlyOwner {
        require(mintStarted == true, "QNFT: mint not started");
        require(mintPaused == false, "QNFT: mint already paused");

        mintPaused = true;

        emit PauseMint(msg.sender, block.timestamp);
    }

    /**
     * @dev unpause mint process
     */
    function unPauseMint() public onlyOwner {
        require(mintStarted == true, "QNFT: mint not started");
        require(mintPaused == true, "QNFT: mint not paused");

        mintPaused = false;

        emit UnpauseMint(msg.sender, block.timestamp);
    }

    /**
     * @dev checks if mint process is finished
     */
    function mintFinished() public view override returns (bool) {
        return
            mintStarted &&
            mintStartTime.add(NFT_SALE_DURATION) <= block.timestamp;
    }

    /**
     * @dev returns the current vote status
     */
    function voteStatus() public view override returns (VoteStatus) {
        if (!mintStarted || !mintFinished()) {
            return VoteStatus.NotStarted;
        } else if (
            block.timestamp <
            mintStartTime.add(NFT_SALE_DURATION).add(MIN_VOTE_DURATION)
        ) {
            return VoteStatus.InProgress;
        } else if (
            block.timestamp <
            mintStartTime.add(NFT_SALE_DURATION).add(SAFE_VOTE_END_DURATION)
        ) {
            return VoteStatus.AbleToWithdraw;
        } else {
            return VoteStatus.AbleToSafeWithdraw;
        }
    }

    /**
     * @dev checks if given nft set is exists
     */
    function nftMinted(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _lockOptionId
    ) public view returns (bool) {
        return
            _getNftId(_imageId, _bgImageId, _favCoinId, _lockOptionId) !=
            uint256(0);
    }

    /**
     * @dev mint nft with given mint options
     */
    function mintNFT(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _lockOptionId,
        uint256 _lockAmount,
        uint256 _defaultImageIndex,
        string memory _name,
        string memory _creator_name,
        string memory _color,
        string memory _story
    ) public payable {
        require(mintStarted, "QNFT: mint not started");
        require(!mintPaused, "QNFT: mint paused");
        require(!mintFinished(), "QNFT: mint finished");

        require(
            nftCount < totalSupply,
            "QNFT: nft count reached the total supply"
        );

        require(_defaultImageIndex < 5, "QNFT: invalid image index");

        uint256 mintPrice =
            settings.calcMintPrice(
                _imageId,
                _bgImageId,
                _favCoinId,
                _lockOptionId,
                _lockAmount,
                freeAllocations[msg.sender]
            );
        require(msg.value >= mintPrice, "QNFT: insufficient mint price");
        // transfer remaining to user
        payable(msg.sender).transfer(msg.value.sub(mintPrice));

        uint256 qstkAmount = _lockAmount.add(freeAllocations[msg.sender]);

        require(
            totalAssignedQstk.add(qstkAmount) <= totalQstkBalance(),
            "QNFT: insufficient qstk balance"
        );

        require(
            !nftMinted(_imageId, _bgImageId, _favCoinId, _lockOptionId),
            "QNFT: nft already exists"
        );

        nftCount = nftCount.add(1);
        nftData[nftCount] = NFTData(
            _imageId,
            _favCoinId,
            _bgImageId,
            _lockOptionId,
            qstkAmount,
            _defaultImageIndex,
            block.timestamp,
            false,
            NFTMeta(_name, _color, _story),
            NFTCreator(_creator_name, msg.sender)
        );
        _setNftId(_imageId, _bgImageId, _favCoinId, _lockOptionId, nftCount);

        totalAssignedQstk = totalAssignedQstk.add(qstkAmount);

        qstkBalances[msg.sender] = qstkBalances[msg.sender].add(qstkAmount);

        IQNFTGov(governance).updateVoteAmount(msg.sender, 0, qstkAmount);

        // calculate free allocations
        uint256 freeAllocation = freeAllocations[msg.sender];
        if (freeAllocation > 0) {
            distributedFreeAllocations = distributedFreeAllocations.add(
                freeAllocation
            );
            totalFreeAllocations = totalFreeAllocations.sub(freeAllocation);
            freeAllocations[msg.sender] = 0;
        }

        // transfer to foundation wallet
        _transferFoundation(
            msg.value.mul(FOUNDATION_PERCENTAGE).div(PERCENT_MAX)
        );
        _transferGovernance();

        _mint(address(this), nftCount);

        emit MintNFT(
            msg.sender,
            nftCount,
            _imageId,
            _bgImageId,
            _favCoinId,
            _lockOptionId,
            _creator_name,
            _color,
            _story
        );
    }

    /**
     * @dev updates nft image of a given nft
     */
    function upgradeNftImage(uint256 _nftId, uint256 _imageId) public payable {
        require(
            _nftId != uint256(0) && nftCount >= _nftId,
            "QNFT: invalid nft id"
        );
        require(ownerOf(_nftId) == msg.sender, "QNFT: invalid owner");
        require(
            settings.nftImagesCount() >= _imageId,
            "QNFT: invalid image id"
        );

        NFTData storage data = nftData[_nftId];

        require(
            !nftMinted(
                _imageId,
                data.bgImageId,
                data.favCoinId,
                data.lockOptionId
            ),
            "QNFT: nft already exists"
        );

        uint256 mintPrice = settings.nftImageMintPrice(_imageId);
        require(
            msg.value >= mintPrice,
            "QNFT: insufficient image upgrade price"
        );

        // transfer remaining to user
        payable(msg.sender).transfer(msg.value.sub(mintPrice));

        uint256 oldImageId = data.imageId;
        data.imageId = _imageId;

        // transfer to foundation wallet
        _transferFoundation(
            msg.value.mul(FOUNDATION_PERCENTAGE).div(PERCENT_MAX)
        );
        _transferGovernance();

        emit UpgradeNftImage(msg.sender, _nftId, oldImageId, _imageId);
    }

    /**
     * @dev updates background of a given nft
     */
    function upgradeNftBackground(uint256 _nftId, uint256 _bgImageId) public {
        require(
            _nftId != uint256(0) && nftCount >= _nftId,
            "QNFT: invalid nft id"
        );
        require(ownerOf(_nftId) == msg.sender, "QNFT: invalid owner");
        require(
            settings.bgImagesCount() >= _bgImageId,
            "QNFT: invalid background image id"
        );

        NFTData storage data = nftData[_nftId];

        require(
            !nftMinted(
                data.imageId,
                _bgImageId,
                data.favCoinId,
                data.lockOptionId
            ),
            "QNFT: nft already exists"
        );

        uint256 oldBgImageId = data.bgImageId;
        data.bgImageId = _bgImageId;

        emit UpgradeNftBackground(msg.sender, _nftId, oldBgImageId, _bgImageId);
    }

    /**
     * @dev updates favorite coin of a given nft
     */
    function upgradeNftCoin(uint256 _nftId, uint256 _favCoinId) public payable {
        require(
            _nftId != uint256(0) && nftCount >= _nftId,
            "QNFT: invalid nft id"
        );
        require(ownerOf(_nftId) == msg.sender, "QNFT: invalid owner");
        require(
            settings.favCoinsCount() >= _favCoinId,
            "QNFT: invalid image id"
        );

        NFTData storage data = nftData[_nftId];

        require(
            !nftMinted(
                data.imageId,
                data.bgImageId,
                _favCoinId,
                data.lockOptionId
            ),
            "QNFT: nft already exists"
        );

        uint256 mintPrice = settings.favCoinMintPrice(_favCoinId);
        require(
            msg.value >= mintPrice,
            "QNFT: insufficient coin upgrade price"
        );

        // transfer remaining to user
        payable(msg.sender).transfer(msg.value.sub(mintPrice));

        uint256 oldFavCoinId = data.favCoinId;
        data.favCoinId = _favCoinId;

        // transfer to foundation wallet
        _transferFoundation(
            msg.value.mul(FOUNDATION_PERCENTAGE).div(PERCENT_MAX)
        );
        _transferGovernance();

        emit UpgradeNftCoin(msg.sender, _nftId, oldFavCoinId, _favCoinId);
    }

    /**
     * @dev unlocks/withdraws qstk from contract
     */
    function unlockQstkFromNft(uint256 _nftId) public nonReentrant {
        require(
            _nftId != uint256(0) && nftCount >= _nftId,
            "QNFT: invalid nft id"
        );
        require(ownerOf(_nftId) == msg.sender, "QNFT: invalid owner");

        NFTData storage item = nftData[_nftId];
        uint256 lockDuration =
            settings.lockOptionLockDuration(item.lockOptionId);

        require(item.withdrawn == false, "QNFT: already withdrawn");
        require(
            item.createdAt.add(lockDuration) >= block.timestamp,
            "QNFT: not able to unlock"
        );

        uint256 unlockAmount = item.lockAmount;
        IERC20Upgradeable(qstk).safeTransfer(msg.sender, unlockAmount);
        qstkBalances[msg.sender] = qstkBalances[msg.sender].sub(unlockAmount);
        totalAssignedQstk = totalAssignedQstk.sub(unlockAmount);

        IQNFTGov(governance).updateVoteAmount(msg.sender, unlockAmount, 0);

        item.withdrawn = true;
        unlocked = true;

        emit UnlockQstkFromNft(msg.sender, _nftId, unlockAmount);
    }

    /**
     * @dev upgrades QSTK token address
     */
    function upgradeQStk(address _qstk) public onlyOwner {
        require(!unlocked, "QNFT: already unlocked");

        transferFrom(msg.sender, address(this), totalQstkBalance());

        qstk = _qstk;
    }

    // internal functions

    /**
     * @dev returns the nft id of a given mint option
     */
    function _getNftId(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _lockOptionId
    ) internal view returns (uint256) {
        uint256 id =
            abi
                .encodePacked(
                uint64(_imageId),
                uint64(_bgImageId),
                uint64(_favCoinId),
                uint64(_lockOptionId)
            )
                .toUint256(0);

        return nftIds[id];
    }

    /**
     * @dev sets nft id for given mint options
     */
    function _setNftId(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _lockOptionId,
        uint256 _nftId
    ) internal {
        uint256 id =
            abi
                .encodePacked(
                uint64(_imageId),
                uint64(_bgImageId),
                uint64(_favCoinId),
                uint64(_lockOptionId)
            )
                .toUint256(0);
        nftIds[id] = _nftId;
    }

    /**
     * @dev transfers given amount of qstk token to foundation wallet
     */
    function _transferFoundation(uint256 _amount) internal {
        // transfer to foundation wallet
        foundationWallet.transfer(_amount);
    }

    /**
     * @dev transfers given amount of qstk token to governance
     */
    function _transferGovernance() internal {
        // transfer to governance
        governance.transfer(address(this).balance);
    }

    /**
     * @dev sets the foundation wallet
     */
    function setFoundationWallet(address payable _foundationWallet)
        public
        onlyOwner
    {
        require(
            foundationWallet == _foundationWallet,
            "QNFT: same foundation wallet"
        );

        foundationWallet = _foundationWallet;

        emit SetFoundationWallet(msg.sender, _foundationWallet);
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
        qstkBalances[to] = qstkBalances[to].add(qstkAmount);
        qstkBalances[from] = qstkBalances[from].sub(qstkAmount);

        IQNFTGov(governance).updateVoteAmount(msg.sender, qstkAmount, 0);
        IQNFTGov(governance).updateVoteAmount(to, 0, qstkAmount);
    }
}