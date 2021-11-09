// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";

import "./interfaces/IVault.sol";
import "./InvitationalNFT.sol";

/**
 * @title   Vault
 * @notice  A vault that provides liquidity on Uniswap V3.
 */
contract Vault is
    IVault,
    IUniswapV3MintCallback,
    IUniswapV3SwapCallback,
    ERC20,
    ReentrancyGuard,
    AccessControl
{

    bytes32 private constant STRATEGY_ROLE = keccak256("STRATEGY_ROLE");

    IERC20 public immutable token0;
    IERC20 public immutable token1;
    InvitationalNFT public immutable NFT_TOKEN; // InvitationNFT contract
    PoolInfo public currentPool;
    PoolInfo[3] public pools;

    address public strategy;
    bool public finalized;
    uint256 public maxTotalSupply;
    uint8 public operationMode; // 0 - all deposits are restricted
                                // 1 - access for all, NFT holders have privileges
                                // 2 - access only for NFT holders
    struct PoolInfo {
        IUniswapV3Pool pool;
        int24 baseLower;
        int24 baseUpper;
        int24 tick;
        uint256 protocolFee;
        uint256 accruedProtocolFees0;
        uint256 accruedProtocolFees1;
    }

    modifier onlyGovernance() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "onlyGovernance");
        _;
    }

    modifier onlyStrategy() {
        require(_msgSender() == strategy, "onlyStrategy");
        _;
    }

    event Deposit(
        address indexed sender,
        address indexed to,
        uint256 shares,
        uint256 amount0,
        uint256 amount1
    );

    event Withdraw(
        address indexed sender,
        address indexed to,
        uint256 shares,
        uint256 amount0,
        uint256 amount1
    );

    event CollectFees(
        uint256 feesToVault0,
        uint256 feesToVault1,
        uint256 feesToProtocol0,
        uint256 feesToProtocol1
    );

    event Snapshot(
        int24 tick,
        uint256 totalAmount0,
        uint256 totalAmount1,
        uint256 totalSupply
    );

    event Rerange(int24 baseLower, int24 baseUpper);

    /**
     * @param _poolInfos Three underlying Uniswap V3 pools for each fee
     * @param _currentPoolIndex index of the current pool
     * @param _maxTotalSupply total supply limit
     * @param _operationMode operation mode for vault
     * @param _nft InvitationNFT contract address
     * @param _admin admin address
     * @param _strategy strategy address
     */
    constructor(
        PoolInfo[] memory _poolInfos,
        uint256 _currentPoolIndex,
        uint256 _maxTotalSupply,
        uint8 _operationMode,
        address _nft,
        address _admin,
        address _strategy
    ) ERC20("Vault", "VT") {
        uint256 len = _poolInfos.length;
        require(len <= 3, "Wrong length");
        for (uint8 i = 0; i < len; i++) {
            pools[i] = _poolInfos[i];
        }

        currentPool = _poolInfos[_currentPoolIndex];

        token0 = IERC20(IUniswapV3Pool(currentPool.pool).token0());
        token1 = IERC20(IUniswapV3Pool(currentPool.pool).token1());

        maxTotalSupply = _maxTotalSupply;
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        NFT_TOKEN = InvitationalNFT(_nft);
        operationMode = _operationMode;
        strategy = _strategy;
    }

    /**
     * @notice Deposits tokens in proportion to the vault's current holdings.
     * @dev These tokens are stored in the vault and are not used for liquidity on
     * Uniswap until the next rebalance. Also note it's not necessary to check
     * if user manipulated price to deposit cheaper, as the value of range
     * orders can only by manipulated higher.
     * @param amount0Desired Max amount of token0 to deposit
     * @param amount1Desired Max amount of token1 to deposit
     * @param amount0Min Revert if resulting `amount0` is less than this
     * @param amount1Min Revert if resulting `amount1` is less than this
     * @param tokenNftId ID of user's invitational NFT
     * @param to Recipient of shares
     * @return shares Number of shares minted
     * @return amount0 Amount of token0 deposited
     * @return amount1 Amount of token1 deposited
     */

    function deposit(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 tokenNftId,
        address to
    )
        external
        override
        nonReentrant
        returns (
            uint256 shares,
            uint256 amount0,
            uint256 amount1
        )
    {
        require(operationMode > 0, "status 0");

        address sender = _msgSender();

        if (operationMode == 2) 
            require(NFT_TOKEN.ownerOf(tokenNftId) == sender, "invalid invitation");

        require(
            amount0Desired > 0 || amount1Desired > 0,
            "amount0Desired or amount1Desired"
        );

        require(to != address(0) && to != address(this), "to");

        // Poke positions so vault's current holdings are up-to-date
        _poke(currentPool.baseLower, currentPool.baseUpper);

        // Calculate amounts proportional to vault's holdings
        (shares, amount0, amount1) = _calcSharesAndAmounts(
            amount0Desired,
            amount1Desired
        );

        require(shares > 0, "shares");
        require(amount0 >= amount0Min, "amount0Min");
        require(amount1 >= amount1Min, "amount1Min");

        // Pull in tokens from sender
        if (amount0 > 0)
            require(
                token0.transferFrom(msg.sender, address(this), amount0),
                "transfer failed"
            );
        if (amount1 > 0)
            require(
                token1.transferFrom(msg.sender, address(this), amount1),
                "transfer failed"
            );

        // Mint shares to recipient
        _mint(to, shares);

        // If User owns NFT, increase his maxTotalSupply
        // Works if NFT functionality is Enabled
        if (operationMode == 2)
            require(totalSupply() <= maxTotalSupply, "maxTotalSupply");

        emit Deposit(msg.sender, to, shares, amount0, amount1);
    }

    /**
     * @notice Withdraws tokens in proportion to the vault's holdings.
     * @param shares Shares burned by sender
     * @param amount0Min Revert if resulting `amount0` is smaller than this
     * @param amount1Min Revert if resulting `amount1` is smaller than this
     * @param to Recipient of tokens
     * @return amount0 Amount of token0 sent to recipient
     * @return amount1 Amount of token1 sent to recipient
     */
    function withdraw(
        uint256 shares,
        uint256 amount0Min,
        uint256 amount1Min,
        address to
    )
        external
        override
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        require(shares > 0, "shares");
        require(to != address(0) && to != address(this), "to");
        uint256 totalSupply = totalSupply();
        address sender = _msgSender();
        // Burn shares
        _burn(sender, shares);
        // Burn user's NFT
        NFT_TOKEN.burn(sender);

        // Calculate token amounts proportional to unused balances
        uint256 unusedAmount0 = (getBalance0() * shares) / totalSupply;
        uint256 unusedAmount1 = (getBalance1() * shares) / totalSupply;

        // Withdraw proportion of liquidity from Uniswap pool
        (uint256 baseAmount0, uint256 baseAmount1) = _burnLiquidityShare(
            currentPool.baseLower,
            currentPool.baseUpper,
            shares,
            totalSupply
        );

        // Sum up total amounts owed to recipient
        amount0 = unusedAmount0 + baseAmount0;
        amount1 = unusedAmount1 + baseAmount1;
        require(amount0 >= amount0Min, "amount0Min");
        require(amount1 >= amount1Min, "amount1Min");

        // Push tokens to recipient
        if (amount0 > 0)
            require(token0.transfer(to, amount0), "transfer failed");
        if (amount1 > 0)
            require(token1.transfer(to, amount1), "transfer failed");

        emit Withdraw(msg.sender, to, shares, amount0, amount1);
    }

    /**
     * @notice Reranges current liquidity range to _tickRange
     * @param _tickRange pool range in ticks
     * @param _poolId pool's id
     */
    function rerange(int24 _tickRange, uint8 _poolId) external onlyStrategy {
        {
            uint8 poolsLen;
            for(uint256 i; i < 3; i++){
                if(address(pools[i].pool) != address(0)){
                    poolsLen++;
                }
            }
            require(_poolId >= 0 && _poolId < poolsLen, "w Pool");
        }
        currentPool = pools[_poolId];

        int24 _tickSpacing = currentPool.pool.tickSpacing();
        int24 _baseLowerPrev = currentPool.baseLower;
        int24 _baseUpperPrev = currentPool.baseUpper;
        int24 _tick = currentPool.tick;

        int256 deltaLower = int256(_tick) - int256(_baseLowerPrev);
        int256 deltaUpper = int256(_baseUpperPrev) - int256(_tick);
        int24 _baseLower = (_tick -
            int24((deltaLower * _tickRange) / (deltaLower + deltaUpper)));
        int24 _baseUpper = (_tick +
            int24((deltaUpper * _tickRange) / (deltaLower + deltaUpper)));

        int128 _lowerCorrection = (_baseLower > 0)
            ? _baseLower % _tickSpacing
            : -_baseLower % _tickSpacing;
        int128 _upperCorrection = (_baseUpper > 0)
            ? _baseUpper % _tickSpacing
            : -_baseUpper % _tickSpacing;

        _baseLower /= _tickSpacing;
        _baseUpper /= _tickSpacing;

        if (_lowerCorrection >= _tickSpacing / 2)
            _baseLower = (_baseLower > 0) ? (_baseLower + 1) : (_baseLower - 1);
        if (_upperCorrection >= _tickSpacing / 2)
            _baseUpper = (_baseUpper > 0) ? (_baseUpper + 1) : (_baseUpper - 1);

        _baseLower *= _tickSpacing;
        _baseUpper *= _tickSpacing;

        emit Rerange(_baseLower, _baseUpper);

        (, _tick, , , , , ) = currentPool.pool.slot0();

        _checkRange(_baseLower, _baseUpper);
        // Withdraw all current liquidity from Uniswap pool
        {
            (uint128 baseLiquidity, , , , ) = _position(
                _baseLowerPrev,
                _baseUpperPrev
            );
            _burnAndCollect(_baseLowerPrev, _baseUpperPrev, baseLiquidity);
        }

        // Emit snapshot to record balances and supply
        uint256 balance0 = getBalance0();
        uint256 balance1 = getBalance1();
        emit Snapshot(_tick, balance0, balance1, totalSupply());

        // Place base order on Uniswap
        uint128 liquidity = _liquidityForAmounts(
            _baseLower,
            _baseUpper,
            balance0,
            balance1
        );
        _mintLiquidity(_baseLower, _baseUpper, liquidity);
        (currentPool.baseLower, currentPool.baseUpper) = (
            _baseLower,
            _baseUpper
        );

        currentPool.tick = _tick;
        pools[_poolId] = currentPool;
    }

    /**
     * @notice Updates vault's positions. Can only be called by the strategy.
     */
    function emergencyRebalance(
        uint8 poolId,
        int256 swapAmount,
        uint160 sqrtPriceLimitX96,
        int24 _baseLower,
        int24 _baseUpper
    ) external nonReentrant onlyStrategy {
        require(poolId >= 0 && poolId < 3, "Wrong pool id");
        currentPool = pools[poolId];
        _checkRange(_baseLower, _baseUpper);

        (, int24 _tick, , , , , ) = currentPool.pool.slot0();

        // Withdraw all current liquidity from Uniswap pool

        {
            (uint128 baseLiquidity, , , , ) = _position(
                currentPool.baseLower,
                currentPool.baseUpper
            );

            _burnAndCollect(
                currentPool.baseLower,
                currentPool.baseUpper,
                baseLiquidity
            );

        }

        // Emit snapshot to record balances and supply
        uint256 balance0 = getBalance0();
        uint256 balance1 = getBalance1();

        emit Snapshot(_tick, balance0, balance1, totalSupply());

        if (swapAmount != 0) {
            currentPool.pool.swap(
                address(this),
                swapAmount > 0,
                swapAmount > 0 ? swapAmount : -swapAmount,
                sqrtPriceLimitX96,
                ""
            );
            balance0 = getBalance0();
            balance1 = getBalance1();
        }

        // Place base order on Uniswap
        uint128 liquidity = _liquidityForAmounts(
            _baseLower,
            _baseUpper,
            balance0,
            balance1
        );

        _mintLiquidity(_baseLower, _baseUpper, liquidity);
        (currentPool.baseLower, currentPool.baseUpper) = (
            _baseLower,
            _baseUpper
        );

        balance0 = getBalance0();
        balance1 = getBalance1();

        currentPool.tick = _tick;
        pools[poolId] = currentPool;
    }

    /// @dev Callback for Uniswap V3 pool.
    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        require(msg.sender == address(currentPool.pool));
        if (amount0 > 0)
            require(token0.transfer(msg.sender, amount0), "transfer failed");
        if (amount1 > 0)
            require(token1.transfer(msg.sender, amount1), "transfer failed");
    }

    /// @dev Callback for Uniswap V3 pool.
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        require(msg.sender == address(currentPool.pool));
        if (amount0Delta > 0)
            require(
                token0.transfer(msg.sender, uint256(amount0Delta)),
                "transfer failed"
            );
        if (amount1Delta > 0)
            require(
                token1.transfer(msg.sender, uint256(amount1Delta)),
                "transfer failed"
            );
    }

    /**
     * @notice Used to collect accumulated protocol fees.
     */
    function collectProtocol(
        uint256 amount0,
        uint256 amount1,
        address to
    ) external onlyGovernance {
        currentPool.accruedProtocolFees0 -= amount0;
        currentPool.accruedProtocolFees1 -= amount1;
        if (amount0 > 0)
            require(token0.transfer(to, amount0), "transfer failed");
        if (amount1 > 0)
            require(token1.transfer(to, amount1), "transfer failed");
    }

    /**
     * @notice Removes tokens accidentally sent to this vault.
     */
    function sweep(
        IERC20 token,
        uint256 amount,
        address to
    ) external onlyGovernance {
        require(token != token0 && token != token1, "token");
        require(token.transfer(to, amount), "transfer failed");
    }

    /**
     * @notice Used to change the protocol fee charged on pool fees earned from
     * Uniswap, expressed as multiple of 1e-6.
     */
    function setProtocolFee(uint256 _protocolFee) external onlyGovernance {
        require(_protocolFee < 1e6, "protocolFee");
        currentPool.protocolFee = _protocolFee;
    }

    /**
     * @notice Used to change deposit cap for a guarded launch or to ensure
     * vault doesn't grow too large relative to the pool. Cap is on total
     * supply rather than amounts of token0 and token1 as those amounts
     * fluctuate naturally over time.
     */
    function setMaxTotalSupply(uint256 _maxTotalSupply)
        external
        onlyGovernance
    {
        maxTotalSupply = _maxTotalSupply;
    }

    /**
     * @notice Used to change strategy address
     */
    function setStrategy(address _newStrategy)
        external
        onlyGovernance
    {
        require(strategy != _newStrategy, "strategy already set");
        strategy = _newStrategy;
    }

    /**
     * @notice Used to renounce emergency powers. Cannot be undone.
     */
    function finalize() external onlyGovernance {
        finalized = true;
    }

    /**
     * @notice Transfers tokens to governance in case of emergency. Cannot be
     * called if already finalized.
     */
    function emergencyWithdraw(IERC20 token, uint256 amount) external onlyGovernance {
        require(!finalized, "finalized");
        require(token.transfer(msg.sender, amount), "Transfer error");
    }

    /**
     * @notice Removes liquidity in case of emergency.
     */
    function emergencyBurn(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) external onlyGovernance {
        currentPool.pool.burn(tickLower, tickUpper, liquidity);
        currentPool.pool.collect(
            address(this),
            tickLower,
            tickUpper,
            type(uint128).max,
            type(uint128).max
        );
    }

    /**
     * @notice Used to change vault's operation mode
     */
    function setOperationMode(uint8 _mode) external onlyGovernance {
        require(operationMode != _mode, "already set");
        operationMode = _mode;
    }

    /**
     * @notice Used to get vault's operation mode
     */
    function getOperationMode() external override view returns(uint8) {
        return operationMode;
    }


    /** 
     @dev Updates info of specified pool
     @param _info new info to be set
     @param _poolId pool to update
     */
    function setPoolInfo(PoolInfo memory _info, uint8 _poolId)
        external
        onlyGovernance
    {
        require(_poolId >= 0 && _poolId < pools.length, "w Pool");
        pools[_poolId] = _info;
    }

    /**
     * @notice Calculates the vault's total holdings of token0 and token1 - in
     * other words, how much of each token the vault would hold if it withdrew
     * all its liquidity from Uniswap.
     */
    function getTotalAmounts()
        public
        view
        override
        returns (uint256 total0, uint256 total1)
    {
        (uint256 baseAmount0, uint256 baseAmount1) = getPositionAmounts(
            currentPool.baseLower,
            currentPool.baseUpper
        );
        total0 = getBalance0() + baseAmount0;
        total1 = getBalance1() + baseAmount1;
    }

    /**
     * @notice Amounts of token0 and token1 held in vault's position. Includes
     * owed fees but excludes the proportion of fees that will be paid to the
     * protocol. Doesn't include fees accrued since last poke.
     */
    function getPositionAmounts(int24 tickLower, int24 tickUpper)
        public
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (
            uint128 liquidity,
            ,
            ,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = _position(tickLower, tickUpper);
        (amount0, amount1) = _amountsForLiquidity(
            tickLower,
            tickUpper,
            liquidity
        );

        // Subtract protocol fees
        uint256 oneMinusFee = uint256(1e6) - (currentPool.protocolFee);
        amount0 += uint256(tokensOwed0) * oneMinusFee / 1e6;
        amount1 += uint256(tokensOwed1) * oneMinusFee / 1e6;

    }

    /**
     * @notice Balance of token0 in vault not used in any position.
     */
    function getBalance0() public view returns (uint256) {
        return
            token0.balanceOf(address(this)) -
            (currentPool.accruedProtocolFees0);
    }

    /**
     * @notice Balance of token1 in vault not used in any position.
     */
    function getBalance1() public view returns (uint256) {
        return
            token1.balanceOf(address(this)) -
            (currentPool.accruedProtocolFees1);
    }

    /// @dev Do zero-burns to poke a position on Uniswap so earned fees are
    /// updated. Should be called if total amounts needs to include up-to-date
    /// fees.
    function _poke(int24 tickLower, int24 tickUpper) internal {
        (uint128 liquidity, , , , ) = _position(tickLower, tickUpper);
        if (liquidity > 0) {
            currentPool.pool.burn(tickLower, tickUpper, 0);
        }
    }

    /// @dev Calculates the largest possible `amount0` and `amount1` such that
    /// they're in the same proportion as total amounts, but not greater than
    /// `amount0Desired` and `amount1Desired` respectively.
    function _calcSharesAndAmounts(
        uint256 amount0Desired,
        uint256 amount1Desired
    )
        internal
        view
        returns (
            uint256 shares,
            uint256 amount0,
            uint256 amount1
        )
    {
        uint256 totalSupply = totalSupply();
        (uint256 total0, uint256 total1) = getTotalAmounts();

        // If total supply > 0, vault can't be empty
        assert(totalSupply == 0 || total0 > 0 || total1 > 0);

        if (totalSupply == 0) {
            // For first deposit, just use the amounts desired
            amount0 = amount0Desired;
            amount1 = amount1Desired;
            shares = Math.max(amount0, amount1);
        } else if (total0 == 0) {
            amount1 = amount1Desired;
            shares = (amount1 * totalSupply) / total1;
        } else if (total1 == 0) {
            amount0 = amount0Desired;
            shares = (amount0 * totalSupply) / total0;
        } else {
            uint256 cross = Math.min(
                amount0Desired * total1,
                amount1Desired * total0
            );
            require(cross > 0, "cross");

            // Round up amounts
            amount0 = (cross - 1) / total1 + 1;
            amount1 = (cross - 1) / total0 + 1;
            shares = ((cross * totalSupply) / total0) / total1;
        }
    }

    /// @dev Withdraws share of liquidity in a range from Uniswap pool.
    function _burnLiquidityShare(
        int24 tickLower,
        int24 tickUpper,
        uint256 shares,
        uint256 totalSupply
    ) internal returns (uint256 amount0, uint256 amount1) {
        (uint128 totalLiquidity, , , , ) = _position(tickLower, tickUpper);
        uint256 liquidity = (uint256(totalLiquidity) * shares) / totalSupply;

        if (liquidity > 0) {
            (
                uint256 burned0,
                uint256 burned1,
                uint256 fees0,
                uint256 fees1
            ) = _burnAndCollect(tickLower, tickUpper, _toUint128(liquidity));

            // Add share of fees
            amount0 = ((burned0 + fees0) * shares) / totalSupply;
            amount1 = ((burned1 + fees1) * shares) / totalSupply;
        }
    }

    function _checkRange(int24 tickLower, int24 tickUpper) internal view {
        int24 _tickSpacing = currentPool.pool.tickSpacing();
        require(tickLower < tickUpper, "tickLower < tickUpper");
        require(tickLower >= TickMath.MIN_TICK, "tickLower too low");
        require(tickUpper <= TickMath.MAX_TICK, "tickUpper too high");
        require(tickLower % _tickSpacing == 0, "tickLower % tickSpacing");
        require(tickUpper % _tickSpacing == 0, "tickUpper % tickSpacing");
    }

    /// @dev Withdraws liquidity from a range and collects all fees in the
    /// process.
    function _burnAndCollect(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    )
        internal
        returns (
            uint256 burned0,
            uint256 burned1,
            uint256 feesToVault0,
            uint256 feesToVault1
        )
    {
        if (liquidity > 0) {
            (burned0, burned1) = currentPool.pool.burn(
                tickLower,
                tickUpper,
                liquidity
            );
        }

        // Collect all owed tokens including earned fees
        (uint256 collect0, uint256 collect1) = currentPool.pool.collect(
            address(this),
            tickLower,
            tickUpper,
            type(uint128).max,
            type(uint128).max
        );

        feesToVault0 = collect0 - burned0;
        feesToVault1 = collect1 - burned1;
        uint256 feesToProtocol0;
        uint256 feesToProtocol1;

        // Update accrued protocol fees
        uint256 _protocolFee = currentPool.protocolFee;
        if (_protocolFee > 0) {
            feesToProtocol0 = (feesToVault0 * _protocolFee) / 1e6;
            feesToProtocol1 = (feesToVault1 * _protocolFee) / 1e6;
            feesToVault0 = feesToVault0 - feesToProtocol0;
            feesToVault1 = feesToVault1 - feesToProtocol1;
            currentPool.accruedProtocolFees0 += feesToProtocol0;
            currentPool.accruedProtocolFees1 += feesToProtocol1;
        }
        emit CollectFees(
            feesToVault0,
            feesToVault1,
            feesToProtocol0,
            feesToProtocol1
        );
    }

    /// @dev Deposits liquidity in a range on the Uniswap pool.
    function _mintLiquidity(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal {
        if (liquidity > 0) {
            currentPool.pool.mint(
                address(this),
                tickLower,
                tickUpper,
                liquidity,
                ""
            );
        }
    }

    /// @dev Wrapper around `IUniswapV3Pool.positions()`.
    function _position(int24 tickLower, int24 tickUpper)
        internal
        view
        returns (
            uint128,
            uint256,
            uint256,
            uint128,
            uint128
        )
    {
        bytes32 positionKey = PositionKey.compute(
            address(this),
            tickLower,
            tickUpper
        );
        return currentPool.pool.positions(positionKey);
    }

    /// @dev Wrapper around `LiquidityAmounts.getAmountsForLiquidity()`.
    function _amountsForLiquidity(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal view returns (uint256, uint256) {
        (uint160 sqrtRatioX96, , , , , , ) = currentPool.pool.slot0();
        return
            LiquidityAmounts.getAmountsForLiquidity(
                sqrtRatioX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );
    }

    /// @dev Wrapper around `LiquidityAmounts.getLiquidityForAmounts()`.
    function _liquidityForAmounts(
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    ) internal view returns (uint128) {
        (uint160 sqrtRatioX96, , , , , , ) = currentPool.pool.slot0();
        require(amount0 > 0, "!am0");

        return
            LiquidityAmounts.getLiquidityForAmounts(
                sqrtRatioX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );
    }

    /// @dev Casts uint256 to uint128 with overflow check.
    function _toUint128(uint256 x) internal pure returns (uint128) {
        assert(x <= type(uint128).max);
        return uint128(x);
    }
}