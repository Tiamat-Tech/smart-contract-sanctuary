pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "hardhat/console.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/UniswapV2Library.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IWETH.sol";

contract SpikeInuRouterV1 is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeMath for uint256;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "SpikeInuRouterV1: EXPIRED");
        _;
    }

    bool public isInitialized;
    bool public isMaintaining;
    address factory;
    address feeTo;
    uint256 feePercent;
    // id of random position form 1 to totalWhitelist;
    // mint amount in
    uint256 mintSwapAmount;
    mapping(address => bool) whitelistFactory;
    mapping(uint256 => address) chainFeeAddress;
    mapping(address => bool) whitelistStableTokens;
    mapping(address => address) routerToFactory;
    address chainGasAddress;

    IUniswapV2Router02 public uniswapV2Router;

    function initialize() public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
    }

    function inititalContract(
        address[] memory _stableTokens,
        address[] memory _routers,
        address[] memory _factories
    ) public onlyOwner {
        require(!isInitialized, "initialized");
        isInitialized = true;
        feePercent = 500; // = 0.5%, 100% = 100000
        uniswapV2Router = IUniswapV2Router02(
            // 0x5F277aE9379eA15E664FFb9Ea7d959b107521a78 // bscs spike pancake clone
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D // uniswap v2 ropsten
        );
        feeTo = address(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
        for (uint256 i; i < _stableTokens.length; i++) {
            whitelistStableTokens[_stableTokens[i]] = true;
        }
        for (uint256 i; i < _routers.length; i++) {
            routerToFactory[_routers[i]] = _factories[i];
        }
    }

    /**
     * @param swapParams[0] = from chain
     * @param swapParams[1] = to chain
     */
    function swapFromChainIn(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        uint256 deadline,
        address router,
        uint256[] calldata swapParams
    )
        external
        ensure(deadline)
        nonReentrant
        returns (uint256[] memory amounts)
    {}

    /**
     * @param swapParams[0] = from chain
     * @param swapParams[1] = to chain
     */
    function swapFromChainOut(
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        uint256 deadline,
        address router,
        uint256[] calldata swapParams
    )
        external
        ensure(deadline)
        nonReentrant
        returns (uint256[] memory amounts)
    {}

    /**
     * @param swapParams[0] = from chain
     * @param swapParams[1] = to chain
     */
    function swapEthFromChainIn(
        uint256 amountEthIn,
        uint256 amountOutMin,
        address[] memory path,
        uint256 deadline,
        address router,
        address wethAddress,
        uint256[2] calldata swapParams
    )
        external
        payable
        ensure(deadline)
        nonReentrant
        returns (uint256[] memory amounts)
    {}

    /**
     * ex1: USDT -> MATIC: bridge transfer usdt to UniRouter for swap MATIC
     * ex2: USDT -> BNB : bridge transfer usdt to UniRouter for swap BNB
     * ex3: USDT -> BNB -> KNC: bridge transfer usdt to UniRouter for swap KNC
     * @param amountIn: max amount can use for fee and swap
     * @param swapParams[0] = from chain
     * @param swapParams[1] = to chain
     */
    function swapToChainIn(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline,
        uint256[] calldata swapParams
    )
        external
        ensure(deadline)
        nonReentrant
        returns (uint256[] memory amounts)
    {}

    function _calculateFee(uint256 swapAmount)
        internal
        returns (uint256 feeAmount)
    {
        bool feeOn = feeTo != address(0);
        if (feeOn) {
            feeAmount = swapAmount.mul(feePercent).div(100000);
        }
        return feeAmount;
    }

    function _collectFee(
        uint256 chainId,
        address[] memory path,
        uint256 feeAmount,
        uint256 deadline
    ) internal {
        if (feeAmount > 0) {
            require(
                chainFeeAddress[chainId] != address(0),
                "FEE_ADDRESS_INVALID"
            );

            if (path[path.length - 1] == chainFeeAddress[chainId]) {
                TransferHelper.safeTransfer(
                    chainFeeAddress[chainId],
                    address(feeTo),
                    feeAmount
                );
            } else {
                // swap token to usd for collect fee.
                // address[] memory feePath = new address[](2);
                // feePath[0] = path[0];
                // feePath[1] = chainFeeAddress[chainId];
                // approve router can transfer amount of this contract
                // TransferHelper.safeApprove(
                //     path[0],
                //     address(uniswapV2Router),
                //     feeAmount
                // );
                // uint256[] memory amountsSwapResult = uniswapV2Router
                //     .swapTokensForExactTokens(
                //         amountOut,
                //         feeAmount,
                //         path,
                //         address(feeTo),
                //         deadline
                //     );
            }
        }
    }

    /**
     * @notice refund gas for sender when make cross chain swap
     */
    function refundGas(uint256 gasAmount, address fromToken) internal {
        address[] memory gasPath = new address[](2);
        gasPath[0] = fromToken;
        gasPath[1] = chainGasAddress;
        uint256[] memory amounts = UniswapV2Library.getAmountsIn(
            factory,
            gasAmount,
            gasPath
        );
        require(
            amounts[0] <= gasAmount.mul(105).div(100),
            "SpikeInuRouterV1: GAS_EXCESSIVE_INPUT_AMOUNT"
        );
        console.log("refundGas amounts in=", amounts[0]);
        console.log("refundGas amounts out=", amounts[1]);
        // transfer token A from user to this contract
        TransferHelper.safeTransferFrom(
            fromToken,
            _msgSender(),
            address(this),
            amounts[0]
        );

        // approve router can transfer amount of this contract
        TransferHelper.safeApprove(
            fromToken,
            address(uniswapV2Router),
            amounts[0]
        );
        // call swap router, send Gas to sender
        uniswapV2Router.swapTokensForExactTokens(
            gasAmount,
            gasAmount.mul(105).div(100),
            gasPath,
            _msgSender(),
            block.timestamp + 20000
        );
    }

    function updateFactory(address _factory) external onlyOwner {
        require(_factory != address(0), "INVALID_FACTORY");
        factory = _factory;
    }

    function updateRouter(address _router) external onlyOwner {
        require(_router != address(0), "INVALID_ROUTER");
        uniswapV2Router = IUniswapV2Router02(_router);
    }

    function updateWhitelistFactory(address _factory, bool _whitelisted)
        external
        onlyOwner
    {
        require(_factory != address(0), "INVALID_FACTORY");
        whitelistFactory[_factory] = _whitelisted;
    }

    function updateChainFeeAddress(uint256 chainId, address _address)
        external
        onlyOwner
    {
        require(_address != address(0), "INVALID_ADDRESS");
        chainFeeAddress[chainId] = _address;
    }

    function updateMaintainMode(bool _maintainMode) external onlyOwner {
        isMaintaining = _maintainMode;
    }

    function verifySlippage(
        uint256 amountOut,
        uint256 amountDesired,
        uint256 slippage
    ) external pure returns (bool isDesired) {
        isDesired = amountDesired >= amountOut.mul(1000 - slippage);
    }

    //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    event Swaped(
        address indexed sender,
        uint256 amountIn,
        uint256 amountOut,
        address indexed to
    );

    event SwapStart(
        address indexed sender,
        uint256 amountIn,
        uint256 amountOut,
        address indexed to
    );
    event SwapEnd(
        address indexed sender,
        uint256 amountIn,
        uint256 amountOut,
        address indexed to
    );
}