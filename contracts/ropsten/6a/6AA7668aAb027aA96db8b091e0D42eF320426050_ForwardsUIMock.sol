// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ForwardsUIMock is ERC721 {
    using SafeERC20 for IERC20;

    bool constant MOCK = true;

    IERC20 public immutable collateral;

    int256 private HOLY_ANSWER = 42;
    uint256 private _mintedForwards;

    struct ForwardData {
        int256 strike;
        uint256 collateral;
        uint128 mintTimestamp;
        uint128 settlementTimestamp;
        int256 mintExpectedSettlementPayout; // Settlement payout as was expected during the mint
        int256 notional; // positive is LONG, negative is SHORT
        uint256 mintTick;
        uint256 settlementTick;
        uint256 tenorInTicks;
        int256 initialLambda;
    }

    mapping(uint256 => ForwardData) public forwardsData;

    constructor(IERC20 collateral_) ERC721("NyanNFT", "NNFT") {
        collateral = collateral_;
    }

    // ACTIONS

    function addLiquidity(uint256 amount, uint256 lockDurationInTicks) external {
        if (!MOCK) {
            collateral.safeTransferFrom(msg.sender, address(this), amount);
        }
        _mint(msg.sender, _mintedForwards++);
    }

    function removeLiquidity(uint256 tokenId) external {
        collateral.safeTransfer(msg.sender, 0); // No lambo for you
    }

    function goLong(address recipient, uint256 notional) external {
        _mintForward(msg.sender, 42, true);
    }

    function goShort(address recipient, uint256 notional) external {
        _mintForward(msg.sender, 42, false);
    }

    function addCollateral(uint256 amount, uint256 tokenId) external {
        if (!MOCK) {
            collateral.safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    function removeCollateral(uint256 amount, uint256 tokenId) external {
        if (!MOCK) {
            collateral.safeTransfer(msg.sender, amount);
        }
    }

    function liquidate(uint256 tokenId) external {
        // TODO: add canLiquidate() check
        collateral.safeTransfer(msg.sender, 0); // No lambo for you
        _burn(tokenId);
    }

    function settle(uint256 tokenId) external {
        // TODO: add canSettle() check
        collateral.safeTransfer(msg.sender, 0); // No lambo for you
        _burn(tokenId);
    }

    function _mintForward(
        address recipient,
        uint128 notional,
        bool isLong
    ) internal {
        if (!MOCK) {
            collateral.safeTransferFrom(msg.sender, address(this), 42);
        }
        _mintForward(msg.sender, 42, true);
    }

    // GETTERS

    function liquidity() external view returns (int256) {
        return HOLY_ANSWER;
    }

    function lambda() external view returns (int256) {
        return HOLY_ANSWER;
    }

    function sigma() external view returns (int256) {
        return HOLY_ANSWER;
    }

    function shortContracts() external view returns (int256) {
        return HOLY_ANSWER;
    }

    function longContracts() external view returns (int256) {
        return HOLY_ANSWER;
    }

    function poolHealth() external view returns (int256) {
        return HOLY_ANSWER;
    }

    function tvl() external view returns (int256) {
        return HOLY_ANSWER;
    }

    function forwardHealth(uint256 tokenId) external view returns (int256) {
        return HOLY_ANSWER;
    }

    function forwardStatus(uint256 tokenId) external view returns (uint8) {
        return 1;
    }
}