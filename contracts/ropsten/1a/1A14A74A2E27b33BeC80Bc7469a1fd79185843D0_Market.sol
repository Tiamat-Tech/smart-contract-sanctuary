// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import './License.sol';
import './Factory.sol';

// @author Julian Peters
// @title Market
contract Market {
    address public immutable factory;
    address public immutable USDC;

    // @param _factory Address of the Factory contract
    // @param _USDC Address of the USDC contract
    constructor(address _factory, address _USDC) {
        factory = _factory;
        USDC = _USDC;
    }

    // @notice Send funds to License contract and trigger the buying of a license
    // @param licenseType Type of license to buy
    // @param licenseContract Address of the license contract to buy from
    // @param referrerWallet Wallet that receives the referrer commission (usually the frontend). Set to 0x0 for none.
    function buyLicense(
        uint256 licenseType,
        address licenseContract,
        address referrerWallet
    ) external {
        // @dev Only allow buying of licenses created by factory (prevent interaction with malicious contracts)
        require(
            Factory(factory).licensePosition(licenseContract) != 0,
            'INVALID LICENSE'
        );

        uint256 cost = License(licenseContract).licenseTypeToPrice(licenseType);

        if (cost > 0) {
            uint256 allowance = IERC20(USDC).allowance(
                msg.sender,
                address(this)
            );
            require(allowance >= cost, 'INSUFFICIENT USDC ALLOWANCE');
            uint256 balance = IERC20(USDC).balanceOf(msg.sender);
            require(balance >= cost, 'INSUFFICIENT USDC BALANCE');
            TransferHelper.safeTransferFrom(
                USDC,
                msg.sender,
                licenseContract,
                cost
            );
        }

        License(licenseContract).buyLicense(
            msg.sender,
            licenseType,
            referrerWallet
        );
    }
}