// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import "./DarenBonus.sol";
import "./DarenMedal.sol";
import "./interfaces/IDarenOrder.sol";

contract DarenOrder is
    IDarenOrder,
    AccessControlEnumerableUpgradeable,
    PausableUpgradeable
{
    using SafeMathUpgradeable for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 private primaryKey; // Order index

    address public usdtToken; // The USDT token
    address public darenToken; // The Daren token
    address public darenBonus; // The DarenBonus contract
    address public darenMedal; // The DarenMedal contract

    uint256 public ratioBase;
    uint256 public feeRatio; // 2.5%
    address public feeTo;

    uint256 public voteFeeRatio; // 5%
    address public voteFeeTo;

    mapping(uint256 => Order) public orderIDList;

    uint256 public orderExpireTime; // Exipre after 30 days
    uint256 public voteExpireTime; // Exipie after 7 days

    bool public allowHolderToVote;
    uint256 public holdingThreshold;
    uint256 public voteLimit;

    // Vote: orderID => voter => bool
    mapping(uint256 => mapping(address => bool)) private orderVotedAddresses;
    mapping(uint256 => address[]) private orderVotedAddressList;

    function initialize(
        address _darenBonus,
        address _darenToken,
        address _darenMedal,
        address _usdtToken
    ) public initializer {
        __AccessControlEnumerable_init();
        __Pausable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);

        require(_usdtToken != address(0), "usdtToken should not be zero");
        require(_darenToken != address(0), "darenToken should not be zero");
        require(_darenBonus != address(0), "darenBonus should not be zero");
        require(_darenMedal != address(0), "darenMedal should not be zero");
        usdtToken = _usdtToken;
        darenBonus = _darenBonus;
        darenToken = _darenToken;
        darenMedal = _darenMedal;

        primaryKey = 0;

        orderExpireTime = 30;
        voteExpireTime = 7;

        allowHolderToVote = false;
        holdingThreshold = 100000;
        voteLimit = 50; // Voters can vote up to 50(/99) for one side.

        ratioBase = 10000;
        feeRatio = 250; // ratio base is 10000, 250 => 250 / 10000 => 2.5%
        voteFeeRatio = 500; // ratio base is 10000, 500 => 500 / 10000 => 5%

        feeTo = msg.sender;
        voteFeeTo = msg.sender;
    }

    function createOrder(
        string memory _name,
        uint256 _orderID,
        uint256 _value, // in wei
        address _seller
    ) external override returns (uint256 pk) {
        require(_seller != msg.sender, "Unable to purchase your own services.");
        require(_orderID > 0, "Order ID is invalid.");
        require(orderIDList[_orderID].pk <= 0, "Order ID already exists.");
        require(
            _value >= 5 * 10**ERC20(usdtToken).decimals(),
            "No free service."
        );

        ERC20(usdtToken).transferFrom(msg.sender, address(this), _value);

        primaryKey += 1;
        Order memory order = Order({
            pk: primaryKey,
            name: _name,
            orderID: _orderID,
            value: _value,
            seller: _seller,
            buyer: msg.sender,
            status: OrderStatus.Active,
            createdAt: block.timestamp,
            expiresAt: block.timestamp + orderExpireTime * 1 days,
            votes: OrderVotes(0, 0, VoteTarget.None, 0, 0)
        });

        orderIDList[_orderID] = order;
        emit OrderCreated({
            pk: primaryKey,
            name: _name,
            orderID: _orderID,
            value: _value,
            seller: _seller,
            buyer: msg.sender,
            createdAt: block.timestamp
        });
        return order.pk;
    }

    function getStatusKeyByValue(OrderStatus _status)
        internal
        pure
        returns (string memory strStatus)
    {
        if (OrderStatus.Active == _status) return "ACTIVE";
        if (OrderStatus.Submitted == _status) return "SUBMITTED";
        if (OrderStatus.Completed == _status) return "COMPLETED";
        if (OrderStatus.Withdrawn == _status) return "WITHDRAWN";

        if (OrderStatus.AgreeToRefund == _status) return "AGREE_TO_REFUND";
        if (OrderStatus.Refunded == _status) return "REFUNDED";

        if (OrderStatus.Voting == _status) return "VOTING";

        require(false, "Invalid status value");
    }

    function _cmpstr(string memory s1, string memory s2)
        internal
        pure
        returns (bool)
    {
        return
            keccak256(abi.encodePacked(s1)) == keccak256(abi.encodePacked(s2));
    }

    function getStatusValueByKey(string memory _status)
        internal
        pure
        returns (OrderStatus orderStatus)
    {
        if (_cmpstr("ACTIVE", _status)) return OrderStatus.Active;
        if (_cmpstr("SUBMITTED", _status)) return OrderStatus.Submitted;
        if (_cmpstr("COMPLETED", _status)) return OrderStatus.Completed;
        if (_cmpstr("WITHDRAWN", _status)) return OrderStatus.Withdrawn;

        if (_cmpstr("AGREE_TO_REFUND", _status))
            return OrderStatus.AgreeToRefund;
        if (_cmpstr("REFUNDED", _status)) return OrderStatus.Refunded;

        if (_cmpstr("VOTING", _status)) return OrderStatus.Voting;

        require(false, "Invalid status key");
    }

    function getOrder(uint256 _orderID)
        external
        view
        override
        returns (
            uint256 pk,
            string memory name,
            uint256 orderID,
            uint256 value,
            address seller,
            address buyer,
            string memory status,
            uint256 createdAt,
            OrderVotes memory votes
        )
    {
        require(_orderID > 0, "order ID should be greater than 0.");
        Order memory order = orderIDList[_orderID];
        require(order.pk > 0, "order does not exist.");

        return (
            order.pk,
            order.name,
            order.orderID,
            order.value,
            order.seller,
            order.buyer,
            getStatusKeyByValue(order.status),
            order.createdAt,
            order.votes
        );
    }

    function updateOrder(uint256 _orderID, string memory _toStatusStr)
        external
        override
    {
        Order storage order = orderIDList[_orderID];
        OrderStatus _toStatus = getStatusValueByKey(_toStatusStr);
        require(
            order.status == OrderStatus.Active ||
                order.status == OrderStatus.Submitted,
            "Order status can not be changed."
        );

        if (_toStatus == OrderStatus.Submitted) {
            require(
                order.status == OrderStatus.Active,
                "Only active orders can be submitted."
            );
            require(
                msg.sender == order.seller,
                "Only seller can submit the order."
            );

            order.status = OrderStatus.Submitted;
        } else if (_toStatus == OrderStatus.Completed) {
            require(
                order.status == OrderStatus.Submitted,
                "Only submitted order can be completed."
            );
            require(
                msg.sender == order.buyer,
                "Only buyer can confirm the order."
            );

            order.status = OrderStatus.Completed;
        } else if (_toStatus == OrderStatus.AgreeToRefund) {
            require(
                msg.sender == order.seller,
                "Only seller can agree to refund."
            );

            order.status = OrderStatus.AgreeToRefund;
        } else if (_toStatus == OrderStatus.Voting) {
            require(
                msg.sender == order.buyer,
                "Only buyer can request a vote."
            );

            order.votes.createdAt = block.timestamp;
            order.votes.expireAt = block.timestamp + voteExpireTime * 1 days;

            order.status = OrderStatus.Voting;
        } else {
            require(false, "Invalid status.");
            return;
        }
        emit OrderUpdated({
            pk: order.pk,
            orderID: order.orderID,
            status: _toStatusStr
        });
    }

    function vote(uint256 _orderID, VoteTarget voteTarget) external {
        Order storage order = orderIDList[_orderID];
        require(
            msg.sender != order.buyer && msg.sender != order.seller,
            "Traders can not vote."
        );
        require(
            voteTarget == VoteTarget.Buyer || voteTarget == VoteTarget.Seller,
            "Invalid vote target."
        );
        require(
            order.status == OrderStatus.Voting,
            "Only voting order can be voted."
        );
        DarenMedal dm = DarenMedal(darenMedal);
        ERC20 u = ERC20(usdtToken);
        require(
            dm.availableToAuditByPrice(
                msg.sender,
                1001,
                order.value.div(10**u.decimals())
            ),
            "Only judge can vote."
        );
        uint256 currentTime = block.timestamp;
        require(currentTime < order.votes.expireAt, "Vote expired.");
        require(
            orderVotedAddresses[_orderID][msg.sender] != true,
            "You already voted."
        );

        if (voteTarget == VoteTarget.Buyer) {
            orderVotedAddresses[_orderID][msg.sender] = true;
            orderVotedAddressList[_orderID].push(msg.sender);
            order.votes.buyer = order.votes.buyer.add(1);
            order.votes.lastVote = VoteTarget.Buyer;
            return;
        } else if (voteTarget == VoteTarget.Seller) {
            orderVotedAddresses[_orderID][msg.sender] = true;
            orderVotedAddressList[_orderID].push(msg.sender);
            order.votes.seller = order.votes.seller.add(1);
            order.votes.lastVote = VoteTarget.Seller;
            return;
        } else {
            require(false, "Invalid vote target.");
        }
    }

    // Both buyer and seller can withdraw:
    //  buyer withdraws ACCEPT_TO_REFUND order.
    //  seller withdraws COMPLETED order.
    function withdrawOrder(uint256 _orderID) external override {
        Order storage order = orderIDList[_orderID];
        ERC20 u = ERC20(usdtToken);
        DarenBonus db = DarenBonus(darenBonus);

        uint256 fee = order.value.mul(feeRatio).div(10000);
        uint256 voteFee = order.value.mul(voteFeeRatio).div(10000);
        uint256 finalValue = order.value.sub(fee);

        if (order.status == OrderStatus.Completed) {
            // order completed, seller withdraw the order.
            db.completeOrder(order.buyer, order.seller, order.value, fee);

            u.transfer(order.seller, finalValue);
            u.transfer(feeTo, fee);
            order.status = OrderStatus.Withdrawn;

            emit OrderWithdrawn(
                order.pk,
                _orderID,
                getStatusKeyByValue(OrderStatus.Withdrawn)
            );
        } else if (order.status == OrderStatus.AgreeToRefund) {
            // After the seller agrees to refund, the buyer can withdraw the order.
            u.transfer(order.buyer, order.value);
            order.status = OrderStatus.Refunded;

            emit OrderWithdrawn(
                order.pk,
                _orderID,
                getStatusKeyByValue(OrderStatus.Refunded)
            );
        } else if (order.status == OrderStatus.Submitted) {
            // After the submitted order has expired, the seller can withdraw the order.
            require(
                block.timestamp > order.expiresAt,
                "Submitted order didn't finished."
            );

            db.completeOrder(order.buyer, order.seller, order.value, fee);

            u.transfer(order.seller, finalValue);
            u.transfer(feeTo, fee);
            order.status = OrderStatus.Withdrawn;

            emit OrderWithdrawn(
                order.pk,
                _orderID,
                getStatusKeyByValue(OrderStatus.Withdrawn)
            );
        } else if (order.status == OrderStatus.Active) {
            // After the active order has expired, the buyer can withdraw the order.
            require(
                block.timestamp > order.expiresAt,
                "The order is active and has not expired."
            );
            u.transfer(order.buyer, order.value);
            order.status = OrderStatus.Refunded;

            emit OrderWithdrawn(
                order.pk,
                _orderID,
                getStatusKeyByValue(OrderStatus.Refunded)
            );
        } else if (order.status == OrderStatus.Voting) {
            require(
                block.timestamp > order.votes.expireAt,
                "Voting didn't finished."
            );
            if (voteFee < 10**u.decimals() * 5) {
                voteFee = 10**u.decimals() * 5;
            }
            finalValue = order.value.sub(voteFee);

            if (
                order.votes.buyer > order.votes.seller ||
                (order.votes.buyer == order.votes.seller &&
                    order.votes.lastVote == VoteTarget.Seller) ||
                (order.votes.seller == 0 && order.votes.buyer == 0)
            ) {
                require(
                    msg.sender == order.buyer,
                    "You didn't win the Vote. Buyer won."
                );

                u.transfer(order.buyer, finalValue);
                u.transfer(voteFeeTo, voteFee);
                db.completeOrderByVoting(
                    orderVotedAddressList[order.orderID],
                    order.buyer,
                    order.seller,
                    order.value,
                    voteFee
                );
                order.status = OrderStatus.Refunded;

                emit OrderWithdrawn(
                    order.pk,
                    _orderID,
                    getStatusKeyByValue(OrderStatus.Refunded)
                );
            } else if (
                order.votes.seller > order.votes.buyer ||
                (order.votes.buyer == order.votes.seller &&
                    order.votes.lastVote == VoteTarget.Buyer)
            ) {
                require(
                    msg.sender == order.seller,
                    "You didn't win the Vote. Seller won."
                );

                u.transfer(order.seller, finalValue);
                u.transfer(voteFeeTo, voteFee);
                db.completeOrderByVoting(
                    orderVotedAddressList[order.orderID],
                    order.buyer,
                    order.seller,
                    order.value,
                    voteFee
                );
                order.status = OrderStatus.Withdrawn;

                emit OrderWithdrawn(
                    order.pk,
                    _orderID,
                    getStatusKeyByValue(OrderStatus.Withdrawn)
                );
            } else {
                require(false, "Vote EMPTY");
            }
        } else {
            require(false, "Invalid withdraw");
        }

        // totalFee = totalFee.add(fee);
        // availableFee = availableFee.add(fee);
        // order.value = order.value.sub(fee);
    }

    function getPK() external view onlyRole(ADMIN_ROLE) returns (uint256) {
        return primaryKey;
    }

    // Fee
    function setFeeRatio(uint256 _feeRatio) external onlyRole(ADMIN_ROLE) {
        feeRatio = _feeRatio;
    }

    function setVoteFeeRatio(uint256 _voteFeeRatio)
        external
        onlyRole(ADMIN_ROLE)
    {
        voteFeeRatio = _voteFeeRatio;
    }

    function setFeeTo(address payable _feeTo) external onlyRole(ADMIN_ROLE) {
        require(_feeTo != address(0), "Should not be zero address");
        feeTo = _feeTo;
    }

    function setVoteFeeTo(address payable _feeTo)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(_feeTo != address(0), "Should not be zero address");
        voteFeeTo = _feeTo;
    }

    // Expire
    function setOrderExpireTime(uint256 _expireTime)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(_expireTime > 0, "Expire days should be greater than 0");
        orderExpireTime = _expireTime;
    }

    function setVoteExpireTime(uint256 _voteExpireTime)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(_voteExpireTime > 0, "Expire days should be greater than 0");
        voteExpireTime = _voteExpireTime;
    }

    // Voting by token holders
    function setTokenThresholdForVoting(uint256 _holdingAmount)
        external
        onlyRole(ADMIN_ROLE)
    {
        if (_holdingAmount > 0) {
            allowHolderToVote = true;
            holdingThreshold = _holdingAmount;
        } else {
            allowHolderToVote = false;
        }
    }

    function setVoteLimit(uint256 _voteLimit) external onlyRole(ADMIN_ROLE) {
        require(_voteLimit > 3, "Vote limit should be greater than 3");
        voteLimit = _voteLimit;
    }

    // Set address
    function setDarenBonusAddress(address _address)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(_address != address(0), "Address should not be zero");
        darenBonus = _address;
    }

    function setDarenMedalAddress(address _address)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(_address != address(0), "Address should not be zero");
        darenMedal = _address;
    }

    function setUSDTTokenAddress(address _address)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(_address != address(0), "Address should not be zero");
        usdtToken = _address;
    }

    function setDarenTokenAddress(address _address)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(_address != address(0), "Address should not be zero");
        darenToken = _address;
    }
}