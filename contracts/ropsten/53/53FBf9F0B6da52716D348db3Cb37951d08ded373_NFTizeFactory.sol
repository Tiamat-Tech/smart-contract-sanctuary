// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.6;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./NftPoolToken.sol";
import "./NftizePool.sol";

/// @title NFTize pool creator contract
contract NFTizeFactory is Initializable, AccessControlUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    address internal constant UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; //TODO update with Sushiswap address
    address internal constant UNISWAP_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; //TODO update with Sushiswap address

    // index of created contracts
    address[] public poolsTokenContracts;

    IUniswapV2Router02 public constant uniswapRouter = IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS);
    IUniswapV2Factory public constant uniswapFactory = IUniswapV2Factory(UNISWAP_FACTORY_ADDRESS);
    IERC20 public theosToken;

    event NftizePoolCreated(address indexed poolContract, address indexed token);
    event LiquidityAdded(uint256 theosTokenAmount, uint256 poolTokenAmount);

    error InsufficientTheosLiquidity(uint256 available, uint256 required);

    function initialize(address theosAddress) public virtual initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        theosToken = IERC20(theosAddress);
    }

    /// @notice Returns the new pool token contract address
    function createPool(
        string memory tokenName,
        string memory symbol,
        uint256 poolSlots,
        uint256 basePrice
    ) public {
        uint256 theosAmount = 100 ether;
        // TODO: hard coding this for now, before we have a price oracle for theos
        uint256 poolTokenAmount = 100 ether;

        if (theosAmount > (theosToken.balanceOf(msg.sender)))
            revert InsufficientTheosLiquidity({ available: theosToken.balanceOf(msg.sender), required: theosAmount });

        theosToken.transferFrom(msg.sender, address(this), theosAmount);

        NftizePool nftizePoolContract = new NftizePool();
        nftizePoolContract.initialize(tokenName, symbol, poolTokenAmount, basePrice, poolSlots);
        poolsTokenContracts.push(address(nftizePoolContract));

        IERC20(nftizePoolContract.poolToken()).approve(address(this), poolTokenAmount);
        IERC20(nftizePoolContract.poolToken()).transferFrom(address(this), msg.sender, poolTokenAmount);

        theosToken.approve(UNISWAP_ROUTER_ADDRESS, theosAmount);
        IERC20(nftizePoolContract.poolToken()).approve(UNISWAP_ROUTER_ADDRESS, poolTokenAmount);

        emit NftizePoolCreated(address(nftizePoolContract), nftizePoolContract.poolToken());
    }

    function addPoolLiquidity(
        address poolToken,
        uint256 theosAmount,
        uint256 poolTokenAmount,
        uint256 minAmount
    ) public {
        IERC20(poolToken).transferFrom(msg.sender, address(this), poolTokenAmount);
        theosToken.transferFrom(msg.sender, address(this), theosAmount);

        IERC20(poolToken).approve(UNISWAP_ROUTER_ADDRESS, poolTokenAmount);
        theosToken.approve(UNISWAP_ROUTER_ADDRESS, theosAmount);

        uniswapRouter.addLiquidity(
            address(theosToken),
            poolToken,
            theosAmount,
            poolTokenAmount,
            minAmount,
            minAmount,
            msg.sender,
            block.timestamp
        );

        emit LiquidityAdded(theosAmount, poolTokenAmount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}