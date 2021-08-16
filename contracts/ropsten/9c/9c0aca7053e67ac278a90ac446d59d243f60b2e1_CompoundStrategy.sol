//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../interfaces/compound/ICERC20.sol";
import "../interfaces/compound/IComptroller.sol";
import "../interfaces/compound/ICompoundInterestRateModel.sol";
import "../interfaces/chainlink/AggregatorV3Interface.sol";
import "../interfaces/uniswapV2/IUniswapV2Router02.sol";
import "./BaseRhoStrategy.sol";
import "../libraries/uniswapV3/Path.sol";
import "../interfaces/ITokenExchange.sol";
import "../interfaces/uniswapV3/ISwapRouter.sol";
import "../interfaces/IPriceOracle.sol";

contract CompoundStrategy is BaseRhoStrategy {
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;

    string public constant override NAME = "Compound";

    ICERC20 public cToken;
    IComptroller public comptroller;
    IERC20MetadataUpgradeable public comp;

    IPriceOracle public compUsdPriceOracle;
    ITokenExchange public tokenExchange;

    function initialize(
        address _underlyingAddr,
        address _ctokenAddr,
        address _comptrollerAddr,
        address _tokenExchange,
        address _compAddr,
        address _compUsdPriceOracleAddr,
        uint256 _lockDurationInBlock,
        uint256 _blocksPerYear
    ) public initializer {
        BaseRhoStrategy.__initialize(_underlyingAddr, _lockDurationInBlock);
        cToken = ICERC20(_ctokenAddr);
        comptroller = IComptroller(_comptrollerAddr);
        comp = IERC20MetadataUpgradeable(_compAddr);
        compUsdPriceOracle = IPriceOracle(_compUsdPriceOracleAddr);
        BLOCK_PER_YEAR = _blocksPerYear;
        tokenExchange = ITokenExchange(_tokenExchange);
    }

    function supplyRate() external view override returns (uint256) {
        return cToken.supplyRatePerBlock() * BLOCK_PER_YEAR;
    }

    function balanceOfUnderlying() public view override returns (uint256) {
        return (cToken.balanceOf(address(this)) * cToken.exchangeRateStored()) / 1e18;
    }

    function updateBalanceOfUnderlying() public override returns (uint256) {
        // cToken.exchangeRateCurrent();
        return cToken.balanceOfUnderlying(address(this));
    }

    function _bonusPerBlockPerUnderlying() internal view virtual returns (uint256 usdPerBlockPerUnderlying) {
        uint256 compPerBlockPerCtoken =
            (comptroller.compSpeeds(address(cToken)) * 10**cToken.decimals()) / cToken.totalSupply(); // 18, per cToken
        uint256 exchangeRate = (cToken.exchangeRateStored() * 10**cToken.decimals()) / 10**underlying.decimals(); // 18
        uint256 compPerBlockPerUnderlying = (compPerBlockPerCtoken * 1e18) / exchangeRate; // 18, per underlying
        usdPerBlockPerUnderlying =
            (compPerBlockPerUnderlying * compUsdPriceOracle.price(address(comp))) /
            10**compUsdPriceOracle.decimals();
    }

    function bonusRatePerBlock() external view override returns (uint256) {
        return _bonusPerBlockPerUnderlying();
    }

    function bonusSupplyRate() external view override returns (uint256) {
        return _bonusPerBlockPerUnderlying() * BLOCK_PER_YEAR;
    }

    function effectiveSupplyRate() external view override returns (uint256 _amount) {
        return (cToken.supplyRatePerBlock() + _bonusPerBlockPerUnderlying()) * BLOCK_PER_YEAR;
    }

    function effectiveSupplyRate(uint256 delta, bool isPositive) external view override returns (uint256) {
        uint256 newCash = isPositive ? cToken.getCash() + delta : cToken.getCash() - delta;
        return
            (ICompoundInterestRateModel(cToken.interestRateModel()).getSupplyRate(
                newCash,
                cToken.totalBorrows(),
                cToken.totalReserves(),
                cToken.reserveFactorMantissa()
            ) + _bonusPerBlockPerUnderlying()) * BLOCK_PER_YEAR;
    }

    function deployInternal(uint256 _amount) internal override {
        underlying.safeIncreaseAllowance(address(cToken), _amount);
        assert(cToken.mint(_amount) == 0);
    }

    function withdrawUnderlyingInternal(uint256 _amount) internal override {
        uint256 errorcode = cToken.redeemUnderlying(_amount);
        string memory message = "CompoundStrategy: Fail to withdraw from compound";
        if (errorcode == 14) {
            message = "CompoundStrategy: compound has not enough cash";
        }
        require(errorcode == 0, message);
        underlying.safeTransfer(_msgSender(), _amount);
    }

    function withdrawAllCashAvailableInternal() internal override {
        uint256 balance = updateBalanceOfUnderlying();
        uint256 withdrawable = underlyingWithdrawable();
        if (balance > withdrawable) {
            emit StrategyOutOfCash(balance, withdrawable);
            require(cToken.redeemUnderlying(withdrawable) == 0, "CompoundStrategy: Fail to withdraw from compound");
            underlying.safeTransfer(_msgSender(), withdrawable);
            return;
        }
        require(
            cToken.redeem(cToken.balanceOf(address(this))) == 0,
            "CompoundStrategy: Fail to withdraw from compound"
        );
        underlying.safeTransfer(_msgSender(), balance);
    }

    function supplyRatePerBlock() external view override returns (uint256) {
        return cToken.supplyRatePerBlock();
    }

    function collectRewardToken() external override onlyRole(VAULT_ROLE) whenNotPaused nonReentrant {
        address[] memory holders = new address[](1);
        address[] memory cTokens = new address[](1);
        holders[0] = address(this);
        cTokens[0] = address(cToken);
        comptroller.claimComp(holders, cTokens, false, true);

        comp.safeIncreaseAllowance(address(tokenExchange), comp.balanceOf(address(this)));
        tokenExchange.sellExactInput(comp, underlying, _msgSender(), comp.balanceOf(address(this)));
    }

    function bonusToken() external view override returns (address) {
        return address(comp);
    }

    function bonusTokensAccrued() external view override returns (uint256) {
        return comptroller.compAccrued(address(this));
    }

    function shouldCollectReward(uint256 rewardCollectThreshold) external view override returns (bool) {
        uint256 compPrice = compUsdPriceOracle.price(address(comp));
        uint8 compPriceDec = compUsdPriceOracle.decimals();
        uint256 compQty = comp.balanceOf(address(this)) + comptroller.compAccrued(address(this));
        uint256 minUnderlyingQty =
            (((compQty * compPrice * 10**underlying.decimals()) / 10**comp.decimals() / 10**compPriceDec));
        return minUnderlyingQty > rewardCollectThreshold;
    }

    // withdraw random token transfer into this contract
    function sweepERC20Token(address token, address to) external override onlyRole(SWEEPER_ROLE) {
        require(token != address(underlying), "!safe");
        require(token != address(cToken), "!safe");
        super._sweepERC20Token(token, to);
    }

    function getCash() internal view override returns (uint256) {
        return cToken.getCash();
    }
}