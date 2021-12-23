// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./interfaces/ITierable.sol";
import "./libraries/Depositable.sol";
import "./libraries/MaxDepositable.sol";
import "./libraries/MaxTierDepositable.sol";
import "./libraries/Schedulable.sol";
import "./libraries/Suspendable.sol";
import "./libraries/Collectable.sol";
import "./libraries/Authorizable.sol";

contract Sale is
    Initializable,
    AccessControlUpgradeable,
    Depositable,
    MaxDepositable,
    MaxTierDepositable,
    Schedulable,
    Suspendable,
    Collectable,
    Authorizable
{
    struct SaleConfiguration {
        IERC20Upgradeable depositToken; // token used to deposit
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
     * @notice Initializer
     * @param configuration: see {Sale.SaleConfiguration}
     */
    function initialize(SaleConfiguration memory configuration)
        external
        initializer
    {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
        __Depositable_init_unchained(configuration.depositToken);
        __MaxDepositable_init_unchained(configuration.maxTotalDeposit);
        __MaxTierDepositable_init_unchained(
            configuration.lockedToken,
            configuration.tiersMaxDeposit
        );
        __Schedulable_init_unchained(
            configuration.startDate,
            configuration.endDate
        );
        __Pausable_init_unchained();
        __Suspendable_init_unchained(configuration.pauser);
        __Collectable_init_unchained(configuration.collector);
        __EIP712_init_unchained("Launchblock", "1.0");
        __Authorizable_init_unchained(configuration.authorizer);
        __Sale_init_unchained();
    }

    function __Sale_init_unchained() internal onlyInitializing {
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

    uint256[50] private __gap;
}