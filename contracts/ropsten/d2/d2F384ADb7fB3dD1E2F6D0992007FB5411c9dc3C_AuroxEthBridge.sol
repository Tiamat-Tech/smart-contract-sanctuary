//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./interface/IAuroxBridge.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/ISwapRouter.sol";
import "./interface/IQuickSwapRouter.sol";

contract AuroxEthBridge is IAuroxBridge {

    address immutable nodeAddress;
    address public constant wethAddress = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public constant usdcAddress = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // For Swapping
    IERC20 public constant WMATIC_TOKEN = IERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
    ISwapRouter public constant uniROUTER = ISwapRouter(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
    IQuickSwapRouter public constant QuickSwapRouter = IQuickSwapRouter(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);

    mapping(address => uint96) userInfo;

    struct PurchaseRequest {
        address inputToken;
        address outputToken;
        uint256 amount;
        uint256 minAmountout;
    }

    mapping(address => PurchaseRequest[]) public userPositions;

    modifier onlyNode() {
        require(msg.sender == nodeAddress, "Only node allowed!");
        _;
    }

    constructor(
        address _nodeAddress
    ) public {
        nodeAddress = _nodeAddress;
    }

    /**
    * @notice Register the swap request from user
    * @dev path[0] = inputToken, path[last] = outputToken
    */
    function registerSwap(address[] memory path, address[] memory secondPath, uint256 amountIn, uint minAmountOut) external override {
        userPositions[msg.sender].push(PurchaseRequest(path[0], path[path.length - 1], amountIn, minAmountOut));
        uint256[] memory usdcAmount = uniROUTER.getAmountsIn(amountIn, path);
        emit RegisterSwap(msg.sender, path[path.length - 1], usdcAmount[0], secondPath);
    }
    /**
    * @notice Purchase asset on behalf of user
    */
    // @dev path should be generated on the backend side
    // output and input token will be path[0], path[path.length - 1]
    function buyAssetOnBehalf(address[] memory path, address userAddress, uint usdcAmount) external override onlyNode {
        assert(userInfo[userAddress] != block.number);
        uint[] memory amounts = QuickSwapRouter.swapTokensForExactTokens(usdcAmount, type(uint256).max, path, address(this), block.timestamp + 1000);
        userInfo[userAddress] = uint96(block.number);
        emit BuyAssetOnBehalf(userAddress, path[path.length - 1], usdcAmount, amounts[amounts.length - 1]);
    }

    /**
    * @notice Issue nft that representing specific token amount purchased
    */
    function issueOwnershipNft(address userAddress, address token, uint256 amount) external override {

    }
}