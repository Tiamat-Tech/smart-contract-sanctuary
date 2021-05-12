// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import "../interface/structs.sol";
import "../interface/IQStk.sol";
import "../interface/IQNFT.sol";
import "../interface/IQNFTSettings.sol";

/**
 * @author fantasy
 */
contract QNFTSettings is OwnableUpgradeable, IQNFTSettings {
    using SafeMathUpgradeable for uint256;

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
        uint256 indexed lockDuration,
        uint256 discount // percent
    );
    event RemoveLockOption(address indexed owner, uint256 indexed lockOptionId);
    event AddImageSets(
        address indexed owner,
        uint256[] mintPrices,
        address[] designers,
        string[] dataUrls
    );
    event RemoveImageSet(address indexed owner, uint256 indexed nftImageId);
    event AddBgImages(address indexed owner, string[] dataUrls);
    event RemoveBgImage(address indexed owner, uint256 indexed bgImageId);
    event AddFavCoins(
        address indexed owner,
        uint256[] mintPrices,
        string[] dataUrls
    );
    event RemoveFavCoin(address indexed owner, uint256 favCoinId);

    // constants
    uint256 public constant EMOTION_COUNT_PER_NFT = 5;
    uint256 public constant BACKGROUND_IMAGE_COUNT = 4;
    uint256 public constant ARROW_IMAGE_COUNT = 3;
    uint256 public constant PERCENT_MAX = 100;

    // mint options set
    uint256 public qstkPrice; // qstk price
    uint256 public nonTokenPriceMultiplier; // percentage - should be multiplied to non token price - image + coin
    uint256 public tokenPriceMultiplier; // percentage - should be multiplied to token price - qstk

    LockOption[] public lockOptions; // array of lock options
    string[] public bgImages; // array of background image data urls
    NFTImage[] public nftImages; // array of nft images
    NFTFavCoin[] public favCoins; // array of favorite coins

    IQNFT public qnft; // QNFT contract address

    function initialize() external initializer {
        __Ownable_init();
        qstkPrice = 0.00001 ether; // qstk price = 0.00001 ether
        nonTokenPriceMultiplier = PERCENT_MAX; // non token price multiplier = 100%;
        tokenPriceMultiplier = PERCENT_MAX; // token price multiplier = 100%;
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
        uint256 _discount
    ) public onlyOwner {
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
     * @dev remove a lock option
     */
    function removeLockOption(uint256 _lockOptionId) public onlyOwner {
        require(
            qnft.mintStarted() == false,
            "QNFTSettings: mint already started"
        );

        uint256 length = lockOptions.length;
        require(length > _lockOptionId, "QNFTSettings: invalid lock option id");

        lockOptions[_lockOptionId] = lockOptions[length - 1];
        lockOptions.pop();

        emit RemoveLockOption(msg.sender, _lockOptionId);
    }

    /**
     * @dev returns the count of nft images sets
     */
    function nftImagesCount() public view override returns (uint256) {
        return nftImages.length;
    }

    /**
     * @dev returns the mint price of given nft image id
     */
    function nftImageMintPrice(uint256 _nftImageId)
        public
        view
        override
        returns (uint256)
    {
        require(
            _nftImageId < nftImages.length,
            "QNFTSettings: invalid image id"
        );
        return nftImages[_nftImageId].mintPrice;
    }

    /**
     * @dev adds a new nft iamges set
     */
    function addImageSets(
        uint256[] memory _mintPrices,
        address[] memory _designers,
        string[] memory _dataUrls
    ) public onlyOwner {
        uint256 length = _mintPrices.length;
        require(
            length > 0 &&
                length == _designers.length &&
                length == _dataUrls.length,
            "QNFTSettings: invalid arguments"
        );

        for (uint16 i = 0; i < length; i++) {
            nftImages.push(
                NFTImage(_mintPrices[i], _designers[i], _dataUrls[i])
            );
        }

        emit AddImageSets(msg.sender, _mintPrices, _designers, _dataUrls);
    }

    /**
     * @dev removes a nft images set
     */
    function removeImageSet(uint256 _nftImageId) public onlyOwner {
        require(
            qnft.mintStarted() == false,
            "QNFTSettings: mint already started"
        );

        uint256 length = nftImages.length;
        require(length > _nftImageId, "QNFTSettings: invalid id");

        nftImages[_nftImageId] = nftImages[length - 1];
        nftImages.pop();

        emit RemoveImageSet(msg.sender, _nftImageId);
    }

    /**
     * @dev returns the count of background images
     */
    function bgImagesCount() public view override returns (uint256) {
        return bgImages.length;
    }

    /**
     * @dev adds a new background image
     */
    function addBgImages(string[] memory _dataUrls) public onlyOwner {
        uint256 length = _dataUrls.length;
        require(length > 0, "QNFTSettings: no data");

        for (uint16 i = 0; i < length; i++) {
            bgImages.push(_dataUrls[i]);
        }

        emit AddBgImages(msg.sender, _dataUrls);
    }

    /**
     * @dev removes a background image
     */
    function removeBgImage(uint256 _bgImageId) public onlyOwner {
        require(
            qnft.mintStarted() == false,
            "QNFTSettings: mint already started"
        );

        uint256 length = bgImages.length;
        require(length > _bgImageId, "QNFTSettings: invalid id");

        bgImages[_bgImageId] = bgImages[length - 1];
        bgImages.pop();

        emit RemoveBgImage(msg.sender, _bgImageId);
    }

    /**
     * @dev returns the count of favorite coins
     */
    function favCoinsCount() public view override returns (uint256) {
        return favCoins.length;
    }

    /**
     * @dev returns the mint price of given favorite coin
     */
    function favCoinMintPrice(uint256 _favCoinId)
        public
        view
        override
        returns (uint256)
    {
        require(
            _favCoinId < favCoins.length,
            "QNFTSettings: invalid favcoin id"
        );

        return favCoins[_favCoinId].mintPrice;
    }

    /**
     * @dev adds a new favorite coin
     */
    function addFavCoins(
        uint256[] memory _mintPrices,
        string[] memory _dataUrls
    ) public onlyOwner {
        uint256 length = _mintPrices.length;
        require(
            length > 0 && length == _dataUrls.length,
            "QNFTSettings: invalid arguments"
        );

        for (uint16 i = 0; i < length; i++) {
            favCoins.push(NFTFavCoin(_mintPrices[i], _dataUrls[i]));
        }

        emit AddFavCoins(msg.sender, _mintPrices, _dataUrls);
    }

    /**
     * @dev removes a favorite coin
     */
    function removeFavCoin(uint256 _favCoinId) public onlyOwner {
        require(
            qnft.mintStarted() == false,
            "QNFTSettings: mint already started"
        );

        uint256 length = favCoins.length;
        require(length > _favCoinId, "QNFTSettings: invalid id");

        favCoins[_favCoinId] = favCoins[length - 1];
        favCoins.pop();

        emit RemoveFavCoin(msg.sender, _favCoinId);
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
        require(
            nftImages.length > _imageId,
            "QNFTSettings: invalid image option"
        );
        require(
            bgImages.length > _bgImageId,
            "QNFTSettings: invalid background option"
        );
        require(
            lockOptions.length > _lockOptionId,
            "QNFTSettings: invalid lock option"
        );

        LockOption memory lockOption = lockOptions[_lockOptionId];

        require(
            lockOption.minAmount <= _lockAmount + _freeAmount &&
                _lockAmount <= lockOption.maxAmount,
            "QNFTSettings: invalid mint amount"
        );
        require(favCoins.length > _favCoinId, "QNFTSettings: invalid fav coin");

        // mintPrice = qstkPrice * lockAmount * discountRate * tokenPriceMultiplier + (imageMintPrice + favCoinMintPrice) * nonTokenPriceMultiplier

        uint256 decimal = IQStk(qnft.qstk()).decimals();
        uint256 tokenPrice =
            qstkPrice
                .mul(_lockAmount)
                .mul(uint256(PERCENT_MAX).sub(lockOption.discount))
                .div(10**decimal)
                .div(PERCENT_MAX);
        tokenPrice = tokenPrice.mul(tokenPriceMultiplier).div(PERCENT_MAX);

        uint256 nonTokenPrice =
            nftImages[_imageId].mintPrice.add(favCoins[_favCoinId].mintPrice);
        nonTokenPrice = nonTokenPrice.mul(nonTokenPriceMultiplier).div(
            PERCENT_MAX
        );

        return tokenPrice.add(nonTokenPrice);
    }

    /**
     * @dev sets QNFT contract address
     */
    function setQNft(IQNFT _qnft) public onlyOwner {
        require(qnft != _qnft, "QNFTSettings: QNFT already set");

        qnft = _qnft;
    }

    /**
     * @dev sets token price multiplier - qstk
     */
    function setTokenPriceMultiplier(uint256 _tokenPriceMultiplier)
        public
        onlyOwner
    {
        tokenPriceMultiplier = _tokenPriceMultiplier;

        emit SetTokenPriceMultiplier(msg.sender, tokenPriceMultiplier);
    }

    /**
     * @dev sets non token price multiplier - image + coins
     */
    function setNonTokenPriceMultiplier(uint256 _nonTokenPriceMultiplier)
        public
        onlyOwner
    {
        nonTokenPriceMultiplier = _nonTokenPriceMultiplier;

        emit SetNonTokenPriceMultiplier(msg.sender, nonTokenPriceMultiplier);
    }
}