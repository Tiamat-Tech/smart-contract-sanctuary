// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "./GrimBoostVaultYieldSource.sol";
import "./external/openzeppelin/ProxyFactory.sol";

/// @title GrimBoostVault Yield Source Proxy Factory
/// @notice Minimal proxy pattern for creating new GrimBoostVault Yield Sources
contract GrimBoostSourceProxyFactory is ProxyFactory {
    /// @notice Contract template for deploying proxied GrimBoostVault Yield Sources
    GrimBoostVaultYieldSource public instance;

    /// @notice Initializes the Factory with an instance of the GrimBoostVault Yield Source
    constructor() public {
        instance = new GrimBoostVaultYieldSource();
    }

    /// @notice Creates a new GrimBoostVault Yield Source as a proxy of the template instance
    /// @param _vault Vault address
    /// @param _token Underlying Token address
    /// @return A reference to the new proxied GrimBoostVault Yield Source
    function create(GrimBoostVaultInterface _vault, IERC20Upgradeable _token)
        public
        returns (GrimBoostVaultYieldSource)
    {
        GrimBoostVaultYieldSource GrimBoostSource = GrimBoostVaultYieldSource(
            deployMinimal(address(instance), "")
        );

        GrimBoostSource.initialize(_vault, _token);

        return GrimBoostSource;
    }
}