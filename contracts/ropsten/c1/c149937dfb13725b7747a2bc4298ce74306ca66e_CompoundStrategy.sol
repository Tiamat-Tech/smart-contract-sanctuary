//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../interfaces/compound/ICERC20.sol";
import "../interfaces/compound/IComptroller.sol";
import "../interfaces/compound/ICompoundInterestRateModel.sol";
import "../interfaces/uniswap/IUniswapV2Router02.sol";
import "../interfaces/chainlink/AggregatorV3Interface.sol";
import "./BaseRhoStrategy.sol";
import "../libraries/flurry.sol";

contract CompoundStrategy is BaseRhoStrategy, PausableUpgradeable {
    using Flurry for *;
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;

    ICERC20 public cToken;
    IComptroller public comptroller;
    IERC20MetadataUpgradeable public comp;
    IUniswapV2Router02 public uniswap;
    AggregatorV3Interface public compPriceFeed;

    string public override NAME;

    function initialize(
        address _underlyingAddr,
        address _ctokenAddr,
        address _comptrollerAddr,
        address _uniswapV2Router02Addr,
        address _compAddr,
        address _compPriceFeedAddr,
        uint256 _lockDurationInBlock,
        uint256 _blocksPerYear
    ) public initializer {
        PausableUpgradeable.__Pausable_init();
        BaseRhoStrategy.__initialize(_underlyingAddr, _lockDurationInBlock);
        cToken = ICERC20(_ctokenAddr);
        comptroller = IComptroller(_comptrollerAddr);
        uniswap = IUniswapV2Router02(_uniswapV2Router02Addr);
        comp = IERC20MetadataUpgradeable(_compAddr);
        compPriceFeed = AggregatorV3Interface(_compPriceFeedAddr);
        BLOCK_PER_YEAR = _blocksPerYear;
        NAME = "Compound";
    }

    function supplyRatePerBlock() external view override returns (uint256) {
        return cToken.supplyRatePerBlock();
    }

    function supplyRate() external view override returns (uint256) {
        return cToken.supplyRatePerBlock() * BLOCK_PER_YEAR;
    }

    function balanceOfUnderlying() public view override returns (uint256) {
        return (cToken.balanceOf(address(this)) * cToken.exchangeRateStored()) / 1e18;
    }

    function updateBalanceOfUnderlying() external override returns (uint256) {
        return cToken.balanceOfUnderlying(address(this));
    }

    function _bonusPerBlockPerUnderlying() internal view virtual returns (uint256) {
        uint256 compPerBlockPerCtoken =
            (comptroller.compSpeeds(address(cToken)) * 10**cToken.decimals()) / cToken.totalSupply(); // 18, per cToken
        uint256 exchangeRate = (cToken.exchangeRateStored() * 10**cToken.decimals()) / 10**underlying.decimals(); // 18
        uint256 compPerBlockPerUnderlying = (compPerBlockPerCtoken * 1e18) / exchangeRate; // 18, per underlying
        uint256 usdPerBlockPerUnderlying =
            (compPerBlockPerUnderlying * Flurry.getPriceFromChainlink(compPriceFeed)) / 10**compPriceFeed.decimals();
        return usdPerBlockPerUnderlying;
    }

    function bonusSupplyRate() external view override returns (uint256) {
        return _bonusPerBlockPerUnderlying() * BLOCK_PER_YEAR;
    }

    function effectiveSupplyRate() external view override returns (uint256 _amount) {
        return (cToken.supplyRatePerBlock() + _bonusPerBlockPerUnderlying()) * BLOCK_PER_YEAR;
    }

    function effectiveSupplyRate(uint256 delta, bool isPositive) external view override returns (uint256) {
        uint256 newCash;
        if (isPositive) {
            newCash = cToken.getCash() + delta;
        } else {
            newCash = cToken.getCash() - delta;
        }
        return
            (ICompoundInterestRateModel(cToken.interestRateModel()).getSupplyRate(
                newCash,
                cToken.totalBorrows(),
                cToken.totalReserves(),
                cToken.reserveFactorMantissa()
            ) + _bonusPerBlockPerUnderlying()) * BLOCK_PER_YEAR;
    }

    function deploy(uint256 _amount) public override onlyRole(VAULT_ROLE) {
        require(_amount > 0, "CompoundStrategy: deploy amount zero");
        underlying.safeIncreaseAllowance(address(cToken), _amount);
        assert(cToken.mint(_amount) == 0);
        emit Deploy(_amount);
    }

    function withdrawUnderlying(uint256 _amount) public override onlyRole(VAULT_ROLE) {
        require(cToken.redeemUnderlying(_amount) == 0, "CompoundStrategy: Fail to withdraw from Compound");
        underlying.safeTransfer(_msgSender(), _amount);
        emit WithdrawUnderlying(_amount);
    }

    // implement by redeem() but not redeemUnderlying() as cToken quantity is const
    function withdrawAll() external override onlyRole(VAULT_ROLE) {
        uint256 originalBal = underlying.balanceOf(address(this));
        require(
            cToken.redeem(cToken.balanceOf(address(this))) == 0,
            "CompoundStrategy: Fail to withdraw from compound"
        );
        uint256 amount = underlying.balanceOf(address(this)) - originalBal;
        underlying.safeTransfer(_msgSender(), amount);
        emit WithdrawAll();
    }

    function collectRewardToken() external virtual override onlyRole(VAULT_ROLE) {
        comptroller.claimComp(address(this));
    }

    function setRewardConversionThreshold(uint256 _threshold) external override onlyRole(VAULT_ROLE) {
        rewardConversionThreshold = _threshold;
    }

    function swapToken(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        uint256 deadline
    ) external virtual onlyRole(VAULT_ROLE) {
        require(comp.balanceOf(address(this)) >= amountIn, "not enough balance");
        require(amountIn > 0, "amountIn cannot be 0");
        require(
            path[0] == address(comp) && path[path.length - 1] == address(underlying),
            "path index 0 and index last should match stragegy award token and underlying token"
        );
        comp.safeIncreaseAllowance(address(uniswap), amountIn);
        uniswap.swapExactTokensForTokens(amountIn, amountOutMin, path, address(this), deadline);
    }

    // withdraw random token transfer into this contract
    function sweepERC20Token(address token, address to) external override onlyRole(SWEEPER_ROLE) {
        require(token != address(underlying), "!safe");
        require(token != address(cToken), "!safe");
        super._sweepERC20Token(token, to);
    }
}