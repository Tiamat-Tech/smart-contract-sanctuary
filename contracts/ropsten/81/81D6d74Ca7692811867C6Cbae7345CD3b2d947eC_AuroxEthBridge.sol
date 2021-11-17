//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./interface/IAuroxBridge.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/ISwapRouter.sol";

contract AuroxEthBridge is IAuroxBridge {

    struct ExchangeInfo {
        uint256 fromAmount;
        uint256 toAmount;
    }

    address immutable nodeAddress;
    address public constant wethAddress = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public constant usdcAddress = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // For Swapping
    IERC20 public constant WMATIC_TOKEN = IERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
    ISwapRouter public constant uniROUTER = ISwapRouter(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);

    mapping(address => ExchangeInfo) userInfo;

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
    ) {
        nodeAddress = _nodeAddress;
    }

    /**
    * @notice Register the swap request from user
    */
    function registerSwap(address inputToken, address outputToken, uint256 amountIn, uint256 minAmountOut) external {
        userPositions[msg.sender].push(PurchaseRequest(inputToken, outputToken, amountIn, minAmountOut));
        address[] memory path = new address[](3);
        path[0] = inputToken;
        path[1] = wethAddress;
        path[2] = outputToken;
        uint256[] memory outputAmount = uniROUTER.getAmountsIn(amountIn, path);
        require(outputAmount[0] >= minAmountOut, "Minimum amount overflow");

        path[2] = usdcAddress;
        uint256[] memory usdcAmount = uniROUTER.getAmountsIn(amountIn, path);
        emit RegisterSwap(msg.sender, outputToken, usdcAmount[0]);
    }
    /**
    * @notice Purchase asset on behalf of user
    */
    // @dev path should be generated on the backend side
    // output and input token will be path[0], path[path.length - 1]
    function buyAssetOnBehalf(address inputToken, address outputToken, address userAddress, uint256 usdcAmount) external override onlyNode {
        address[] memory path = new address[](3);
        path[0] = inputToken;
        path[1] = wethAddress;
        path[2] = outputToken;

        uniROUTER.swapTokensForExactTokens(usdcAmount, type(uint256).max, path, address(this), block.timestamp + 1000, false);

        emit BuyAssetOnBehalf(userAddress, outputToken, usdcAmount);
    }

    /**
    * @notice Issue nft that representing specific token amount purchased
    */
    function issueOwnershipNft(address userAddress, address token, uint256 amount) external override {

    }
}