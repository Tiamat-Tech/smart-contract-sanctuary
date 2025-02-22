// SPDX-License-Identifier: LGPL-3.0-or-newer
pragma solidity >=0.6.8;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/IAuctionLauncher.sol";
import "../libraries/TransferHelper.sol";
import "../interfaces/IMesaFactory.sol";
import "../interfaces/IWETH.sol";

interface IAuction {
    function initAuction(
        IERC20 _auctioningToken,
        IERC20 _biddingToken,
        uint256 _orderCancelationPeriodDuration,
        uint96 _amountToSell,
        uint96 _minBidAmountToReceive,
        uint256 _minimumBiddingAmountPerOrder,
        uint256 _minFundingThreshold,
        uint256 _gracePeriodStartDuration,
        uint256 _gracePeriodDuration,
        bool _isAtomicClosureAllowed
    ) external;
}

contract EasyAuctionTemplate {
    using SafeMath for uint256;

    IAuction public auction;
    IWETH public WETH;
    IAuctionLauncher public auctionLauncher;
    IMesaFactory public mesaFactory;
    uint256 public auctionTemplateId;
    bool initialized = false;

    event TemplateInitialized(
        address tokenOut,
        address tokenIn,
        uint256 duration,
        uint256 tokenOutSupply,
        uint96 minPrice,
        uint96 minBuyAmount,
        uint256 minRaise
    );

    constructor(
        address _WETH,
        address _auctionLauncher,
        uint256 _auctionTemplateId
    ) public {
        WETH = IWETH(_WETH);
        auctionLauncher = IAuctionLauncher(_auctionLauncher);
        mesaFactory = IMesaFactory(
            IAuctionLauncher(_auctionLauncher).factory()
        );
        auctionTemplateId = _auctionTemplateId;
    }

    /// @dev internal setup function to initialize the template, called by init()
    /// @param _tokenOut token to be auctioned
    /// @param _tokenIn token to bid on auction
    /// @param _duration auction duration in seconds
    /// @param _tokenOutSupply amount of tokens to be auctioned
    /// @param _minPrice minimum Price that token should be auctioned for
    /// @param _minBuyAmount minimum amount of tokens an investor has to buy
    /// @param _minRaise minimum amount an IDO is expected to raise
    /// @param _tokenSupplier address that deposits the tokens
    function initTemplate(
        address _tokenOut,
        address _tokenIn,
        uint256 _duration,
        uint256 _tokenOutSupply,
        uint96 _minPrice,
        uint96 _minBuyAmount,
        uint256 _minRaise,
        address _tokenSupplier
    ) internal returns (address newAuction) {
        require(!initialized, "EasyAuctionTemplate: ALEADY_INITIALIZED");

        uint256 orderCancelationPeriodDuration = 100;
        uint256 minimumBiddingAmountPerOrder = 100;
        bool isAtomicClosureAllowed = false;

        bytes memory encodedInitData =
            abi.encode(
                _tokenOut,
                _tokenIn,
                orderCancelationPeriodDuration,
                _duration,
                _tokenOutSupply,
                _minBuyAmount,
                minimumBiddingAmountPerOrder,
                _minRaise,
                isAtomicClosureAllowed
            );

        uint256 depositAmount =
            auctionLauncher.getDepositAmountWithFees(_tokenOutSupply);

        initialized = true;

        // deposits sellAmount + fees
        TransferHelper.safeTransferFrom(
            _tokenOut,
            _tokenSupplier,
            address(this),
            depositAmount
        );

        // approve deposited tokens on auctionLauncher
        TransferHelper.safeApprove(
            _tokenOut,
            address(auctionLauncher),
            depositAmount
        );

        // deploys & initializes new auction

        /*
        newAuction = auctionLauncher.createAuction(
            auctionTemplateId,
            _tokenOut,
            _tokenOutSupply,
            encodedInitData
        );
        */

        emit TemplateInitialized(
            _tokenOut,
            _tokenIn,
            _duration,
            _tokenOutSupply,
            _minPrice,
            _minBuyAmount,
            _minRaise
        );
    }

    /// @dev setup function expexted to be called by templateLauncher to init the template
    /// @param _data encoded template params
    function init(bytes calldata _data) public returns (address newAuction) {
        (
            address _tokenOut,
            address _tokenIn,
            uint256 _duration,
            uint256 _tokenOutSupply,
            uint96 _minPrice,
            uint96 _minBuyAmount,
            uint256 _minRaise,
            address _tokenSupplier
        ) =
            abi.decode(
                _data,
                (
                    address,
                    address,
                    uint256,
                    uint256,
                    uint96,
                    uint96,
                    uint256,
                    address
                )
            );

        return
            initTemplate(
                _tokenOut,
                _tokenIn,
                _duration,
                _tokenOutSupply,
                _minPrice,
                _minBuyAmount,
                _minRaise,
                _tokenSupplier
            );
    }
}