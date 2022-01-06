pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./libraries/TransferHelper.sol";
import "./libraries/UniswapV2Library.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/ISpikeInuRouterV1.sol";
import "hardhat/console.sol";

contract SpikeInuGateway is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeMath for uint256;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "SpikeInuGateway: EXPIRED");
        _;
    }

    bool public isInitialized;
    address public spikeInuRouter;

    function initialize() public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
    }

    function inititalContract(address _spikeRouter) public onlyOwner {
        require(!isInitialized, "initialized");
        isInitialized = true;
        spikeInuRouter = _spikeRouter;
    }

    /**
     * @param swapParams[0] = from chain
     * @param swapParams[1] = to chain
     */
    function swapFromChainIn(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256 deadline,
        address routers,
        uint256[] calldata swapParams
    )
        external
        ensure(deadline)
        nonReentrant
        returns (uint256[] memory amounts)
    {
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            address(this),
            amountIn
        );
        TransferHelper.safeApprove(path[0], spikeInuRouter, amountIn);
        amounts = ISpikeInuRouterV1(spikeInuRouter).swapFromChainIn(
            amountIn,
            amountOutMin,
            path,
            deadline,
            routers,
            swapParams
        );

        TransferHelper.safeTransfer(
            path[path.length - 1],
            msg.sender,
            amounts[amounts.length - 1]
        );
    }

    /**
     * @param swapParams[0] = from chain
     * @param swapParams[1] = to chain
     */
    function swapFromChainOut(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        uint256 deadline,
        address routers,
        uint256[] calldata swapParams
    )
        external
        ensure(deadline)
        nonReentrant
        returns (uint256[] memory amounts)
    {
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            address(this),
            amountInMax
        );
        TransferHelper.safeApprove(path[0], spikeInuRouter, amountInMax);
        amounts = ISpikeInuRouterV1(spikeInuRouter).swapFromChainOut(
            amountOut,
            amountInMax,
            path,
            deadline,
            routers,
            swapParams
        );
        TransferHelper.safeTransfer(
            path[path.length - 1],
            msg.sender,
            amounts[amounts.length - 1]
        );
    }

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
        address routers,
        uint256[] calldata swapParams
    )
        external
        ensure(deadline)
        nonReentrant
        returns (uint256[] memory amounts)
    {
        amounts = ISpikeInuRouterV1(spikeInuRouter).swapToChainIn(
            amountIn,
            amountOutMin,
            path,
            to,
            deadline,
            routers,
            swapParams
        );
    }

    function updateRouter(address _spikeRouter) external {
        require(_spikeRouter != address(0));
        spikeInuRouter = _spikeRouter;
    }
}