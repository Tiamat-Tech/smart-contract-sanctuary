// SPDX-License-Identifier: MIT
pragma solidity >=0.4.25 <0.7.0;

import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@openzeppelin/contracts-upgradeable/proxy/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';
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

contract Accelerator is Initializable, Migrateable, Manageable {
    event AcceleratorToken(
        address indexed from,
        address indexed tokenIn,
        address indexed token,
        uint8[3] splitAmounts,
        uint256 axionBought,
        uint256 tokenBought,
        uint256 stakeDays,
        uint256 payout,
        uint256 currentDay
    );
    event AcceleratorEth(
        address indexed from,
        address indexed token,
        uint8[3] splitAmounts,
        uint256 axionBought,
        uint256 tokenBought,
        uint256 stakeDays,
        uint256 payout,
        uint256 currentDay
    );

    /** Public */
    address public staking; // Staking Address
    address public axion; // Axion Address
    address public token; // Token to buy other then aixon
    address payable public uniswap; // Uniswap Adress
    address payable public recipient; // Recipient Address
    uint256 public minStakeDays; // Minimum length of stake from contract
    uint256 public start; // Start of Contract in seconds
    uint256 public secondsInDay; // 86400
    uint256 public maxBoughtPerDay; // Amount bought before bonus is removed
    uint256[] public bought; // Total bought for the day
    uint8[3] public splitAmounts; // 0 axion, 1 btc, 2 recipient
    mapping(address => bool) public allowedTokens; // Tokens allowed to be used for stakeWithToken
    /** Private */
    bool private _paused; // Contract paused

    // -------------------- Modifiers ------------------------
    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), 'AUTOSTAKER: paused');
        _;
    }

    // -------------------- Functions ------------------------
    /** @dev stake with token
        Description: Sell a token buy axion and then stake it for # of days
        @param _amountOut {uint256}
        @param _deadline {uint256}
        @param _days {uint256}
     */
    function axionBuyAndStake(
        uint256 _amountOut,
        uint256 _deadline,
        uint256 _days
    )
        external
        payable
        whenNotPaused
        returns (uint256 axionBought, uint256 tokenBought)
    {
        require(_days >= minStakeDays, 'AUTOSTAKER: Minimum stake days');
        uint256 currentDay = getCurrentDay();
        //** Get Amounts */
        (uint256 _recipientAmount, uint256 _tokenAmount, uint256 _axionAmount) =
            dividedAmounts(msg.value);

        //** Swap tokens */
        axionBought = swapEthForTokens(
            axion,
            address(this),
            _axionAmount,
            _amountOut,
            _deadline
        );
        tokenBought = swapEthForTokens(
            token,
            address(this),
            _tokenAmount,
            _amountOut,
            _deadline
        );

        // Call sendAndBurn
        uint256 payout =
            sendAndBurn(axionBought, tokenBought, _days, currentDay);

        //** Transfer any eithereum in contract to recipient address */
        recipient.transfer(_recipientAmount);

        //** Stake the burned tokens */
        IStaking(staking).externalStake(payout, _days, msg.sender);

        //** Emit Event  */
        emit AcceleratorEth(
            msg.sender,
            token,
            splitAmounts,
            axionBought,
            tokenBought,
            _days,
            payout,
            currentDay
        );

        /** Return amounts for the frontend */
        return (axionBought, tokenBought);
    }

    /** @dev Swap tokens for tokens
        Description: Use uniswap to swap the token in for axion.
        @param _tokenOutAddress {address}
        @param _to {address}
        @param _amountIn {uint256}
        @param _amountOutMin {uint256}
        @param _deadline {uint256}

        @return {uint256}
     */
    function swapEthForTokens(
        address _tokenOutAddress,
        address _to,
        uint256 _amountIn,
        uint256 _amountOutMin,
        uint256 _deadline
    ) internal returns (uint256) {
        /** Path through WETH */
        address[] memory path = new address[](2);
        path[0] = IUniswapV2Router02(uniswap).WETH();
        path[1] = _tokenOutAddress;

        /** Swap for tokens */
        return
            IUniswapV2Router02(uniswap).swapExactETHForTokens{value: _amountIn}(
                _amountOutMin,
                path,
                _to,
                _deadline
            )[1];
    }

    /** @dev stake with ethereum
        Description: Sell a token buy axion and then stake it for # of days
        @param _token {address}
        @param _amount {uint256}
        @param _amountOut {uint256}
        @param _deadline {uint256}
        @param _days {uint256}
     */
    function axionBuyAndStake(
        address _token,
        uint256 _amount,
        uint256 _amountOut,
        uint256 _deadline,
        uint256 _days
    )
        external
        whenNotPaused
        returns (uint256 axionBought, uint256 tokenBought)
    {
        require(_days >= minStakeDays, 'AUTOSTAKER: Minimum stake days');
        require(
            allowedTokens[_token] == true,
            'AUTOSTAKER: This token is not allowed to be used on this contract'
        );
        uint256 currentDay = getCurrentDay();

        //** Get Amounts */
        (uint256 _recipientAmount, uint256 _tokenAmount, uint256 _axionAmount) =
            dividedAmounts(_amount);

        /** Transfer tokens to contract */
        IERC20(_token).transferFrom(
            msg.sender,
            address(this),
            _tokenAmount + _axionAmount
        );

        //** Swap tokens */
        axionBought = swapTokensForTokens(
            _token,
            axion,
            address(this),
            _axionAmount,
            _amountOut,
            _deadline
        );

        if (_token != token) {
            tokenBought = swapTokensForTokens(
                _token,
                token,
                address(this),
                _tokenAmount,
                _amountOut,
                _deadline
            );
        } else {
            tokenBought = _tokenAmount;
        }

        // Call sendAndBurn
        uint256 payout =
            sendAndBurn(axionBought, tokenBought, _days, currentDay);

        //** Transfer tokens to Manager */
        IERC20(_token).transferFrom(msg.sender, recipient, _recipientAmount);

        //** Stake the burned tokens */
        IStaking(staking).externalStake(payout, _days, msg.sender);

        //* Emit Event */
        emit AcceleratorToken(
            msg.sender,
            _token,
            token,
            splitAmounts,
            axionBought,
            tokenBought,
            _days,
            payout,
            currentDay
        );

        /** Return amounts for the frontend */
        return (axionBought, tokenBought);
    }

    /** @dev Swap tokens for tokens
        Description: Use uniswap to swap the token in for axion.
        @param _tokenInAddress {address}
        @param _tokenOutAddress {address}
        @param _to {address}
        @param _amountIn {uint256}
        @param _amountOutMin {uint256}
        @param _deadline {uint256}

        @return amounts {uint256[]} [TokenIn, ETH, AXN]
     */
    function swapTokensForTokens(
        address _tokenInAddress,
        address _tokenOutAddress,
        address _to,
        uint256 _amountIn,
        uint256 _amountOutMin,
        uint256 _deadline
    ) internal returns (uint256) {
        /** Path through WETH */
        address[] memory path = new address[](3);
        path[0] = _tokenInAddress;
        path[1] = IUniswapV2Router02(uniswap).WETH();
        path[2] = _tokenOutAddress;

        /** Check allowance */
        if (
            IERC20(_tokenInAddress).allowance(address(this), uniswap) < 2**255
        ) {
            IERC20(_tokenInAddress).approve(uniswap, 2**255);
        }

        /** Swap for tokens */
        return
            IUniswapV2Router02(uniswap).swapExactTokensForTokens(
                _amountIn,
                _amountOutMin,
                path,
                _to,
                _deadline
            )[2];
    }

    function sendAndBurn(
        uint256 _axionBought,
        uint256 _tokenBought,
        uint256 _days,
        uint256 _currentDay
    ) internal returns (uint256) {
        /** Burn the tokens */
        IToken(axion).burn(address(this), _axionBought);
        IERC20(token).transferFrom(
            msg.sender,
            staking,
            _tokenBought - (_tokenBought / splitAmounts[1])
        );
        IStaking(staking).updateTokenPricePerShare(
            msg.sender,
            recipient,
            token,
            _tokenBought
        );

        /** Add additional axion if stake length is greater then 1year */
        uint256 payout = (100 * _axionBought) / splitAmounts[0];
        if (_days >= 350 && bought[_currentDay] < maxBoughtPerDay) {
            uint256 forSaleWithBonus = maxBoughtPerDay - bought[_currentDay];
            bought[_currentDay] += payout;
            if (payout > forSaleWithBonus) {
                uint256 payoutWithBonus = forSaleWithBonus;
                uint256 payoutWithoutBonus = payout - payoutWithBonus;

                return
                    (payoutWithBonus +
                        (payoutWithBonus * ((_days / 350) + 5)) /
                        100) + payoutWithoutBonus;
            }
            return payout + (payout * ((_days / 350) + 5)) / 100; // multiply by percent divide by 100
        } else {
            bought[_currentDay] += payout;
        }

        /** Return amounts for the frontend */
        return payout;
    }

    /** Utility Functions */
    /** @dev currentDay
        Description: Get the current day since start of contract
     */
    function getCurrentDay() public view returns (uint256) {
        return (now - start) / secondsInDay;
    }

    /** @dev dividedAmounts
        Description: Uses Split amounts to return amountIN should be each
        @param _amountIn {uint256}
     */
    function dividedAmounts(uint256 _amountIn)
        internal
        view
        returns (
            uint256 _recipientAmount,
            uint256 _tokenAmount,
            uint256 _axionAmount
        )
    {
        _axionAmount = (_amountIn * splitAmounts[0]) / 100;
        _tokenAmount = (_amountIn * splitAmounts[1]) / 100;
        _recipientAmount = (_amountIn * splitAmounts[2]) / 100;
    }

    // -------------------- Setter Functions ------------------------
    /** @dev setAllowedToken
        Description: Allow tokens can be swapped for axion.
        @param _token {address}
        @param _allowed {bool}
     */
    function setAllowedToken(address _token, bool _allowed)
        external
        onlyManager
    {
        allowedTokens[_token] = _allowed;
    }

    /** @dev setPaused
        @param _p {bool}
     */
    function setPaused(bool _p) external onlyManager {
        _paused = _p;
    }

    /** @dev setFee
        @param _days {uint256}
     */
    function setMinStakeDays(uint256 _days) external onlyManager {
        minStakeDays = _days;
    }

    /** @dev splitAmounts
        @param _splitAmounts {uint256[]}
     */
    function setSplitAmounts(uint8[3] calldata _splitAmounts)
        external
        onlyManager
    {
        splitAmounts = _splitAmounts;
    }

    /** @dev maxBoughtPerDay
        @param _amount uint256 
    */
    function setMaxBoughtPerDay(uint256 _amount) external onlyManager {
        maxBoughtPerDay = _amount;
    }

    // -------------------- Getter Functions ------------------------
    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /** @dev initialize
        Description: Initialize contract
        @param _migrator {address}
        @param _manager {address}
     */
    function initialize(address _migrator, address _manager)
        external
        initializer
    {
        /** Setup roles and addresses */
        _setupRole(MIGRATOR_ROLE, _migrator);
        _setupRole(MANAGER_ROLE, _manager);
    }

    function startAddresses(
        address _staking,
        address _axion,
        address _token,
        address payable _uniswap,
        address payable _recipient
    ) external onlyMigrator {
        staking = _staking;
        axion = _axion;
        token = _token;
        uniswap = _uniswap;
        recipient = _recipient;
    }

    function startVariables(
        uint256 _minStakeDays,
        uint256 _start,
        uint256 _secondsInDay,
        uint256 _maxBoughtPerDay,
        uint8[3] calldata _splitAmounts
    ) external onlyMigrator {
        minStakeDays = _minStakeDays;
        start = _start;
        secondsInDay = _secondsInDay;
        maxBoughtPerDay = _maxBoughtPerDay;
        splitAmounts = _splitAmounts;
    }
}