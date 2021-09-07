// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// SafeMath is no longer needed starting with Solidity 0.8. The compiler now has built in overflow checking.

import "hardhat/console.sol";

/**
 * The konomi oracle subscription contract
 */
contract KonoSubscribe is Ownable {
    // The next subscription id to assign to
    uint64 public nextSubscriptionId;

    // Info for each user's subscription
    struct Subscription {
        // The timestamp of the subscription
        uint256 timestamp;
    }

    // The feed object of the subscription event
    struct Feed {
        uint8[] sources;
        string symbol;
        string slug;
    }

    // roughly around 300 kono per week
    uint256 public konoPerBlock = 1500000000000000;

    // roughly 201600 blocks per week
    uint256 public immutable week = 201600;

    // kono contract address
    IERC20 public kono;

    // Info of each user that stakes LP tokens.
    mapping(address => mapping(uint64 => Subscription))
        public userSubscriptions;

    /** A new subscription is made */
    event NewSubscription(
        address indexed user,
        uint64 subscriptionId,
        uint8[] sources,
        string symbol,
        string slug,
        uint256 leaseEnd,
        uint8 aggregationStrategy,
        uint256 amountPaid
    );

    /** A new subscription from substrate is made. */
    event NewSubstrateSubscription(
        address indexed user,
        uint64 subscriptionId,
        Feed feed,
        uint256 leaseEnd,
        uint8 aggregationStrategy,
        string connectionUrl,
        uint8 feedId,
        uint256 amountPaid
    );

    /** Unsubscribed from the feed and the amount refunded */
    event Unsubscribed(
        address indexed user,
        uint64 subscriptionId,
        uint256 amount
    );

    constructor(address _kono) {
        kono = ERC20(_kono);
    }

    function derivePayable(uint8[] calldata _sources, uint256 _leasePeriod)
        internal
        view
        returns (uint256)
    {
        return _leasePeriod * konoPerBlock * _sources.length;
    }

    function subscribeInternal(uint8[] calldata _sources, uint256 _leasePeriod)
        private
        returns (uint64, uint256)
    {
        uint64 subscriptionId = nextSubscriptionId++;
        Subscription storage subscription = userSubscriptions[msg.sender][
            subscriptionId
        ];
        subscription.timestamp = block.number;

        require(week <= _leasePeriod, "Lease too short");
        uint256 amountToPay = derivePayable(_sources, _leasePeriod);
        kono.transferFrom(msg.sender, address(this), amountToPay);

        return (subscriptionId, amountToPay);
    }

    function subscribe(
        uint8[] calldata _sources,
        string calldata _symbol,
        string calldata _slug,
        uint256 _leasePeriod,
        uint8 _aggregationStrategy
    ) external payable {
        uint64 subscriptionId;
        uint256 amountToPay;
        (subscriptionId, amountToPay) = subscribeInternal(
            _sources,
            _leasePeriod
        );

        emit NewSubscription(
            msg.sender,
            subscriptionId,
            _sources,
            _symbol,
            _slug,
            block.number + _leasePeriod,
            _aggregationStrategy,
            amountToPay
        );
    }

    function subscribeBySubstrate(
        uint8[] calldata _sources,
        string calldata _symbol,
        string calldata _slug,
        uint256 _leasePeriod,
        uint8 _aggregationStrategy,
        string calldata _connectionUrl,
        uint8 _feedId
    ) public payable {
        uint64 subscriptionId;
        uint256 amountToPay;
        (subscriptionId, amountToPay) = subscribeInternal(
            _sources,
            _leasePeriod
        );

        Feed memory feed = Feed(_sources, _symbol, _slug);
        {
            // avoids stack too deep errors
            emit NewSubstrateSubscription(
                msg.sender,
                subscriptionId,
                feed,
                block.number + _leasePeriod,
                _aggregationStrategy,
                _connectionUrl,
                _feedId,
                amountToPay
            );
        }
    }

    /**
     * Unsubscribe for the subscription id
     */
    function markUnsubscribed(
        address _user,
        uint64 _subscriptionId,
        uint256 _amount
    ) external onlyOwner {
        Subscription storage subscription = userSubscriptions[_user][
            _subscriptionId
        ];
        require(subscription.timestamp != 0, "Subscription does not exist!");

        // Remove the subscription from storage
        delete userSubscriptions[_user][_subscriptionId];

        emit Unsubscribed(_user, _subscriptionId, _amount);
    }

    function withdraw(uint256 _amount) external onlyOwner {
        kono.transfer(owner(), _amount);
    }
}