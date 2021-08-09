// SPDX-License-Identifier: MIT
pragma solidity >=0.4.25 <0.7.0;

import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@openzeppelin/contracts-upgradeable/proxy/Initializable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './interfaces/IStaking.sol';
import './abstracts/Migrateable.sol';
import './abstracts/Manageable.sol';
import './interfaces/IToken.sol';

/** Launch
    Roles Needed -
    Staking Contract: External Staker Role
    Token Contract: Burner (AKA Minter)
 */

contract Autostake is Initializable, Migrateable, Manageable {
    event Stake(address from, address tokenIn, uint256 amountOut);

    address staking;
    address uniswap;
    address axion;
    mapping(address => bool) public allowedTokens;

    function setAllowedToken(address _token, bool _allowed)
        external
        onlyManager
    {
        allowedTokens[_token] = _allowed;
    }

    /** @dev stake with token
        Description: Sell a token buy axion and then stake it for # of days
        @param _token {address}
        @param _amount {uint256}
        @param _amountOut {uint256}
        @param _deadline {uint256}
        @param _days {uint256}


        @return amounts {uint256[]} [TokenIn, ETH, AXN]
     */
    function stakeWithToken(
        address _token,
        uint256 _amount,
        uint256 _amountOut,
        uint256 _deadline,
        uint256 _days
    ) external returns (uint256[] memory amounts) {
        require(_days >= 30, 'AUTOSTAKER: Minimum of 30 days');
        require(
            allowedTokens[_token] == true,
            'AUTOSTAKER: This token is not allowed to be used on this contract'
        );

        /** Swap tokens */
        amounts = _swapTokensForTokens(_token, _amount, _amountOut, _deadline);

        /** Burn the tokens */
        IToken(axion).burn(address(this), amounts[2]);

        /** Add additional axion if stake length is greater then 1year */
        uint256 payout = amounts[2];
        if (_days >= 350) {
            payout = payout + (payout * ((_days / 350) + 5)) / 100; // multiply by percent divide by 100
        }

        /** Stake the burned tokens */
        IStaking(staking).externalStake(payout, _days, msg.sender);

        /** Emit Event */
        emit Stake(msg.sender, _token, amounts[2]);

        /** Return amounts for the frontend */
        return amounts;
    }

    /** @dev Swap tokens for tokens
        Description: Use uniswap to swap the token in for axion.
        @param tokenInAddress {address}
        @param amountIn {uint256}
        @param amountOutMin {uint256}
        @param deadline {uint256}

        @return amounts {uint256[]} [TokenIn, ETH, AXN]
     */
    function _swapTokensForTokens(
        address tokenInAddress,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) internal returns (uint256[] memory amounts) {
        /** Transfer tokens to contract */
        IERC20(tokenInAddress).transferFrom(
            msg.sender,
            address(this),
            amountIn
        );

        /** Path through WETH */
        address[] memory path = new address[](3);
        path[0] = tokenInAddress;
        path[1] = IUniswapV2Router02(uniswap).WETH();
        path[2] = axion;

        /** Check allowance */
        if (IERC20(tokenInAddress).allowance(address(this), uniswap) < 2**255) {
            IERC20(tokenInAddress).approve(uniswap, 2**255);
        }

        /** Swap for tokens */
        amounts = IUniswapV2Router02(uniswap).swapExactTokensForTokens(
            (amountIn * 95) / 100,
            amountOutMin,
            path,
            address(this),
            deadline
        );

        /** Return amounts [TokenIn, WETH, Axn] */
        return amounts;
    }

    /** @dev
        Description: Initialize contract
        @param _migrator {address}
        @param _manager {address}
        @param _axion {address}
        @param _staking {address}
        @param _uniswap {address}
     */
    function initialize(
        address _migrator,
        address _manager,
        address _axion,
        address _staking,
        address _uniswap
    ) external initializer {
        _setupRole(MIGRATOR_ROLE, _migrator);
        _setupRole(MANAGER_ROLE, _manager);
        axion = _axion;
        staking = _staking;
        uniswap = _uniswap;
    }
}