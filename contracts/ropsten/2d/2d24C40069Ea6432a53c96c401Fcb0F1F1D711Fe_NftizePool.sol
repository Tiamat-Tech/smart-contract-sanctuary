// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./NftPoolToken.sol";
import "./TokenData.sol";
import "./IERC20Burn.sol";
import "./LPData.sol";
import "./Math.sol";

contract NftizePool is IERC721Receiver, AccessControl {

    address public constant SUSHISWAP_FACTORY_ADDRESS = 0xc35DADB65012eC5796536bD9864eD8773aBc74C4;
    address public constant SUSHISWAP_ROUTER_ADDRESS = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;

    IUniswapV2Factory public constant sushiswapFactory = IUniswapV2Factory(SUSHISWAP_FACTORY_ADDRESS);
    IUniswapV2Router02 public constant sushiswapRouter = IUniswapV2Router02(SUSHISWAP_ROUTER_ADDRESS);

    address public poolToken;
    IERC20 public theosToken;
    address public feeAddress;
    uint256 public constant platformFee = 500; // 5.0% in basis points
    uint256 public basePrice;
    uint256 public poolSlots;
    uint256 public poolNfts;

    uint public constant MINIMUM_LIQUIDITY = 10 ** 3;

    mapping(address => mapping(uint256 => uint256)) public nftPrices;
    mapping(address => mapping(uint256 => address)) public originalNftDepositors;
    mapping(address => mapping(uint256 => bool)) public whitelist;
    LPData public lpProvider;

    bytes32 public constant WHITELISTER_ROLE = keccak256("WHITELISTER_ROLE");

    error InsufficientPrivilege(string message);
    error NftNotWhitelisted(string message);
    error PoolSlotsFull(string message);
    error InsufficientLPLiquidity(uint256 theosAmount, uint256 poolTokenAmount);

    event NftWhitelisted(address nft, uint256 tokenId);

    constructor(
        TokenData memory tokenData,
        uint256 _basePrice,
        uint256 _poolSlots,
        address whitelister,
        address nftContractAddress,
        uint256 tokenId,
        address _feeAddress,
        address theosAddress
    )  {
        basePrice = _basePrice;
        poolSlots = _poolSlots;
        feeAddress = _feeAddress;

        _setupRole(WHITELISTER_ROLE, whitelister);
        _setupRole(DEFAULT_ADMIN_ROLE, whitelister);
        whitelist[nftContractAddress][tokenId] = true;

        theosToken = IERC20(theosAddress);

        NftPoolToken poolTokenContract = new NftPoolToken(tokenData.name, tokenData.symbol, tokenData.initialSupply);
        poolTokenContract.mint(address(this), poolSlots * basePrice);
        poolToken = address(poolTokenContract);
        IERC20(poolToken).transfer(msg.sender, tokenData.initialSupply);
    }

    function depositNFT(
        address nftContractAddress,
        uint256 tokenId,
        uint256 i
    ) public {
        if (!whitelist[nftContractAddress][tokenId])
            revert NftNotWhitelisted({message : "Nft must be whitelisted"});

        if (poolSlots <= poolNfts)
            revert PoolSlotsFull({message : "All pool slots are full"});

        IERC721(nftContractAddress).safeTransferFrom(msg.sender, address(this), tokenId);
        uint256 feeAmount = calculateFee(basePrice);

        nftPrices[nftContractAddress][tokenId] = basePrice + i;
        originalNftDepositors[nftContractAddress][tokenId] = msg.sender;
        poolNfts = poolNfts + 1;

        IERC20(poolToken).transfer(msg.sender, basePrice - feeAmount);
        IERC20(poolToken).transfer(feeAddress, feeAmount);
    }

    function withdrawNFT(address nftContractAddress, uint256 tokenId) public {
        uint256 nftPrice = nftPrices[nftContractAddress][tokenId];
        uint256 feeAmount = calculateFee(nftPrice);
        IERC20(poolToken).transfer(msg.sender, nftPrice - feeAmount);
        IERC20(poolToken).transfer(feeAddress, feeAmount);
        IERC721(nftContractAddress).safeTransferFrom(address(this), msg.sender, tokenId);
        delete nftPrices[nftContractAddress][tokenId];
        delete originalNftDepositors[nftContractAddress][tokenId];
    }

    function addLpProvider(address depositor, uint256 theosAmount, uint256 poolTokenAmount) public returns (address sushiLp) {
        sushiLp = sushiswapFactory.getPair(address(theosToken), poolToken);
        lpProvider = LPData(
            depositor,
            sushiLp,
            theosAmount,
            poolTokenAmount
        );
        return sushiLp;
    }

    function claimTheosLiquidity() public {
        //      this action is now enabled for anyone to call
        //        if (msg.sender != lpProvider.depositor) {
        //            revert InvalidLP();
        //        }

        IUniswapV2Pair sushiLP = IUniswapV2Pair(lpProvider.lpTokenAddress);

        uint256 theosReserveAmount;
        uint256 poolTokenReserveAmount;
        uint256 timestamp;
        uint256 lpTokenAmount;

        if (address(theosToken) < poolToken) {
            (theosReserveAmount, poolTokenReserveAmount, timestamp) = sushiLP.getReserves();
            lpTokenAmount = (Math.sqrt(lpProvider.theosTokenAmount * lpProvider.indexPoolTokenAmount)) - MINIMUM_LIQUIDITY;
        }
        else {
            (poolTokenReserveAmount, theosReserveAmount, timestamp) = sushiLP.getReserves();
            lpTokenAmount = (Math.sqrt(lpProvider.indexPoolTokenAmount * lpProvider.theosTokenAmount)) - MINIMUM_LIQUIDITY;
        }

        if (theosReserveAmount > 2 * lpProvider.theosTokenAmount &&
            poolTokenReserveAmount > 2 * lpProvider.indexPoolTokenAmount) {

            sushiswapRouter.removeLiquidity(
                address(theosToken), // tokenA
                poolToken, // tokenB
                lpTokenAmount, // Sushi LP token amount
                lpProvider.theosTokenAmount,
                lpProvider.indexPoolTokenAmount,
                address(this), // to address for returned tokens
                block.timestamp
            );

            IERC20Burn(poolToken).burn(lpProvider.indexPoolTokenAmount);
            theosToken.transfer(lpProvider.depositor, lpProvider.theosTokenAmount);

        } else revert InsufficientLPLiquidity(theosReserveAmount, poolTokenReserveAmount);

    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function whitelistNft(address nftContractAddress, uint256 tokenId) public {
        if (!hasRole(WHITELISTER_ROLE, msg.sender))
            revert InsufficientPrivilege({message : "Caller is not a whitelister"});
        whitelist[nftContractAddress][tokenId] = true;
        emit NftWhitelisted(nftContractAddress, tokenId);
    }

    function calculateFee(uint256 price) public pure returns (uint256) {
        return (price * platformFee) / 10000;
        //dividing by 10k because of using basis points
    }

}