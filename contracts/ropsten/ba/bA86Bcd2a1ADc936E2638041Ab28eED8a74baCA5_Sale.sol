// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ITierable.sol";
import "./libraries/Depositable.sol";
import "./libraries/MaxDepositable.sol";
import "./libraries/MaxTierDepositable.sol";
import "./libraries/Schedulable.sol";
import "./libraries/Suspendable.sol";
import "./libraries/Collectable.sol";
import "./libraries/Authorizable.sol";

contract Sale is
    AccessControl,
    Depositable,
    MaxDepositable,
    MaxTierDepositable,
    Schedulable,
    Suspendable,
    Collectable,
    Authorizable
{
    struct SaleConfiguration {
        IERC20 depositToken; // token used to deposit
        uint256 maxTotalDeposit; // max total deposited in the sale
        ITierable lockedToken; // locked token used to get the user tier
        uint256[] tiersMaxDeposit; // max amount deposited per tier (per user)
        uint256 startDate; // start date of the sale
        uint256 endDate; // end date of the sale
        address authorizer; // authorizer account, used to verify signed deposit
        address collector; // collector account
        address pauser; // pauser account
    }

    /**
     * @notice Constructor
     * @param configuration: see {Sale.SaleConfiguration}
     */
    constructor(SaleConfiguration memory configuration)
        Depositable(configuration.depositToken)
        MaxDepositable(configuration.maxTotalDeposit)
        MaxTierDepositable(
            configuration.lockedToken,
            configuration.tiersMaxDeposit
        )
        Schedulable(configuration.startDate, configuration.endDate)
        Authorizable(configuration.authorizer)
        Collectable(configuration.collector)
        Suspendable(configuration.pauser)
    {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @dev see {Depositable._deposit}
     */
    function _deposit(
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override(MaxTierDepositable, MaxDepositable, Depositable)
        whenMaxDepositNotReached(amount)
        returns (uint256)
    {
        return MaxTierDepositable._deposit(from, to, amount);
    }

    /**
     * @notice Deposit amount token to the sender address balance
     * must be signed by a member of `AUTHORIZER_ROLE`
     */
    function deposit(uint256 amount, bytes memory signature)
        external
        whenOpened
        whenNotPaused
        whenAuthorized(amount, _msgSender(), signature)
    {
        require(amount > 0, "Sale: amount must be > 0");
        _deposit(_msgSender(), _msgSender(), amount);
    }

    /**
     * @notice Collect all tokens deposited and send them to the caller's address
     * only callable by members of the collector role
     */
    function collect() external whenClosed whenNotPaused {
        uint256 amount = depositToken.balanceOf(address(this));
        _collect(_msgSender(), amount);
    }
}