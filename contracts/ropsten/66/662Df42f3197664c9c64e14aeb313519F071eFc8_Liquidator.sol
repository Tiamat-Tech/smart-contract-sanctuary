//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/ILendingPoolAddressesProvider.sol";
import "./interfaces/ILendingPool.sol";
import "./interfaces/ILiquidator.sol";
import "./base/Manager.sol";
import "./base/Multicall.sol";
import "./base/Address.sol";

contract Liquidator is ILiquidator, Multicall, Manager {
    using Address for address payable;
    using Address for address;
    address immutable lendingPoolAddressProvider;
    uint256 constant ACTIVE_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF; // prettier-ignore

    constructor(address poolAddress) {
        lendingPoolAddressProvider = poolAddress;
    }

    function getBatchUserData(address[] calldata users) override public view returns (UserData[] memory) {
        ILendingPoolAddressesProvider addressProvider = ILendingPoolAddressesProvider(lendingPoolAddressProvider);

        ILendingPool lendingPool = ILendingPool(addressProvider.getLendingPool());
        UserData[] memory usersData = new UserData[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            (,,,,,uint256 healthFactor) = lendingPool.getUserAccountData(users[i]);
            usersData[i].collateralAssets = getUserReservesData(users[i]);
            usersData[i].hlf = healthFactor;
        }

        return usersData;
    }

    function balanceOf(address user, address token) override public view returns (Balance memory) {
        if (token.isContract()) {
            return Balance(token, IERC20(token).balanceOf(user));
        }
        revert('INVALID_TOKEN');
    }

    function batchBalanceOf(address[] calldata users, address[] calldata tokens)
    override
    public
    view
    returns (UserBalances[] memory)
    {
        UserBalances[] memory usersBalances = new UserBalances[](users.length);

        for (uint256 i = 0; i < users.length; i++) {
            usersBalances[i] = UserBalances(users[i], new Balance[](tokens.length));
            for (uint256 j = 0; j < tokens.length; j++) {
                usersBalances[i].balances[j] = balanceOf(users[i], tokens[j]);
            }
        }

        return usersBalances;
    }

    function liquidate(
        address _collateral,
        address _reserve,
        address _user,
        uint256 _purchaseAmount,
        bool _receiveaToken
    )
    override
    payable
    public
    onlyManager
    returns (address, address)
    {
        ILendingPoolAddressesProvider addressProvider = ILendingPoolAddressesProvider(lendingPoolAddressProvider);

        ILendingPool lendingPool = ILendingPool(addressProvider.getLendingPool());

        if (IERC20(_reserve).allowance(address(this), address(lendingPool)) < _purchaseAmount) {
            require(IERC20(_reserve).approve(address(lendingPool), type(uint256).max), "Approval error");
        }

        if (IERC20(_reserve).balanceOf(address(this)) < _purchaseAmount) {
            revert("Liquidator: Not enough balance to cover purchase amount");
        }

        lendingPool.liquidationCall(_collateral, _reserve, _user, _purchaseAmount, _receiveaToken);

        return (_user, _reserve);
    }


    function getUserReservesData(address user)
    internal
    view
    returns (address[] memory)
    {
        ILendingPoolAddressesProvider addressProvider = ILendingPoolAddressesProvider(lendingPoolAddressProvider);
        ILendingPool lendingPool = ILendingPool(addressProvider.getLendingPool());
        address[] memory reserves = lendingPool.getReservesList();
        address[] memory collaterals = new address[](reserves.length);
        uint56 counter = 0;
        ILendingPool.UserConfigurationMap memory userConfig = lendingPool.getUserConfiguration(user);

        for (uint256 i = 0; i < reserves.length; i++) {
            ILendingPool.ReserveData memory baseData = lendingPool.getReserveData(reserves[i]);
            if (getFlagsMemory(baseData.configuration) && isUsingAsCollateral(userConfig, i)) {
                collaterals[counter] = reserves[i];
                counter = counter + 1;
            }
        }
        return collaterals;
    }

    function getFlagsMemory(ILendingPool.ReserveConfigurationMap memory self) internal pure returns (bool){
        return (self.data & ~ACTIVE_MASK) != 0;
    }

    function isUsingAsCollateral(ILendingPool.UserConfigurationMap memory self, uint256 reserveIndex)
    internal
    pure
    returns (bool)
    {
        require(reserveIndex < 128, 'Invalid index');
        return (self.data >> (reserveIndex * 2 + 1)) & 1 != 0;
    }
}