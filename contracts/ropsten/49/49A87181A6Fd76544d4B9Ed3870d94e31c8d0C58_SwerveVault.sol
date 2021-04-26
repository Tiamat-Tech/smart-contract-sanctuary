// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Detailed} from "./interfaces/IERC20Detailed.sol";
import {ISwerveGauge} from "./interfaces/swerve/ISwerveGauge.sol";
import {ISwerveMinter} from "./interfaces/swerve/ISwerveMinter.sol";
import {ISwervePool} from "./interfaces/swerve/ISwervePool.sol";
import {IUniswapRouter} from "./interfaces/uniswap/IUniswapRouter.sol";

contract SwerveVault is OwnableUpgradeable, ERC20Upgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 public constant MAX_BPS = 10_000;
    // used for swrv <> weth <> currency token route
    address public constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    // NOTE: A four-century period will be missing 3 of its 100 Julian leap years, leaving 97.
    //       So the average year has 365 + 97/400 = 365.2425 days
    //       ERROR(Julian): -0.0078
    //       ERROR(Gregorian): -0.0003
    uint256 public constant SECS_PER_YEAR = 31_556_952;

    // ================ WARNING ==================
    // ===== THIS CONTRACT IS INITIALIZABLE ======
    // === STORAGE VARIABLES ARE DECLARED BELOW ==
    // REMOVAL OR REORDER OF VARIABLES WILL RESULT
    // ========= IN STORAGE CORRUPTION ===========

    IERC20Upgradeable public token;
    uint256 public tokenIndex;
    uint256 public precisionMultiplier;

    // Swerve Finance Protocol
    ISwerveGauge public swerveGauge;
    ISwerveMinter public swerveMinter;
    ISwervePool public swervePool;
    IERC20Upgradeable public swusdToken;
    IERC20Upgradeable public swrvToken;
    // Control slippage of add_liquidity & remove_liquidity_one_coin (in BPS, <= 10k)
    uint256 public swerveSlippage;
    
    IUniswapRouter public uniRouter;
    address[] public uniSWRV2TokenPath;

    // allow pausing of deposits
    bool public isJoiningPaused;

    mapping(address => uint256) public latestJoinBlock;

    // Limit for totalAssets the Vault can hold
    uint256 public depositLimit;
    // Debt ratio for the Vault (in BPS, <= 10k)
    uint256 public debtRatio;
    // Governance Fee ratio for management of Vault (given to `rewards`  in BPS, <= 10k)
    uint256 public managementFeeRatio;
    // Governance Fee ratio for performance of Vault (given to `rewards`  in BPS, <= 10k)
    uint256 public performanceFeeRatio;
    // block.timestamp of the last time a harvest occured
    uint256 public lastHarvest;
    // Rewards address where fees are sent to
    address public rewards;

    // ======= STORAGE DECLARATION END ============

    function initialize(
        address _swervePool,
        uint256 _tokenIndex,
        address _swerveGauge,
        address _uniRouter
    ) public initializer {
        __Ownable_init_unchained();

        swervePool = ISwervePool(_swervePool);
        swusdToken = IERC20Upgradeable(swervePool.token());
        address underlyingCoin = swervePool.underlying_coins(int128(int256(_tokenIndex)));
        token = IERC20Upgradeable(underlyingCoin);
        tokenIndex = _tokenIndex;
        string memory name = string(abi.encodePacked(IERC20Detailed(underlyingCoin).name(), " sVault"));
        string memory symbol = string(abi.encodePacked("sv", IERC20Detailed(underlyingCoin).symbol()));
        __ERC20_init(name, symbol);

        swerveGauge = ISwerveGauge(_swerveGauge);
        swerveMinter = swerveGauge.minter();
        swrvToken = IERC20Upgradeable(swerveMinter.token());
        uniRouter = IUniswapRouter(_uniRouter);
        uniSWRV2TokenPath = [address(swrvToken), WETH, address(token)];
        swerveSlippage = 50; // 0.5%

        precisionMultiplier = 10 ** (IERC20Detailed(swervePool.token()).decimals() - decimals());
        depositLimit = 100_000 * (10 ** decimals());  // 100K
        debtRatio = 9500; // 95% pool value
        managementFeeRatio = 200; // 2% per year
        performanceFeeRatio = 1000; // 10% of yield
        lastHarvest = block.timestamp;
        rewards = _msgSender();
    }

    // Modifiers

    /**
     * @dev Vault can only be joined when it's unpaused
     */
    modifier joiningNotPaused() {
        require(!isJoiningPaused, "Swift: Deposit is paused");
        _;
    }

    // Events

    /**
     * @dev Emitted when joining is paused or unpaused
     * @param isJoiningPaused New pausing status
     */
    event JoiningPauseStatusChanged(bool isJoiningPaused);

    // ERC20Upgradeable

    function decimals() public override view virtual returns (uint8) {
        return IERC20Detailed(address(token)).decimals();
    }

    // Vault

    /**
     * @dev Allow pausing of deposits in case of emergency
     * @param status New deposit status
     */
    function changeJoiningPauseStatus(bool status) external onlyOwner {
        isJoiningPaused = status;
        emit JoiningPauseStatusChanged(status);
    }

    function setSwerveSlippage(uint256 slippage) external onlyOwner {
        require(slippage <= MAX_BPS, "Swift: slippage > MAX_BPS");
        swerveSlippage = slippage;
    }

    function setDepositLimit(uint256 limit) external onlyOwner {
        depositLimit = limit;
    }

    function setDebtRatio(uint256 ratio) external onlyOwner {
        require(ratio <= MAX_BPS, "Swift: ratio > MAX_BPS");
        debtRatio = ratio;
    }

    function setManagementFeeRatio(uint256 ratio) external onlyOwner {
        require(ratio <= MAX_BPS, "Swift: ratio > MAX_BPS");
        managementFeeRatio = ratio;
    }

    function setPerformanceFeeRatio(uint256 ratio) external onlyOwner {
        require(ratio <= MAX_BPS, "Swift: ratio > MAX_BPS");
        performanceFeeRatio = ratio;
    }

    function setRewards(address _rewards) external onlyOwner {
        rewards = _rewards;
    }

    /**
     * @dev Get total balance of Swerve.fi pool tokens
     * @return Balance of swerve pool tokens in this contract
     */
    function swusdTokenBalance() public view returns (uint256) {
        return swusdToken.balanceOf(address(this)) + swerveGauge.balanceOf(address(this));
    }

    /**
     * @dev Virtual value of swUSD tokens in the pool
     * @return swusdToken in USD
     */
    function swusdTokenValue() public view returns (uint256) {
        uint256 value = swusdTokenBalance() * swervePool.curve().get_virtual_price();
        return value / (precisionMultiplier * 1e18);
    }

    /**
     * @dev Currency token balance
     * @return Currency token balance
     */
    function currencyBalance() internal view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /**
     * @dev Calculate pool value in USD
     * "virtual price" of entire pool - underlying tokens, swUSD tokens
     * @return pool value in USD
     */
    function poolValue() public view returns (uint256) {
        return currencyBalance() + swusdTokenValue();
    }

    /**
     * @notice Expected amount of minted Swerve.fi swUSD tokens
     * Can be used to control slippage
     * @param currencyAmount amount to calculate for
     * @param _deposit set True for deposits, False for withdrawals
     * @return expected amount minted given currency amount
     */
    function calcTokenAmount(
        uint256 currencyAmount,
        bool _deposit
    ) public view returns (uint256) {
        uint256[4] memory amounts = [uint256(0), uint256(0), uint256(0), uint256(0)];
        amounts[tokenIndex] = currencyAmount;
        return swervePool.curve().calc_token_amount(amounts, _deposit);
    }

    /**
     * @param depositedAmount Amount of currency deposited
     * @param recipient Receiver of minted tokens
     * @return amount minted from this transaction
     */
    function mint(uint256 depositedAmount, address recipient) internal returns (uint256) {
        uint256 mintedAmount = depositedAmount;
        if (mintedAmount == 0) {
            return mintedAmount;
        }

        // first staker mints same amount deposited
        if (totalSupply() > 0) {
            mintedAmount = totalSupply() * depositedAmount / poolValue();
        }
        // mint pool tokens
        _mint(recipient, mintedAmount);

        return mintedAmount;
    }

    /**
     * @dev ensure enough Swerve.fi pool tokens are available
     * Check if current available amount of swUSD is enough and
     * withdraw remainder from gauge
     * @param neededAmount amount of swUSD required
     * @return amount of swUSD ensured
     */
    function ensureEnoughTokensAreAvailable(uint256 neededAmount) internal returns (uint256) {
        uint256 availableAmount = swusdToken.balanceOf(address(this));
        if (availableAmount < neededAmount) {
            uint256 withdrawAmount = neededAmount - availableAmount;
            uint256 gaugeBalance = swerveGauge.balanceOf(address(this));
            if (withdrawAmount > gaugeBalance) {
                withdrawAmount = gaugeBalance;
            }
            if (withdrawAmount > 0) {
                swerveGauge.withdraw(withdrawAmount);
            }
            return availableAmount + withdrawAmount;
        }
        return neededAmount;
    }

    function _removeLiquidityFromSwerve(uint256 swusdAmount) internal {
        // unstake in gauge
        swusdAmount = ensureEnoughTokensAreAvailable(swusdAmount);

        // remove currency token from swerve
        swusdToken.safeApprove(address(swervePool), 0);
        swusdToken.safeApprove(address(swervePool), swusdAmount);
        uint256 minCurrencyAmount = swusdAmount * swervePool.curve().get_virtual_price();
        minCurrencyAmount *= (MAX_BPS - swerveSlippage);
        minCurrencyAmount /= (precisionMultiplier * 1e18 * MAX_BPS);
        swervePool.remove_liquidity_one_coin(swusdAmount, int128(int256(tokenIndex)), minCurrencyAmount);
    }

    function removeLiquidityFromSwerve(uint256 amountToWithdraw) internal {
        // get rough estimate of how much swUSD we should sell
        uint256 roughSwerveTokenAmount = calcTokenAmount(amountToWithdraw, false) * 1005 / 1000;
        _removeLiquidityFromSwerve(roughSwerveTokenAmount);
    }

    /**
     * @dev Join the pool by depositing currency tokens
     * @param amount amount of currency token to deposit
     */
    function deposit(uint256 amount) external joiningNotPaused {
        require((poolValue() + amount) <= depositLimit, "Swift: Pool value cannot exceed depositLimit");
        
        mint(amount, _msgSender());

        latestJoinBlock[tx.origin] = block.number;
        token.safeTransferFrom(_msgSender(), address(this), amount);
    }

    /**
     * @dev Exit pool only with liquid tokens
     * This function will withdraw underlying tokens
     * @param shares amount of pool tokens to redeem for underlying tokens
     */
    function withdraw(uint256 shares) external {
        require(block.number != latestJoinBlock[tx.origin], "Swift: Cannot deposit and withdraw in same block");

        uint256 amountToWithdraw = poolValue() * shares / totalSupply();

        // burn tokens
        _burn(_msgSender(), shares);

        uint256 beforeBalance = currencyBalance();
        if (amountToWithdraw > beforeBalance) {
            removeLiquidityFromSwerve(amountToWithdraw - beforeBalance);
        }
        uint256 afterBalance = currencyBalance();
        if (amountToWithdraw > afterBalance) {
            amountToWithdraw = afterBalance;
        }

        token.safeTransfer(_msgSender(), amountToWithdraw);
    }

    /**
     * @dev Amount of tokens in Vault swerve has access to as a credit line
     * This will check the debt limit, as well as the tokens
     * available in the Vault, and determine the maximum amount of tokens
     * (if any) swerve may draw on
     * @return The quantity of tokens available for swerve to draw on
     */
    function creditAvailable() public view returns (uint256) {
        uint256 balance = currencyBalance();
        uint256 reserved = (MAX_BPS - debtRatio) * poolValue() / MAX_BPS;
        if (balance > reserved) {
            return balance - reserved;
        }
        return 0;
    }

    /**
     * @dev Deposit funds into Swerve.fi pool and stake in gauge
     * Called by owner to help manage funds in pool and save on gas for deposits
     */
    function earn() public onlyOwner {
        uint256 currencyAmount = creditAvailable();
        if (currencyAmount > 0) {
            uint256[4] memory amounts = [uint256(0), uint256(0), uint256(0), uint256(0)];
            amounts[tokenIndex] = currencyAmount;

            // add to swerve
            uint256 minMintAmount = calcTokenAmount(currencyAmount, true);
            minMintAmount *= (MAX_BPS - swerveSlippage);
            minMintAmount /= MAX_BPS;
            token.safeApprove(address(swervePool), 0);
            token.safeApprove(address(swervePool), currencyAmount);
            swervePool.add_liquidity(amounts, minMintAmount);

            // stake swusd tokens in gauge
            uint256 swusdBalance = swusdToken.balanceOf(address(this));
            swusdToken.safeApprove(address(swerveGauge), 0);
            swusdToken.safeApprove(address(swerveGauge), swusdBalance);
            swerveGauge.deposit(swusdBalance);
        }
    }

    function harvest() public onlyOwner {
        swerveMinter.mint(address(swerveGauge));
        uint256 beforeBalance = currencyBalance();
        // claiming rewards and liquidating them
        uint256 swrvBalance = swrvToken.balanceOf(address(this));
        if (swrvBalance > 0) {
            swrvToken.safeApprove(address(uniRouter), 0);
            swrvToken.safeApprove(address(uniRouter), swrvBalance);
            uniRouter.swapExactTokensForTokens(
                swrvBalance,
                0,
                uniSWRV2TokenPath,
                address(this),
                block.timestamp + 1 hours);
        }
        uint256 afterBalance = currencyBalance();
        if (afterBalance > beforeBalance) {
            uint256 gain = afterBalance - beforeBalance;
            uint256 debtValue = swusdTokenValue();
            uint256 managementFee = debtValue * (block.timestamp - lastHarvest) * managementFeeRatio;
            managementFee /= (SECS_PER_YEAR * MAX_BPS);
            uint256 performanceFee = gain * performanceFeeRatio / MAX_BPS;
            uint256 totalFee = managementFee + performanceFee;
            if (totalFee > gain) {
                totalFee = gain;
            }
            if (rewards != address(0)) {
                mint(totalFee, rewards);
            }
        }
        lastHarvest = block.timestamp;
    }

    function harvestAndEarn() external onlyOwner {
        harvest();
        earn();
    }

    /**
     * @dev Collect SWRV tokens minted by staking at gauge
     */
    function collectSWRV() external onlyOwner {
        swerveMinter.mint(address(swerveGauge));
        uint256 swrvBalance = swrvToken.balanceOf(address(this));
        swrvToken.safeTransfer(_msgSender(), swrvBalance);
        lastHarvest = block.timestamp;
    }

    /**
     * @dev Remove liquidity from swerve
     * @param swusdAmount amount of swerve pool tokens
     */
    function pull(uint256 swusdAmount) external onlyOwner {
        _removeLiquidityFromSwerve(swusdAmount);
    }

    /**
     * @dev Removes tokens from this Vault that are not the type of token managed
     * by this Vault. This may be used in case of accidentally sending the
     * wrong kind of token to this Vault.
     *
     * Tokens will be sent to `governance`.
     *
     * This will fail if an attempt is made to sweep the tokens that this Vault manages.
     *
     * This may only be called by governance.
     * @param _token The token to transfer out of this vault.
     */
    function sweep(address _token) external onlyOwner {
        uint256 balance = IERC20Upgradeable(_token).balanceOf(address(this));
        IERC20Upgradeable(_token).safeTransfer(_msgSender(), balance);
    }
}