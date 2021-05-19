// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import "../interface/structs.sol";
import "../interface/IQNFTSettings.sol";
import "../interface/IQSettings.sol";

/**
 * @author fantasy
 */
contract QNFTSettings is IQNFTSettings, ContextUpgradeable {
    // events
    event SetNonTokenPriceMultiplier(
        address indexed owner,
        uint256 nonTokenPriceMultiplier
    );
    event SetTokenPriceMultiplier(
        address indexed owner,
        uint256 tokenPriceMultiplier
    );
    event AddLockOption(
        address indexed owner,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 lockDuration,
        uint256 discount // percent
    );
    event UpdateLockOption(
        address indexed owner,
        uint256 indexed lockOptionId,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 lockDuration,
        uint256 discount // percent
    );
    event AddImagePrices(address indexed owner, uint256[] prices);
    event UpdateImagePrice(
        address indexed owner,
        uint256 indexed imageId,
        uint256 price
    );
    event AddFavCoinPrices(address indexed owner, uint256[] mintPrices);
    event UpdateFavCoinPrice(
        address indexed owner,
        uint256 favCoinId,
        uint256 price
    );
    event StartMint(address indexed owner, uint256 startedAt);
    event PauseMint(address indexed owner, uint256 pausedAt);
    event UnpauseMint(address indexed owner, uint256 unPausedAt);

    // constants
    uint256 public constant PERCENT_MAX = 100;
    uint256 public constant NFT_SALE_DURATION = 1209600; // 2 weeks

    // mint options set
    uint256 public qstkPrice; // qstk price
    uint256 public nonTokenPriceMultiplier; // percentage - should be multiplied to non token price - image + coin
    uint256 public tokenPriceMultiplier; // percentage - should be multiplied to token price - qstk

    LockOption[] public lockOptions; // array of lock options
    uint16 public override bgImageCount; // count of background images
    uint256[] public override imagePrices; // array of image purchase prices
    uint256[] public override favCoinPrices; // array of favorite coin purchase prices

    // mint options set
    bool public override onlyAirdropUsers;
    bool public override mintStarted;
    bool public override mintPaused;
    uint256 public override mintStartTime;

    IQSettings public settings; // QSettings contract address

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

    function initialize(address _settings) external initializer {
        __Context_init();
        qstkPrice = 0.00001 ether; // qstk price = 0.00001 ether
        nonTokenPriceMultiplier = PERCENT_MAX; // non token price multiplier = 100%;
        tokenPriceMultiplier = PERCENT_MAX; // token price multiplier = 100%;
        settings = IQSettings(_settings);
        onlyAirdropUsers = true;
    }

    /**
     * @dev returns the count of lock options
     */
    function lockOptionsCount() public view override returns (uint256) {
        return lockOptions.length;
    }

    /**
     * @dev returns the lock duration of given lock option id
     */
    function lockOptionLockDuration(uint256 _lockOptionId)
        public
        view
        override
        returns (uint256)
    {
        require(
            _lockOptionId < lockOptions.length,
            "QNFTSettings: invalid lock option"
        );

        return lockOptions[_lockOptionId].lockDuration;
    }

    /**
     * @dev adds a new lock option
     */
    function addLockOption(
        uint256 _minAmount,
        uint256 _maxAmount,
        uint256 _lockDuration,
        uint8 _discount
    ) public onlyManager {
        require(_discount < PERCENT_MAX, "QNFTSettings: invalid discount");
        lockOptions.push(
            LockOption(_minAmount, _maxAmount, _lockDuration, _discount)
        );

        emit AddLockOption(
            msg.sender,
            _minAmount,
            _maxAmount,
            _lockDuration,
            _discount
        );
    }

    /**
     * @dev update a lock option
     */
    function updateLockOption(
        uint256 _lockOptionId,
        uint256 _minAmount,
        uint256 _maxAmount,
        uint256 _lockDuration,
        uint8 _discount
    ) public onlyManager {
        uint256 length = lockOptions.length;
        require(length > _lockOptionId, "QNFTSettings: invalid lock option id");

        lockOptions[_lockOptionId] = LockOption(
            _minAmount,
            _maxAmount,
            _lockDuration,
            _discount
        );

        emit UpdateLockOption(
            msg.sender,
            _lockOptionId,
            _minAmount,
            _maxAmount,
            _lockDuration,
            _discount
        );
    }

    /**
     * @dev sets background image count
     */
    function setBgImageCount(uint16 _bgImageCount) public onlyManager {
        bgImageCount = _bgImageCount;
    }

    /**
     * @dev returns the count of nft images sets
     */
    function imageCount() public view override returns (uint256) {
        return imagePrices.length;
    }

    /**
     * @dev adds a new nft iamges set
     */
    function addImagePrices(uint256[] memory _imagePrices) public onlyManager {
        uint256 length = _imagePrices.length;
        for (uint256 i = 0; i < length; i++) {
            imagePrices.push(_imagePrices[i]);
        }

        emit AddImagePrices(msg.sender, _imagePrices);
    }

    /**
     * @dev removes a nft images set
     */
    function updateImage(uint256 _imageId, uint256 _price) public onlyManager {
        uint256 length = imagePrices.length;
        require(length > _imageId, "QNFTSettings: invalid image id");

        imagePrices[_imageId] = _price;

        emit UpdateImagePrice(msg.sender, _imageId, _price);
    }

    /**
     * @dev returns the count of favorite coins
     */
    function favCoinsCount() public view override returns (uint256) {
        return favCoinPrices.length;
    }

    /**
     * @dev adds a new favorite coin
     */
    function addFavCoinPrices(uint256[] memory _favCoinPrices)
        public
        onlyManager
    {
        uint256 length = _favCoinPrices.length;
        for (uint16 i = 0; i < length; i++) {
            favCoinPrices.push(_favCoinPrices[i]);
        }

        emit AddFavCoinPrices(msg.sender, _favCoinPrices);
    }

    /**
     * @dev removes a favorite coin
     */
    function updateFavCoinPrice(uint256 _favCoinId, uint256 _price)
        public
        onlyManager
    {
        uint256 length = favCoinPrices.length;
        require(length > _favCoinId, "QNFTSettings: invalid id");

        favCoinPrices[_favCoinId] = _price;

        emit UpdateFavCoinPrice(msg.sender, _favCoinId, _price);
    }

    /**
     * @dev calculate mint price of given mint options
     */
    function calcMintPrice(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _lockOptionId,
        uint256 _lockAmount,
        uint256 _freeAmount
    ) public view override returns (uint256) {
        require(imageCount() > _imageId, "QNFTSettings: invalid image option");
        require(
            bgImageCount > _bgImageId,
            "QNFTSettings: invalid background option"
        );
        require(
            lockOptionsCount() > _lockOptionId,
            "QNFTSettings: invalid lock option"
        );
        require(favCoinsCount() > _favCoinId, "QNFTSettings: invalid fav coin");

        LockOption memory lockOption = lockOptions[_lockOptionId];

        require(
            lockOption.minAmount <= _lockAmount + _freeAmount &&
                _lockAmount <= lockOption.maxAmount,
            "QNFTSettings: invalid mint amount"
        );

        // mintPrice = qstkPrice * lockAmount * discountRate * tokenPriceMultiplier + (imageMintPrice + favCoinMintPrice) * nonTokenPriceMultiplier

        uint256 decimal = IERC20MetadataUpgradeable(settings.qstk()).decimals();
        uint256 tokenPrice =
            (qstkPrice *
                _lockAmount *
                (uint256(PERCENT_MAX) - lockOption.discount)) /
                (10**decimal) /
                PERCENT_MAX;
        tokenPrice = (tokenPrice * tokenPriceMultiplier) / PERCENT_MAX;

        uint256 nonTokenPrice =
            imagePrices[_imageId] + favCoinPrices[_favCoinId];
        nonTokenPrice = (nonTokenPrice * nonTokenPriceMultiplier) / PERCENT_MAX;

        return tokenPrice + nonTokenPrice;
    }

    /**
     * @dev sets token price multiplier - qstk
     */
    function setTokenPriceMultiplier(uint256 _tokenPriceMultiplier)
        public
        onlyManager
    {
        tokenPriceMultiplier = _tokenPriceMultiplier;

        emit SetTokenPriceMultiplier(msg.sender, tokenPriceMultiplier);
    }

    /**
     * @dev sets non token price multiplier - image + coins
     */
    function setNonTokenPriceMultiplier(uint256 _nonTokenPriceMultiplier)
        public
        onlyManager
    {
        nonTokenPriceMultiplier = _nonTokenPriceMultiplier;

        emit SetNonTokenPriceMultiplier(msg.sender, nonTokenPriceMultiplier);
    }

    /**
     * @dev starts/restarts mint process
     */
    function startMint() public onlyManager {
        require(!mintStarted || mintFinished(), "QNFT: mint in progress");

        mintStarted = true;
        mintStartTime = block.timestamp;
        mintPaused = false;

        emit StartMint(msg.sender, mintStartTime);
    }

    /**
     * @dev pause mint process
     */
    function pauseMint() public onlyManager {
        require(
            mintStarted == true && !mintFinished(),
            "QNFT: mint not in progress"
        );
        require(mintPaused == false, "QNFT: mint already paused");

        mintPaused = true;

        emit PauseMint(msg.sender, block.timestamp);
    }

    /**
     * @dev unpause mint process
     */
    function unPauseMint() public onlyManager {
        require(
            mintStarted == true && !mintFinished(),
            "QNFT: mint not in progress"
        );
        require(mintPaused == true, "QNFT: mint not paused");

        mintPaused = false;

        emit UnpauseMint(msg.sender, block.timestamp);
    }

    /**
     * @dev returns the mint end time
     */
    function mintEndTime() public view override returns (uint256) {
        return mintStartTime + NFT_SALE_DURATION;
    }

    /**
     * @dev checks if mint process is finished
     */
    function mintFinished() public view override returns (bool) {
        return mintStarted && mintEndTime() <= block.timestamp;
    }

    function setOnlyAirdropUsers(bool _onlyAirdropUsers) public onlyManager {
        onlyAirdropUsers = _onlyAirdropUsers;
    }
}