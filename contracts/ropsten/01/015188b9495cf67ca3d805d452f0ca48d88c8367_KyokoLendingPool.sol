// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "../credit/CreditSystem.sol";
import "../interfaces/IKToken.sol";
import "../token/KToken.sol";
import "../interfaces/ILendingPool.sol";
import "./LendingPoolStorage.sol";
import "../libraries/ReserveLogic.sol";
import "./DataTypes.sol";
import "../libraries/ValidationLogic.sol";
// import "../token/VersionedInitializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @dev kyoko ERC20 lending pool
 */
contract KyokoLendingPool is
    Initializable,
    ILendingPool,
    LendingPoolStorage,
    AccessControlEnumerableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using ReserveLogic for DataTypes.ReserveData;
    using SafeMathUpgradeable for uint256;

    bytes32 public constant LENDING_POOL_ADMIN =
        keccak256("LENDING_POOL_ADMIN");

    uint256 public constant LENDINGPOOL_REVISION = 0x0;

    modifier whenNotPaused() {
        _whenNotPaused();
        _;
    }

    function _whenNotPaused() internal view {
        require(!_paused, "LP_IS_PAUSED");
    }

    CreditSystem public creditContract;

    /**
     * @dev only the configurator can add reserve(loan assets).
     */
    modifier onlyLendingPoolAdmin() {
        require(
            hasRole(LENDING_POOL_ADMIN, _msgSender()),
            "Only the lending pool admin has permission to do this operation"
        );
        _;
    }

    // function getRevision() internal pure override returns (uint256) {
    //     return LENDINGPOOL_REVISION;
    // }

    function initialize(address _creditContract) public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        creditContract = CreditSystem(_creditContract);
    }

    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf
    ) external override whenNotPaused {
        DataTypes.ReserveData storage reserve = _reserves[asset];

        ValidationLogic.validateDeposit(reserve, amount);

        address kToken = reserve.kTokenAddress;
        reserve.updateState();
        reserve.updateInterestRates(asset, kToken, amount, 0);

        IERC20Upgradeable(asset).safeTransferFrom(msg.sender, kToken, amount);

        IKToken(kToken).mint(onBehalfOf, amount, reserve.liquidityIndex);

        emit Deposit(asset, msg.sender, onBehalfOf, amount);
    }

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external override whenNotPaused returns (uint256) {
        DataTypes.ReserveData storage reserve = _reserves[asset];

        address kToken = reserve.kTokenAddress;
        uint256 userBalance = IKToken(kToken).balanceOf(msg.sender);
        uint256 amountToWithdraw = amount;
        if (amount == type(uint256).max) {
            amountToWithdraw = userBalance;
        }
        ValidationLogic.validateWithdraw(
            asset,
            amountToWithdraw,
            userBalance,
            _reserves,
            _reservesList,
            _reservesCount
        );
        reserve.updateState();
        reserve.updateInterestRates(asset, kToken, 0, amountToWithdraw);
        IKToken(kToken).burn(
            msg.sender,
            to,
            amountToWithdraw,
            reserve.liquidityIndex
        );
        emit Withdraw(asset, msg.sender, to, amountToWithdraw);
        return amountToWithdraw;
    }

    /**
     * @dev guild borrow erc20 from this method
     */
    function borrow(
        address asset,
        uint256 amount,
        address onBehalfOf
    ) external override whenNotPaused {
        require(amount > 0, "BORROW_AMOUNT_LESS_THAN_ZERO");
        DataTypes.ReserveData storage reserve = _reserves[asset];
        _executeBorrow(
            ExecuteBorrowParams(
                asset,
                msg.sender,
                onBehalfOf,
                amount,
                reserve.kTokenAddress,
                true
            )
        );
    }

    function repay(
        address asset,
        uint256 amount,
        address onBehalfOf
    ) external override whenNotPaused returns (uint256) {
        DataTypes.ReserveData storage reserve = _reserves[asset];

        uint256 variableDebt = IERC20Upgradeable(reserve.variableDebtTokenAddress)
            .balanceOf(onBehalfOf);
        // uint256 scaledBorrow = IVariableDebtToken(reserve.variableDebtTokenAddress).scaledBalanceOf(onBehalfOf);

        ValidationLogic.validateRepay(
            reserve,
            amount,
            onBehalfOf,
            variableDebt
        );

        uint256 paybackAmount = variableDebt;

        if (amount < paybackAmount) {
            paybackAmount = amount;
        }

        reserve.updateState();

        IVariableDebtToken(reserve.variableDebtTokenAddress).burn(
            onBehalfOf,
            paybackAmount,
            reserve.variableBorrowIndex
        );

        address kToken = reserve.kTokenAddress;
        reserve.updateInterestRates(asset, kToken, paybackAmount, 0);

        IERC20Upgradeable(asset).safeTransferFrom(msg.sender, kToken, paybackAmount);

        IKToken(kToken).handleRepayment(msg.sender, paybackAmount);

        emit Repay(asset, onBehalfOf, msg.sender, paybackAmount);

        return paybackAmount;
    }

    /**
     * @dev Add new tokens that can be used for lending in the current pool.
     * At the beginning, only one stable currency may be supported, and other tokens will be added later.
     * Only Configurator can add.
     */
    function initReserve(
        address asset,
        address kTokenAddress,
        address variableDebtAddress,
        address interestRateStrategyAddress,
        uint8 reserveDecimals,
        uint16 reserveFactor
    ) external override onlyLendingPoolAdmin {
        // require(AddressUpgradeable.isContract(asset), "NOT_CONTRACT");

        _reserves[asset].init(
            kTokenAddress,
            variableDebtAddress,
            interestRateStrategyAddress
        );

        _addReserveToList(asset, reserveDecimals, reserveFactor);
    }

    function _addReserveToList(
        address asset,
        uint8 reserveDecimals,
        uint16 reserveFactor
    ) internal {
        uint256 reservesCount = _reservesCount;

        bool reserveAlreadyAdded = _reserves[asset].id != 0 ||
            _reservesList[0] == asset;

        if (!reserveAlreadyAdded) {
            _reserves[asset].id = uint8(reservesCount);
            _reserves[asset].decimals = uint8(reserveDecimals);
            _reserves[asset].factor = uint16(reserveFactor);
            _reservesList[reservesCount] = asset;

            _reservesCount = reservesCount + 1;
        }
    }

    /**
     * @dev Returns the normalized variable debt per unit of asset
     * @param asset The address of the underlying asset of the reserve
     * @return The reserve normalized variable debt
     */
    function getReserveNormalizedVariableDebt(address asset)
        external
        view
        override
        returns (uint256)
    {
        return _reserves[asset].getNormalizedDebt();
    }

    function paused() external view override returns (bool) {
        return _paused;
    }

    function setPause(bool val) external override onlyLendingPoolAdmin {
        _paused = val;
        if (_paused) {
            emit Paused();
        } else {
            emit Unpaused();
        }
    }

    struct ExecuteBorrowParams {
        address asset;
        address user;
        address onBehalfOf;
        uint256 amount;
        address kTokenAddress;
        bool releaseUnderlying;
    }

    event ExecuteBorrowParams_event(
        address asset,
        address user,
        address onBehalfOf,
        uint256 amount,
        address kTokenAddress,
        bool releaseUnderlying
    );

    event getUserAccountData_event(
        uint256 totalDebtInUSD,
        uint256 availableBorrowsInUSD
    );

    event validation(
        uint256 usd,
        DataTypes.ReserveData reserve,
        uint256 amount
    );

    event debtMint(
        address user,
        address onBehalfOf,
        uint256 amount,
        uint256 borrowIndex
    );

    event updateRates(
        address asset,
        address kTokenAddress,
        uint256 add,
        uint256 taken
    );

    event tokenMint(address user, uint256 amount);

    function _executeBorrow(ExecuteBorrowParams memory vars) internal {
        emit ExecuteBorrowParams_event(
            vars.asset,
            vars.user,
            vars.onBehalfOf,
            vars.amount,
            vars.kTokenAddress,
            vars.releaseUnderlying
        );
        DataTypes.ReserveData storage reserve = _reserves[vars.asset];

        (
            uint256 totalDebtInUSD,
            uint256 availableBorrowsInUSD
        ) = getUserAccountData(vars.user);
        emit getUserAccountData_event(totalDebtInUSD, availableBorrowsInUSD);

        ValidationLogic.validateBorrow(
            availableBorrowsInUSD,
            reserve,
            vars.amount
        );
        emit validation(availableBorrowsInUSD, reserve, vars.amount);

        reserve.updateState();

        IVariableDebtToken(reserve.variableDebtTokenAddress).mint(
            vars.user,
            vars.onBehalfOf,
            vars.amount,
            reserve.variableBorrowIndex
        );
        emit debtMint(
            vars.user,
            vars.onBehalfOf,
            vars.amount,
            reserve.variableBorrowIndex
        );

        reserve.updateInterestRates(
            vars.asset,
            vars.kTokenAddress,
            0,
            vars.releaseUnderlying ? vars.amount : 0
        );
        emit updateRates(
            vars.asset,
            vars.kTokenAddress,
            0,
            vars.releaseUnderlying ? vars.amount : 0
        );

        if (vars.releaseUnderlying) {
            IKToken(vars.kTokenAddress).transferUnderlyingTo(
                vars.user,
                vars.amount
            );
            emit tokenMint(vars.user, vars.amount);
        }

        emit Borrow(
            vars.asset,
            vars.user,
            vars.onBehalfOf,
            vars.amount,
            reserve.currentVariableBorrowRate
        );
    }

    function getReserveData(address asset)
        external
        view
        override
        returns (DataTypes.ReserveData memory)
    {
        return _reserves[asset];
    }

    function getUserAccountData(address user)
        public
        view
        override
        returns (uint256 totalDebtInWEI, uint256 availableBorrowsInWEI)
    {
        totalDebtInWEI = GenericLogic.calculateUserAccountData(
            user,
            _reserves,
            _reservesList,
            _reservesCount
        );
        (uint256 creditLine,) = creditContract.getCreditLine(user);
        // bytes memory payload = abi.encodeWithSignature("getCreditLine(address)", user);
        // (bool success, bytes memory line) = address(creditContract).staticcall(payload);
        // require(success, "getCreditLine(address) execute failed");
        // (uint256 creditLine,)  = abi.decode(line, (uint256, uint256));

        availableBorrowsInWEI = totalDebtInWEI >= creditLine
            ? 0
            : creditLine.sub(totalDebtInWEI);
    }

    function setReserveInterestRateStrategyAddress(
        address asset,
        address rateStrategyAddress
    ) external override onlyLendingPoolAdmin {
        _reserves[asset].interestRateStrategyAddress = rateStrategyAddress;
    }

    function getReserveNormalizedIncome(address asset)
        external
        view
        virtual
        override
        returns (uint256)
    {
        return _reserves[asset].getNormalizedIncome();
    }

    function getReservesList()
        external
        view
        override
        returns (address[] memory)
    {
        address[] memory _activeReserves = new address[](_reservesCount);

        for (uint256 i = 0; i < _reservesCount; i++) {
            _activeReserves[i] = _reservesList[i];
        }
        return _activeReserves;
    }

    function setReserveFactor(address asset, uint16 reserveFactor)
        external
        onlyLendingPoolAdmin
    {
        DataTypes.ReserveData storage reserve = _reserves[asset];
        reserve.setReserveFactor(reserveFactor);
        emit ReserveFactorChanged(asset, reserveFactor);
    }

    function setActive(address asset, bool active)
        external
        onlyLendingPoolAdmin
    {
        DataTypes.ReserveData storage reserve = _reserves[asset];
        reserve.setActive(active);
        emit ReserveActiveChanged(asset, active);
    }

    function getActive(address asset) external view override returns (bool) {
        DataTypes.ReserveData storage reserve = _reserves[asset];
        return reserve.getActive();
    }

    function setCreditStrategy(address _creditContract)
        external
        override
        onlyLendingPoolAdmin
    {
        creditContract = CreditSystem(_creditContract);
        emit CreditStrategyChanged(_creditContract);
    }

    function getCreditStrategy() external view override returns (address) {
        return address(creditContract);
    }
}