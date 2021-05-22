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
    event SetNonTokenPriceMultiplier(uint256 nonTokenPriceMultiplier);
    event SetTokenPriceMultiplier(uint256 tokenPriceMultiplier);
    event SetUpgradePriceMultiplier(uint256 upgradePriceMultiplier);
    event AddLockOption(
        uint256 minAmount,
        uint256 maxAmount,
        uint256 lockDuration,
        uint8 discount // percent
    );
    event UpdateLockOption(
        uint32 indexed lockOptionId,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 lockDuration,
        uint8 discount // percent
    );
    event AddCharacters(uint256[] prices, uint256 maxSupply);
    event UpdateCharacterPrice(uint32 indexed characterId, uint256 price);
    event UpdateCharacterPrices(
        uint32 startIndex,
        uint32 length,
        uint256 price
    );
    event UpdateCharacterPricesFromArray(uint32[] indexes, uint256[] prices);
    event UpdateCharacterMaxSupply(
        uint32 indexed characterId,
        uint256 maxSupply
    );
    event UpdateCharacterMaxSupplies(
        uint32 startIndex,
        uint32 length,
        uint256 supply
    );
    event UpdateCharacterMaxSuppliesFromArray(
        uint32[] indexes,
        uint256[] supplies
    );
    event AddFavCoinPrices(uint256[] mintPrices);
    event UpdateFavCoinPrice(uint32 favCoinId, uint256 price);
    event StartMint(uint256 startedAt);
    event PauseMint(uint256 pausedAt);
    event UnpauseMint(uint256 unPausedAt);

    // constants
    uint256 public constant PERCENT_MAX = 100;
    uint256 public constant NFT_SALE_DURATION = 1209600; // 2 weeks

    // mint options set
    uint256 public qstkPrice; // qstk price
    uint256 public nonTokenPriceMultiplier; // percentage - should be multiplied to non token price - image + favorite coin
    uint256 public tokenPriceMultiplier; // percentage - should be multiplied to token price - qstk
    uint256 public override upgradePriceMultiplier; // percentage - should be multiplied to coin mint price - favorite coin - used for favorite coin upgrade price calculation

    LockOption[] public lockOptions; // array of lock options
    uint256[] private _characterPrices; // array of character purchase prices
    uint256[] private _characterMaxSupply; // limitation count for the given character
    uint256[] private _favCoinPrices; // array of favorite coin purchase prices

    // mint options set
    uint256 public override mintStartTime;
    bool public override mintStarted;
    bool public override mintPaused;
    bool public override onlyAirdropUsers;

    // By default, transfer is not allowed for redeemed NFTs to prevent spam sell. Users can transfer redeemed NFTS after this flag is enabled.
    bool public override transferAllowedAfterRedeem;

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
        upgradePriceMultiplier = PERCENT_MAX; // upgrade price multiplier = 1000%;
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
    function lockOptionLockDuration(uint32 _lockOptionId)
        external
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
    ) external onlyManager {
        require(_discount < PERCENT_MAX, "QNFTSettings: invalid discount");
        lockOptions.push(
            LockOption(_minAmount, _maxAmount, _lockDuration, _discount)
        );

        emit AddLockOption(_minAmount, _maxAmount, _lockDuration, _discount);
    }

    /**
     * @dev update a lock option
     */
    function updateLockOption(
        uint32 _lockOptionId,
        uint256 _minAmount,
        uint256 _maxAmount,
        uint256 _lockDuration,
        uint8 _discount
    ) external onlyManager {
        uint256 length = lockOptions.length;
        require(length > _lockOptionId, "QNFTSettings: invalid lock option id");

        lockOptions[_lockOptionId] = LockOption(
            _minAmount,
            _maxAmount,
            _lockDuration,
            _discount
        );

        emit UpdateLockOption(
            _lockOptionId,
            _minAmount,
            _maxAmount,
            _lockDuration,
            _discount
        );
    }

    function characterPrices(uint32 _characterId)
        external
        view
        override
        returns (uint256)
    {
        return _characterPrices[_characterId];
    }

    /**
     * @dev returns the count of nft characters
     */
    function characterCount() public view override returns (uint256) {
        return _characterPrices.length;
    }

    /**
     * @dev adds new character mint prices/max supplies
     */
    function addCharacters(uint256[] memory _prices, uint256 _maxSupply)
        external
        onlyManager
    {
        uint256 length = _prices.length;

        for (uint256 i = 0; i < length; i++) {
            _characterPrices.push(_prices[i]);
            _characterMaxSupply.push(_maxSupply);
        }

        emit AddCharacters(_prices, _maxSupply);
    }

    /**
     * @dev updates a nft character
     */
    function updateCharacterPrice(uint32 _characterId, uint256 _price)
        external
        onlyManager
    {
        uint256 length = _characterPrices.length;
        require(length > _characterId, "QNFTSettings: invalid character id");

        _characterPrices[_characterId] = _price;

        emit UpdateCharacterPrice(_characterId, _price);
    }

    /**
     * @dev updates multiple character prices
     */
    function updateCharacterPrices(
        uint32 _startIndex,
        uint32 _length,
        uint256 _price
    ) external onlyManager {
        require(
            _characterPrices.length > uint256(_startIndex) + uint256(_length),
            "QNFTSettings: invalid character id"
        );

        for (uint256 i = 0; i < _length; i++) {
            _characterPrices[uint256(_startIndex) + i] = _price;
        }

        emit UpdateCharacterPrices(_startIndex, _length, _price);
    }

    /**
     * @dev updates multiple character prices
     */
    function updateCharacterPricesFromArray(
        uint32[] memory _indexes,
        uint256[] memory _prices
    ) external onlyManager {
        uint256 indexLength = _indexes.length;
        require(
            indexLength > _prices.length,
            "QNFTSettings: length doesn't match"
        );

        uint256 length = _characterPrices.length;

        for (uint256 i = 0; i < indexLength; i++) {
            require(_indexes[i] < length, "QNFTSettings: invalid index");
            _characterPrices[_indexes[i]] = _prices[i];
        }

        emit UpdateCharacterPricesFromArray(_indexes, _prices);
    }

    function characterMaxSupply(uint32 _characterId)
        external
        view
        override
        returns (uint256)
    {
        return _characterMaxSupply[_characterId];
    }

    /**
     * @dev updates a nft character
     */
    function updateCharacterMaxSupply(uint32 _characterId, uint256 _maxSupply)
        external
        onlyManager
    {
        uint256 length = _characterMaxSupply.length;
        require(length > _characterId, "QNFTSettings: invalid character id");

        _characterMaxSupply[_characterId] = _maxSupply;

        emit UpdateCharacterMaxSupply(_characterId, _maxSupply);
    }

    /**
     * @dev updates multiple character max supplies
     */
    function updateCharacterMaxSupplies(
        uint32 _startIndex,
        uint32 _length,
        uint256 _supply
    ) external onlyManager {
        require(
            _characterMaxSupply.length >
                uint256(_startIndex) + uint256(_length),
            "QNFTSettings: invalid character id"
        );

        for (uint256 i = 0; i < _length; i++) {
            _characterMaxSupply[uint256(_startIndex) + i] = _supply;
        }

        emit UpdateCharacterMaxSupplies(_startIndex, _length, _supply);
    }

    /**
     * @dev updates multiple character max supplies
     */
    function updateCharacterMaxSuppliesFromArray(
        uint32[] memory _indexes,
        uint256[] memory _supplies
    ) external onlyManager {
        uint256 indexLength = _indexes.length;
        require(
            indexLength > _supplies.length,
            "QNFTSettings: length doesn't match"
        );

        uint256 length = _characterMaxSupply.length;

        for (uint256 i = 0; i < indexLength; i++) {
            require(_indexes[i] < length, "QNFTSettings: invalid index");
            _characterMaxSupply[_indexes[i]] = _supplies[i];
        }

        emit UpdateCharacterMaxSuppliesFromArray(_indexes, _supplies);
    }

    function favCoinPrices(uint32 _favCoinId)
        external
        view
        override
        returns (uint256)
    {
        return _favCoinPrices[_favCoinId];
    }

    /**
     * @dev returns the count of favorite coins
     */
    function favCoinsCount() public view override returns (uint256) {
        return _favCoinPrices.length;
    }

    /**
     * @dev adds a new favorite coin
     */
    function addFavCoinPrices(uint256[] memory _prices) external onlyManager {
        uint256 length = _prices.length;
        for (uint16 i = 0; i < length; i++) {
            _favCoinPrices.push(_prices[i]);
        }

        emit AddFavCoinPrices(_prices);
    }

    /**
     * @dev updates a favorite coin
     */
    function updateFavCoinPrice(uint32 _favCoinId, uint256 _price)
        external
        onlyManager
    {
        uint256 length = _favCoinPrices.length;
        require(length > _favCoinId, "QNFTSettings: invalid id");

        _favCoinPrices[_favCoinId] = _price;

        emit UpdateFavCoinPrice(_favCoinId, _price);
    }

    /**
     * @dev calculate mint price of given mint options
     */
    function calcMintPrice(
        uint32 _characterId,
        uint32 _favCoinId,
        uint32 _lockOptionId,
        uint256 _lockAmount,
        uint256 _freeAmount
    )
        external
        view
        override
        returns (
            uint256 totalPrice,
            uint256 tokenPrice,
            uint256 nonTokenPrice
        )
    {
        require(
            characterCount() > _characterId,
            "QNFTSettings: invalid character option"
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

        // mintPrice = qstkPrice * lockAmount * discountRate * tokenPriceMultiplier + (characterMintPrice + favCoinMintPrice) * nonTokenPriceMultiplier

        uint256 decimal = IERC20MetadataUpgradeable(settings.qstk()).decimals();
        tokenPrice =
            (qstkPrice *
                _lockAmount *
                (PERCENT_MAX - uint256(lockOption.discount))) /
            (10**decimal) /
            PERCENT_MAX;
        tokenPrice = (tokenPrice * tokenPriceMultiplier) / PERCENT_MAX;

        nonTokenPrice =
            _characterPrices[_characterId] +
            _favCoinPrices[_favCoinId];
        nonTokenPrice = (nonTokenPrice * nonTokenPriceMultiplier) / PERCENT_MAX;

        totalPrice = tokenPrice + nonTokenPrice;
    }

    /**
     * @dev sets token price multiplier - qstk
     */
    function setTokenPriceMultiplier(uint256 _tokenPriceMultiplier)
        external
        onlyManager
    {
        tokenPriceMultiplier = _tokenPriceMultiplier;

        emit SetTokenPriceMultiplier(tokenPriceMultiplier);
    }

    /**
     * @dev sets non token price multiplier - character + favorite coins
     */
    function setNonTokenPriceMultiplier(uint256 _nonTokenPriceMultiplier)
        external
        onlyManager
    {
        nonTokenPriceMultiplier = _nonTokenPriceMultiplier;

        emit SetNonTokenPriceMultiplier(nonTokenPriceMultiplier);
    }

    /**
     * @dev sets upgrade price multiplier for favorite coins
     */
    function setUpgradePriceMultiplier(uint256 _upgradePriceMultiplier)
        external
        onlyManager
    {
        upgradePriceMultiplier = _upgradePriceMultiplier;

        emit SetUpgradePriceMultiplier(upgradePriceMultiplier);
    }

    /**
     * @dev starts/restarts mint process
     */
    function startMint() external onlyManager {
        require(!mintStarted || mintFinished(), "QNFT: mint in progress");

        mintStarted = true;
        mintStartTime = block.timestamp;
        mintPaused = false;

        emit StartMint(mintStartTime);
    }

    /**
     * @dev pause mint process
     */
    function pauseMint() external onlyManager {
        require(
            mintStarted == true && !mintFinished(),
            "QNFT: mint not in progress"
        );
        require(mintPaused == false, "QNFT: mint already paused");

        mintPaused = true;

        emit PauseMint(block.timestamp);
    }

    /**
     * @dev unpause mint process
     */
    function unPauseMint() external onlyManager {
        require(
            mintStarted == true && !mintFinished(),
            "QNFT: mint not in progress"
        );
        require(mintPaused == true, "QNFT: mint not paused");

        mintPaused = false;

        emit UnpauseMint(block.timestamp);
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

    function setOnlyAirdropUsers(bool _onlyAirdropUsers) external onlyManager {
        onlyAirdropUsers = _onlyAirdropUsers;
    }

    function setTransferAllowedAfterRedeem(bool _allow) external onlyManager {
        transferAllowedAfterRedeem = _allow;
    }

    uint256[50] private __gap;
}