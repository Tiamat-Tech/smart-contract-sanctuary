//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./interface/IAuroxBridge.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract AuroxEthBridge is IAuroxBridge {
    using SafeERC20 for IERC20;

    address public constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 public constant WMATIC_TOKEN = IERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
    IUniswapV2Router02 public constant uniROUTER = IUniswapV2Router02(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);

    address immutable nodeAddress;
    mapping(address => uint96) userInfo;

    mapping(bytes32 => uint256) public positions;

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
    * @dev thisTokenPath[0] = inputToken, thisTokenPath[last] = stableToken
    */
    function registerSwap(address[] calldata thisTokenPath, address[] calldata targetTokenPath,
        uint256 amountIn, uint256 minAmountOut) external override {
        
        require(
            thisTokenPath.length > 1 &&
            targetTokenPath.length > 1 &&
            amountIn > 0 &&
            minAmountOut > 0,
            "bad input params"
        );
        require(
            thisTokenPath[thisTokenPath.length-1] == USDC,
            "token path should end with usdc"
        );
        require(
            IERC20(thisTokenPath[0]).allowance(msg.sender, address(this)) >= amountIn,
            "token allowance is not enough"
        );

        IERC20 token = IERC20(thisTokenPath[0]);
        uint256 tokenBalanceBefore = token.balanceOf(address(this));

        token.safeTransferFrom(msg.sender, address(this), amountIn);
        token.safeApprove(address(uniROUTER), amountIn);

        IERC20 usdc = IERC20(USDC);
        uint256 usdcBalanceBefore = usdc.balanceOf(address(this));

        uniROUTER.swapExactTokensForTokens(
            amountIn,
            1,
            thisTokenPath,
            address(this),
            block.timestamp);
        
        require(token.balanceOf(address(this)) >= tokenBalanceBefore, "bad swap");
        
        uint256 amountUsdc = usdc.balanceOf(address(this)) - usdcBalanceBefore;

        bytes32 id = keccak256(abi.encodePacked(
            msg.data,
            block.number));

        positions[id] += 1;

        emit RegisterSwap(msg.sender,
            thisTokenPath[0],
            targetTokenPath[targetTokenPath.length - 1],
            amountIn,
            amountUsdc
            );
    }
    /**
    * @notice Purchase asset on behalf of user
    */
    // @dev path should be generated on the backend side
    // output and input token will be path[0], path[path.length - 1]
    function buyAssetOnBehalf(address[] memory path, address userAddress, uint usdcAmount) external override onlyNode {
        assert(userInfo[userAddress] != block.number);
        uint[] memory amounts = uniROUTER.swapTokensForExactTokens(usdcAmount, type(uint256).max, path, address(this), block.timestamp + 1000);
        userInfo[userAddress] = uint96(block.number);
        emit BuyAssetOnBehalf(userAddress, path[path.length - 1], usdcAmount, amounts[amounts.length - 1]);
    }

    /**
    * @notice Issue nft that representing specific token amount purchased
    */
    function issueOwnershipNft(address userAddress, address token, uint256 amount) external override {

    }
}