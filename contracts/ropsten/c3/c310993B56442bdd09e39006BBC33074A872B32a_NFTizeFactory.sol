// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error InsufficientTheosLiquidity(uint256 available, uint256 required);

/// @title NFTize pool creator contract
contract NFTizeFactory is Initializable, AccessControlUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    address internal constant UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; //TODO update with Sushiswap address
    address internal constant UNISWAP_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; //TODO update with Sushiswap address

    // index of created contracts
    address[] public poolsTokenContracts;
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    IUniswapV2Router01 public uniswapRouter;
    IUniswapV2Factory public uniswapFactory;
    IERC20 public theosToken;

    event PairCreated(address indexed token0, address indexed token1, address pair);
    event NftizePoolCreated(address indexed poolContract, address indexed token);
    event LiquidityAdded();

    function initialize(address theosAddress) public virtual initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        uniswapRouter = IUniswapV2Router01(UNISWAP_ROUTER_ADDRESS);
        uniswapFactory = IUniswapV2Factory(UNISWAP_FACTORY_ADDRESS); // uniswap addresses are the same on all testnets/mainnet
        theosToken = IERC20(theosAddress);
    }

/// @notice Returns the new pool token contract address
    function createPoolBasic(
        string memory tokenName,
        string memory symbol,
        uint256 poolSlots,
        uint256 basePrice
    ) public {
        uint256 theosAmount = 100 ether;
        // hard coding this for now, before we have a price oracle for theos
        uint256 poolTokenAmount = 100 ether;

        if (theosAmount > (theosToken.balanceOf(msg.sender)))
            revert InsufficientTheosLiquidity({
            available: theosToken.balanceOf(msg.sender),
            required: theosAmount
        });

        theosToken.transferFrom(msg.sender, address(this), theosAmount);

        NftizePool nftizePoolContract = new NftizePool();
        nftizePoolContract.initialize(tokenName, symbol, poolTokenAmount);
        poolsTokenContracts.push(address(nftizePoolContract));

        IERC20(nftizePoolContract.poolToken()).approve(address(this), poolTokenAmount);
        IERC20(nftizePoolContract.poolToken()).transferFrom(address(this), msg.sender, poolTokenAmount);

        theosToken.approve(UNISWAP_ROUTER_ADDRESS, theosAmount);
        IERC20(nftizePoolContract.poolToken()).approve(UNISWAP_ROUTER_ADDRESS, poolTokenAmount);

        address pair = uniswapFactory.createPair(address(theosToken), nftizePoolContract.poolToken());
        getPair[address(theosToken)][nftizePoolContract.poolToken()] = pair;
        getPair[nftizePoolContract.poolToken()][address(theosToken)] = pair;
        // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(address(theosToken), nftizePoolContract.poolToken(), pair);

        IERC20(nftizePoolContract.poolToken()).approve(pair, poolTokenAmount);
        theosToken.approve(pair, theosAmount);

        emit NftizePoolCreated(address(nftizePoolContract), nftizePoolContract.poolToken());
    }

    function addPoolLiquidity (
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

        emit LiquidityAdded();

    }

    /// @notice Returns the new pool token contract address
    function createPoolAdvanced(
        string memory tokenName,
        string memory symbol,
        uint256 poolSlots,
        uint256 basePrice,
        uint256 initialSupply,
        uint256 value
    ) public {
        NftizePool nftizePoolContract = new NftizePool();
        nftizePoolContract.initialize(tokenName, symbol, initialSupply);
        poolsTokenContracts.push(address(nftizePoolContract));

        address pair = uniswapFactory.createPair(address(theosToken), nftizePoolContract.poolToken());
        getPair[address(theosToken)][nftizePoolContract.poolToken()] = pair;
        getPair[nftizePoolContract.poolToken()][address(theosToken)] = pair;
        // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(address(theosToken), nftizePoolContract.poolToken(), pair);
        emit NftizePoolCreated(address(nftizePoolContract), nftizePoolContract.poolToken());
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

contract NftizePool is Initializable {
    address public poolToken;

    function initialize(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) public virtual initializer {
        NftPoolToken poolTokenContract = new NftPoolToken();
        poolTokenContract.initialize(name, symbol, initialSupply);
        poolToken = address(poolTokenContract);
        IERC20(poolToken).approve(address(this), initialSupply);
        IERC20(poolToken).transferFrom(address(this), msg.sender, initialSupply);
    }
}

contract NftPoolToken is Initializable, ERC20PresetMinterPauserUpgradeable {
    function initialize(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) public virtual initializer {
        __ERC20PresetMinterPauser_init(name, symbol);
        _mint(_msgSender(), initialSupply);
    }
}