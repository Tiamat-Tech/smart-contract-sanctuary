pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "hardhat/console.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/UniswapV2Library.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IERC20.sol";

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
    modifier onlyNotMaintain() {
        require(!isMaintaining, "MAINTAINING");
        _;
    }

    modifier onlyOperator() {
        require(operators[_msgSender()], "FORB");
        _;
    }

    bool public isInitialized;
    bool public isMaintaining;
    address factory;
    address feeTo;
    uint256 feePercent;
    // mint amount in
    uint256 mintSwapAmount;
    mapping(address => bool) whitelistFactory;
    mapping(uint256 => address) chainFeeAddress;
    mapping(address => bool) whitelistStableTokens;
    mapping(address => address) routerToFactory;
    address chainGasAddress;

    IUniswapV2Router02 public uniswapV2Router;
    address constant ETH_ADDRESS =
        address(0xc778417E063141139Fce010982780140Aa0cD5Ab);
    uint256 constant maxFeePercent = 50000; // = 50%, 100000 = 100%
    mapping(address => bool) operators;

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
     * @param amountOutMin2 = min amount of second chain
     * mapping swap id for tracking on cross-chain
     */
    function swapFromChainIn(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 amountOutMin2,
        address[] memory path1,
        address[] calldata path2,
        uint256 deadline,
        address router,
        uint256[] calldata swapParams
    )
        external
        ensure(deadline)
        nonReentrant
        onlyNotMaintain
        returns (uint256[] memory amounts)
    {}

    /**
     * @param swapParams[0] = from chain
     * @param swapParams[1] = to chain
     */
    function swapFromChainOut(
        uint256 amountOut,
        uint256 amountInMax,
        uint256 amountOutMin2,
        address[] memory path,
        address[] memory path2,
        uint256 deadline,
        address router,
        uint256[] calldata swapParams
    )
        external
        ensure(deadline)
        nonReentrant
        onlyNotMaintain
        returns (uint256[] memory amounts)
    {
        // transfer token A from user to this contract
    }

    /**
     * swap exact ETH for token
     * @param swapParams[0] = from chain
     * @param swapParams[1] = to chain
     * path[0] = WEWTH
     * path[end] = USTD or destination token
     */
    function swapEthFromChainIn(
        uint256 amountEthIn,
        uint256 amountOutMin,
        uint256 amountOutMin2,
        address[] memory path,
        address[] calldata path2,
        uint256 deadline,
        address router,
        address wethAddress,
        uint256[2] calldata swapParams
    )
        external
        payable
        ensure(deadline)
        nonReentrant
        onlyNotMaintain
        returns (uint256[] memory amounts)
    {}

    /**
     * swap exact ETH for token
     * @param swapParams[0] = from chain
     * @param swapParams[1] = to chain
     */
    function swapEthFromChainOut(
        uint256 amountInMax,
        uint256 amountOutMin,
        uint256 amountOutMin2,
        address[] memory path,
        address[] memory path2,
        uint256 deadline,
        address router,
        uint256[2] calldata swapParams
    )
        external
        payable
        ensure(deadline)
        nonReentrant
        onlyNotMaintain
        returns (uint256[] memory amounts)
    {}

    /**
     * swap table token to destination token on second chain.
     * ex1: USDT -> MATIC: bridge transfer usdt to UniRouter for swap MATIC
     * ex2: USDT -> BNB : bridge transfer usdt to UniRouter for swap BNB
     * ex3: USDT -> BNB -> KNC: bridge transfer usdt to UniRouter for swap KNC
     * @param amountIn: max amount can use for fee and swap
     * @param amountOutMin: min amount out
     * @param path : swap path on second chain.
     * @param to : receiver
     * @param deadline : deadline timestamp
     * @param refundGasAmount : amount usdt will swap for eth
     */
    function swapToChainIn(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline,
        uint256 refundGasAmount
    )
        external
        ensure(deadline)
        nonReentrant
        onlyOperator
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
        uint256 remainingAmount = 0;
        uint256 fee = 0;

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

    function tokenBalance(address token, address account)
        internal
        view
        returns (uint256)
    {
        if (token == ETH_ADDRESS) {
            return account.balance;
        } else {
            return IERC20(token).balanceOf(account);
        }
    }

    function transferTokens(
        address token,
        address payable destination,
        uint256 amount
    ) internal {
        if (amount > 0) {
            if (token == ETH_ADDRESS) {
                (bool result, ) = destination.call{value: amount, gas: 30000}(
                    ""
                );
                require(result, "Failed to transfer Ether");
            } else {
                // IERC20(token).safeTransfer(destination, amount);
                TransferHelper.safeTransfer(token, destination, amount);
            }
        }
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
        address indexed to,
        address[] path,
        uint256 deadline
    );
    event SwapEnd(
        address indexed sender,
        uint256 amountIn,
        uint256 amountOut,
        address indexed to
    );
}