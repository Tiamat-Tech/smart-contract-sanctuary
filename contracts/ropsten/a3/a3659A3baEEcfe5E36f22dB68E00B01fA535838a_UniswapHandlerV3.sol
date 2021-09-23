// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
pragma abicoder v2;

import "./controller/AccessController.sol";
import "./libraries/SafeUint128.sol";
import "./libraries/PositionFee.sol";
import "./interfaces/IHandler.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract UniswapHandlerV3 is AccessController, IHandler {
    using SafeERC20 for IERC20;

    uint128 constant MAX_AMOUNT = type(uint128).max;
    address public POSITION_MANAGER;
    INonfungiblePositionManager public nonfungiblePositionManagerContract;

    struct Stake {
        address staker;
        address poolAddress;
    }

    mapping(bytes32 => Stake) public stakes;

    event Update(bytes32 id, uint256 depositTime, address handler, address pool);
    event Withdraw(bytes32 id, uint256 aquaPremium, uint128[] tokenDifference, address pool);

    constructor(
        address aquaPrimary,
        address indexFund,
        address factory,
        address positionManager
    ) AccessController(indexFund) {
        AQUA_PRIMARY = aquaPrimary;
        UNISWAP_V3_FACTORY = factory;
        POSITION_MANAGER = positionManager;
        nonfungiblePositionManagerContract = INonfungiblePositionManager(positionManager);
    }

    function update(
        bytes32 id,
        uint256 tokenValue,
        address contractAddress,
        bytes calldata data
    ) external override onlyAquaPrimary {
        (address pool, address staker) = abi.decode(data, (address, address));

        require(whitelistedPools[pool].status == true, "Uniswap handler :: Pool not whitelisted.");
        
        require(PositionFee.checkIdValidity(
            POSITION_MANAGER,
            tokenValue,
            pool
        ), "Uniswap handler :: TokenID has a different pool.");

        Stake storage s = stakes[id];
        s.staker = staker;
        s.poolAddress = pool;

        collectFees(tokenValue, staker);

        emit Update(id, block.timestamp, address(this), pool);
    }

    function collectFees(uint256 tokenId, address staker)
        internal
        returns (address[] memory token, uint128[] memory amounts)
    {
        token = new address[](2);
        amounts = new uint128[](2);

        (uint256 amount0, uint256 amount1) = PositionFee.getPositionDetails(tokenId, POSITION_MANAGER);

        if ((amount0 != 0) || (amount1 != 0)) {
            (, , token[0], token[1], , , , , , , , ) = nonfungiblePositionManagerContract.positions(tokenId);

            INonfungiblePositionManager.CollectParams memory params =
                INonfungiblePositionManager.CollectParams(tokenId, staker, MAX_AMOUNT, MAX_AMOUNT);

            (uint256 amount0u, uint256 amount1u) = nonfungiblePositionManagerContract.collect(params);

            amounts[0] = SafeUint128.toUint128(amount0u);
            amounts[1] = SafeUint128.toUint128(amount1u);
        }

        return (token, amounts);
    }

    function withdraw(
        bytes32 id,
        uint256 tokenIdOrAmount,
        address contractAddress
    )
        external
        override
        onlyAquaPrimary
        returns (
            address[] memory token,
            uint256 aquaPoolPremium,
            uint128[] memory tokenDiff,
            bytes memory data
        )
    {
        uint24 fee = abi.decode(whitelistedPools[stakes[id].poolAddress].data, (uint24));
        aquaPoolPremium = whitelistedPools[stakes[id].poolAddress].aquaPremium;

        tokenDiff = new uint128[](2);
        token = new address[](2);

        (token, tokenDiff) = collectFees(tokenIdOrAmount, INDEX_FUND);

        IERC20(POSITION_MANAGER).safeTransferFrom(address(this), stakes[id].staker, tokenIdOrAmount);

        emit Withdraw(id, aquaPoolPremium, tokenDiff, stakes[id].poolAddress);

        delete stakes[id];

        return (token, aquaPoolPremium, tokenDiff, abi.encode(fee));
    }
}