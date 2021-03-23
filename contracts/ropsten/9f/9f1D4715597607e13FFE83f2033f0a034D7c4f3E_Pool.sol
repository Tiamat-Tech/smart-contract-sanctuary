// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./../dependencies/pancake/core/interfaces/IPancakePair.sol";
import "./../dependencies/contracts/SafeMath.sol";
import "./../dependencies/contracts/IERC20.sol";
import "./../interfaces/IPool.sol";
import "./../interfaces/IRouter.sol";
import "./../interfaces/IReserve.sol";
import "./libraries/upgradeability/Versioned.sol";
import "./libraries/helpers/TransferHelper.sol";


/**
 * @title Storage contract
 * @dev Defines  contract storage to reuse in future implementations without copy and paste
 * @author WOWSwap
 **/
abstract contract PoolStorage is Initializable, ContextUpgradeable, Versioned, ERC20Upgradeable {
    IReserve internal m_reserve;
    IERC20 internal m_lendable;
    IERC20 internal m_tradable;
    IPancakePair internal m_pancakePair;
    IRouter internal m_router;
    bool internal m_flipped;

    uint256[50] private ______gap;
}


/**
 * @title Pool contract
 * @dev Entry point to create trading position with leverage
 * - Users can:
 *   # Deposit liquidity
 *   # Withdraw liquidity
 *   # Open position
 *   # Close position
 *   # Liquidate unhealthy positions
 * @author WOWSwap
 **/
contract Pool is PoolStorage, IPool {
    using SafeMath for uint256;

    function getRevision() internal pure override returns (uint256) {
        return 0x1;
    }

    function initialize(
        address reserve,
        address pancakePair,
        address lendable,
        address tradable,
        string calldata name,
        string calldata symbol
    ) external initializer {
        __Context_init_unchained();
        __Versioned_init_unchained();
        __ERC20_init(
            string(abi.encodePacked(name, " Proxy")),
            string(abi.encodePacked("prx", symbol))
        );

        m_reserve = IReserve(reserve);
        m_pancakePair = IPancakePair(pancakePair);
        m_lendable = IERC20(lendable);
        m_tradable = IERC20(tradable);
        m_flipped = lendable >= tradable;
    }

    function _transferTokens(
        address token,
        address to,
        uint256 amount
    ) private {
        // Transfer specified amount of tokens to the recipient
        TransferHelper.safeTransfer(token, to, amount);
    }

    function _swap(uint256 lendableAmount, uint256 tradableAmount) private {
        bytes memory data;
        if (m_flipped) {
            m_pancakePair.swap(
                tradableAmount,
                lendableAmount,
                address(this),
                data
            );
        } else {
            m_pancakePair.swap(
                lendableAmount,
                tradableAmount,
                address(this),
                data
            );
        }
    }

    function openPosition(
        address to,
        uint256 amountOut
    ) external override returns (bool) {
        uint256 amountIn = m_lendable.balanceOf(address(this));

        _transferTokens(
            address(m_lendable),
            address(m_pancakePair),
            amountIn
        );

        _swap(0, amountOut);
        _mint(to, amountOut);

        return true;
    }

    function closePosition(
        address to,
        uint256 amountOut
    ) external override returns (bool) {
        uint256 amountIn = balanceOf(address(this));
        _burn(address(this), amountIn);

        _transferTokens(
            address(m_tradable),
            address(m_pancakePair),
            amountIn
        );

        _swap(amountOut, 0);

        _transferTokens(address(m_lendable), to, amountOut);

        return true;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override virtual {
        // TODO: move principal debt here in a future
     }
}