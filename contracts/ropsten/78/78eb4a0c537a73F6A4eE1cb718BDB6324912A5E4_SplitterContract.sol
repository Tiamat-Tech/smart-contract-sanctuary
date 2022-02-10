// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract SplitterContract is OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public admin;
    address public rkMarket;
    address public router;
    address public weth;
    address public usdc;
    address[] public path;
    uint256 public constant SELLER_SHARE = 90;
    mapping(address => bool) public otherMarkets;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier onlyMarket() {
        require(
            msg.sender == rkMarket || otherMarkets[msg.sender],
            "Only rkMarket can call this function"
        );
        _;
    }

    struct ArtistDistribution {
        address[] addresses;
        uint256[] shares;
    }

    mapping(address => ArtistDistribution) private primaryArtistDistribution;
    mapping(address => ArtistDistribution) private secondaryArtistDistribution;

    event SetPrimaryDistribution(
        address artist,
        address[] companies,
        uint256[] shares
    );
    event SetSecondaryDistribution(
        address artist,
        address[] companies,
        uint256[] shares
    );
    event PrimaryDistribution(
        address artist,
        uint256 price,
        address[] companies,
        uint256[] shares
    );
    event SecondaryDistribution(
        address artist,
        uint256 price,
        address[] companies,
        uint256[] shares
    );
    event NewAdmin(address newAdmin);
    event NewMarket(address newMarket);
    event NewRouter(address newRouter);
    event NewPath(address[] newPath);
    event NewWETH(address newWETH);
    event NewUSDC(address newUSDC);

    uint256 public shareDecimals;

    /// @notice Acts like constructor() for upgradeable contracts
    function initialize(
        address _admin,
        address _rkMarket,
        address _router,
        address[] memory _path
    ) public initializer {
        __Ownable_init();
        admin = _admin;
        rkMarket = _rkMarket;
        router = _router;
        path = _path;
        weth = _path[0];
        usdc = _path[1];
        shareDecimals = 100;
    }

    /**
     * @dev Admin address setter
     */
    function setAdmin(address newAdmin) external onlyOwner {
        require(newAdmin != address(0), "wrong address");
        admin = newAdmin;

        emit NewAdmin(newAdmin);
    }

    /**
     * @dev rkMarket address setter
     */
    function setRKMarket(address newMarket) external onlyOwner {
        require(newMarket != address(0), "wrong address");
        rkMarket = newMarket;

        emit NewMarket(newMarket);
    }

    /**
     * @dev Add new market
     */
    function addMarket(address newMarket) external onlyOwner {
        require(newMarket != address(0), "wrong address");
        otherMarkets[newMarket] = true;

        emit NewMarket(newMarket);
    }

    /**
     * @dev Uniswap router address setter
     */
    function setRouter(address _router) external onlyOwner {
        require(_router != address(0), "wrong address");
        router = _router;

        emit NewRouter(_router);
    }

    /**
     * @dev Tokens swap path setter for the uniswap interface
     */
    function setPath(address[] calldata _path) external onlyOwner {
        require(
            _path[0] != address(0) && _path[1] != address(0),
            "wrong address"
        );
        path = _path;

        emit NewPath(_path);
    }

    /**
     * @dev WETH address setter
     */
    function setWETH(address _weth) external onlyOwner {
        require(_weth != address(0), "wrong address");
        weth = _weth;

        emit NewWETH(_weth);
    }

    /**
     * @dev USDC address setter
     */
    function setUSDC(address _usdc) external onlyOwner {
        require(_usdc != address(0), "wrong address");
        usdc = _usdc;

        emit NewUSDC(_usdc);
    }

    /**
     * @dev Getter function for distribution shares on primary market
     * @param artist - Artist address
     */
    function getPrimaryDistribution(address artist)
        external
        view
        returns (address[] memory addresses, uint256[] memory shares)
    {
        ArtistDistribution memory currentArtist = primaryArtistDistribution[
            artist
        ];
        addresses = currentArtist.addresses;
        shares = currentArtist.shares;
    }

    /**
     * @dev Getter function for distribution shares on secondary market
     * @param artist - Artist address
     */
    function getSecondaryDistribution(address artist)
        external
        view
        returns (address[] memory addresses, uint256[] memory shares)
    {
        ArtistDistribution memory currentArtist = secondaryArtistDistribution[
            artist
        ];
        addresses = currentArtist.addresses;
        shares = currentArtist.shares;
    }

    /**
     * @dev Setting primary and secondary market royalty distribution into mapping for target artist
     * @param primary_addresses - List of primary addresses for distribution
     * @param primary_shares - List of primary percentages for distribution
     * @param secondary_addresses - List of secondary addresses for distribution
     * @param secondary_shares - List of secondary percentages for distribution
     */
    function setDistribution(
        address artist,
        address[] calldata primary_addresses,
        uint256[] calldata primary_shares,
        address[] calldata secondary_addresses,
        uint256[] calldata secondary_shares
    ) external onlyAdmin {
        require(
            _getArraySum(primary_shares) <= 100 * shareDecimals,
            "wrong primary share distribution"
        );
        require(
            _getArraySum(secondary_shares) <= 10 * shareDecimals,
            "wrong secondary share distribution"
        );
        _setDistribution(artist, primary_addresses, primary_shares, true);
        _setDistribution(artist, secondary_addresses, secondary_shares, false);
    }

    /**
     * @dev Setting primary market royalty distribution into mapping for target artist
     * @param addresses - List of addresses for distribution
     * @param shares - List of percentages for distribution
     */
    function setPrimaryDistribution(
        address artist,
        address[] calldata addresses,
        uint256[] calldata shares
    ) external onlyAdmin {
        uint256 shareSum = _getArraySum(shares);
        require(shareSum <= 100 * shareDecimals, "wrong share distribution");
        _setDistribution(artist, addresses, shares, true);
    }

    /**
     * @dev Setting secondary market royalty distribution into mapping for target artist
     * @param addresses - List of addresses for distribution
     * @param shares - List of percentages for distribution
     */
    function setSecondaryDistribution(
        address artist,
        address[] calldata addresses,
        uint256[] calldata shares
    ) external onlyAdmin {
        uint256 shareSum = _getArraySum(shares);
        require(shareSum <= 10 * shareDecimals, "wrong share distribution");
        _setDistribution(artist, addresses, shares, false);
    }

    /**
     * @dev Setting distribution
     * @param addresses - List of addresses for distribution
     * @param shares - List of percentages for distribution
     * @param isPrimary - True to set primary, false for secondary
     */
    function _setDistribution(
        address artist,
        address[] calldata addresses,
        uint256[] calldata shares,
        bool isPrimary
    ) internal {
        require(artist != address(0), "zero address for artist");
        require(addresses.length == shares.length, "different array sizes");
        require(addresses.length > 0, "empty arrays");
        ArtistDistribution memory currentArtist = ArtistDistribution(
            addresses,
            shares
        );
        if (isPrimary) {
            primaryArtistDistribution[artist] = currentArtist;
            emit SetPrimaryDistribution(artist, addresses, shares);
        } else {
            secondaryArtistDistribution[artist] = currentArtist;
            emit SetSecondaryDistribution(artist, addresses, shares);
        }
    }

    /**
     * @dev Secondary market royalty distribution logic
     * @param artist - Artist of the token collection
     * @param amount - Token price in WEI
     */
    function primaryDistribution(address artist, uint256 amount)
        external
        onlyMarket
    {
        require(artist != address(0), "zero address for artist");
        require(amount > 0, "amount should be greater than 0");
        ArtistDistribution memory currentArtist = primaryArtistDistribution[
            artist
        ];
        uint256 usdAmountForDistribution = _swap(amount);

        for (uint256 i = 0; i < currentArtist.addresses.length; i++) {
            uint256 targetShare = (usdAmountForDistribution *
                currentArtist.shares[i]) /
                100 /
                shareDecimals;
            IERC20Upgradeable(usdc).safeTransfer(
                currentArtist.addresses[i],
                targetShare
            );
        }

        emit PrimaryDistribution(
            artist,
            amount,
            currentArtist.addresses,
            currentArtist.shares
        );
    }

    /**
     * @dev Secondary market royalty distribution logic
     * @param artist - Artist of the token collection
     * @param seller - Address who have placed sale order
     * @param amount - Token price in WEI
     */
    function secondaryDistribution(
        address artist,
        address seller,
        uint256 amount
    ) external onlyMarket {
        require(artist != address(0), "zero address for artist");
        require(amount > 0, "amount should be greater than 0");
        ArtistDistribution memory currentArtist = secondaryArtistDistribution[
            artist
        ];
        uint256 amountForSeller = (amount * SELLER_SHARE) / 100;
        IERC20Upgradeable(weth).safeTransfer(seller, amountForSeller);

        uint256 amountForDistribution = amount - amountForSeller;
        uint256 usdAmountForDistribution = _swap(amountForDistribution);

        for (uint256 i = 0; i < currentArtist.addresses.length; i++) {
            uint256 targetShare = (usdAmountForDistribution *
                currentArtist.shares[i]) /
                10 /
                shareDecimals;
            IERC20Upgradeable(usdc).safeTransfer(
                currentArtist.addresses[i],
                targetShare
            );
        }

        emit SecondaryDistribution(
            artist,
            amount,
            currentArtist.addresses,
            currentArtist.shares
        );
    }

    /**
     * @notice For stuck tokens rescue only
     */
    function rescueTokens(address _token) external onlyOwner {
        uint256 balance = IERC20Upgradeable(_token).balanceOf(address(this));
        IERC20Upgradeable(_token).safeTransfer(msg.sender, balance);
    }

    /**
     * @dev DEX interaction for tokens swap
     * @param amountIn - amount of input token to be swapped
     * @return uint256 - amount of output token after swap
     */
    function _swap(uint256 amountIn) internal returns (uint256) {
        IERC20Upgradeable(weth).safeApprove(router, amountIn);
        uint256[] memory amounts = IUniswapV2Router02(router)
            .swapExactTokensForTokens(
                amountIn,
                0,
                path,
                address(this),
                block.timestamp + 300
            );
        return amounts[1];
    }

    /**
     * @dev Function for array sum calculation
     * @param _array - array with uint256 elements
     */
    function _getArraySum(uint256[] calldata _array)
        internal
        pure
        returns (uint256 sum_)
    {
        sum_ = 0;
        for (uint256 i = 0; i < _array.length; i++) {
            sum_ += _array[i];
        }
    }

    /**
     * @dev Function setting share accuracy decimals
     * @param _decimals - new extra decimals for accuracy
     */
    function setFeeDecimals(uint256 _decimals) external onlyOwner {
        shareDecimals = _decimals;
    }
}