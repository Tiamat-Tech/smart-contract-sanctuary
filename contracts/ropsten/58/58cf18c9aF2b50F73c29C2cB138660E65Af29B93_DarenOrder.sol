// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IDarenOrder.sol";
import "./DarenBonus.sol";

contract DarenOrder is IDarenOrder {
    using SafeMath for uint;

    string public standard = "Daren Order v1.0.0";
    string public version = "v1.0.0";
    uint public primaryKey = 0; // Order index

    address public usdtToken;   // The USDT token
    address public darenToken;  // The Daren token
    address public darenBonus;  // The DarenBonus contract

    uint private totalFee = 0;
    uint private availableFee = 0;
    uint public feeRatio = 500; // 5%
    address public feeTo;
    address public feeToSetter;

    uint constant dayInMilliseconds = 1000 * 60 * 60 * 24;

    mapping(uint => uint) public orderPKList;
    mapping(uint => Order) public orderIDList;
    
    uint public totalTransactionAmount;
    uint public allocRatioBase = 1000;  // 50% of fee
    uint public allocRatio = 2000;      // 50% of fee

    uint public orderExpireTime = 30;   // Exipre after 30 days
    uint public voteExpireTime = 7;     // Exipie after 7 days

    bool public allowHolderVote = false;
    // uint public allowVoteFromAmount = 1000 * 10 ** ERC20(darenToken).decimals();

    // Vote: orderID => voter => bool
    mapping(uint => mapping(address => bool)) private orderVotedAddresses;
    mapping(address => bool) private cadidates;

    constructor(address _darenBonus, address _darenToken, address _usdtToken) {
        require(_darenToken != address(0), 'darenToken should not be zero');
        require(_usdtToken != address(0), 'usdtToken should not be zero');
        require(_darenBonus != address(0), 'darenBonus should not be zero');

        feeToSetter = msg.sender;
        feeTo = msg.sender;

        darenBonus = _darenBonus;
        usdtToken = _usdtToken;
        darenToken = _darenToken;
    }

    function createOrder(
        string memory _name,
        uint _orderID,
        uint _value,
        address _seller
    ) public payable override returns (uint pk) {
        require(_seller != msg.sender, "Can't purchase own services.");
        require(_orderID > 0, "Order ID invalid.");
        require(orderIDList[_orderID].pk <= 0, "Order ID already exist.");
        require(_value > 5 * 10 ** ERC20(usdtToken).decimals(), "No free service.");

        ERC20(usdtToken).transferFrom(msg.sender, address(this), _value);

        primaryKey += 1;
        Order memory order = Order(
            primaryKey,
            _name,
            _orderID,
            _value,
            _seller,
            msg.sender,
            OrderStatus.Active,
            block.timestamp,
            OrderVotes(
                0, 0, VoteType.None, 0
            )
        );

        orderIDList[_orderID] = order;
        orderPKList[primaryKey] = _orderID;
        emit CreateOrder(
            primaryKey,
            _orderID,
            _name,
            _value,
            msg.sender,
            _seller,
            block.timestamp
        );
        return order.pk;
    }

    function getStatusKeyByValue(OrderStatus _status) internal pure returns (string memory strStatus) {        
        if (OrderStatus.Active == _status) return "ACTIVE";
        if (OrderStatus.Submitted == _status) return "SUBMITTED";
        if (OrderStatus.Completed == _status) return "COMPLETED";
        if (OrderStatus.Withdrawn == _status) return "WITHDRAWN";

        if (OrderStatus.Expired == _status) return "EXPIRED";

        // if (OrderStatus.WantRefund == _status) return "WANT_REFUND";
        if (OrderStatus.AgreeToRefund == _status) return "AGREE_TO_REFUND";
        if (OrderStatus.Refunded == _status) return "REFUNDED";

        if (OrderStatus.Voting == _status) return "VOTING";
        if (OrderStatus.Voted == _status) return "VOTED";
        require(false, "Invalid status value");
    }

    function cmpstr(string memory s1, string memory s2) public pure returns(bool){
        return keccak256(abi.encodePacked(s1)) == keccak256(abi.encodePacked(s2));
    }

    function getStatusValueByKey(string memory _status) internal pure returns (OrderStatus orderStatus) {
        if (cmpstr("ACTIVE", _status)) return OrderStatus.Active;
        if (cmpstr("SUBMITTED", _status)) return OrderStatus.Submitted;
        if (cmpstr("COMPLETED", _status)) return OrderStatus.Completed;
        if (cmpstr("WITHDRAWN", _status)) return OrderStatus.Withdrawn;

        if (cmpstr("EXPIRED", _status)) return OrderStatus.Expired;

        // if (cmpstr("WANT_REFUND", _status)) return OrderStatus.WantRefund;
        if (cmpstr("AGREE_TO_REFUND", _status)) return OrderStatus.AgreeToRefund;
        if (cmpstr("REFUNDED", _status)) return OrderStatus.Refunded;

        if (cmpstr("VOTING", _status)) return OrderStatus.Voting;
        if (cmpstr("VOTED", _status)) return OrderStatus.Voted;
        require(false, "Invalid status key");
    }

    function getOrder(uint _orderID) public view override returns (
        uint pk,
        uint orderID,
        string memory name,
        uint value,
        address seller,
        address buyer,
        string memory status,
        uint createdAt,
        OrderVotes memory votes
    ) {
        require(_orderID > 0, "order ID should greater than 0.");
        Order memory order = orderIDList[_orderID];
        require(order.pk > 0, "order does not exist.");

        return (
            order.pk,
            order.orderID,
            order.name,
            order.value,
            order.seller,
            order.buyer,
            getStatusKeyByValue(order.status),
            order.createdAt,
            order.votes
        );
    }

    function getOrderByPK(uint _pk) public view override returns (uint orderID) {
        require(_pk > 0, "order ID should greater than 0.");
        uint _orderID = orderPKList[_pk];
        require(_orderID > 0, "order does not exist.");

        return (_orderID);
    }

    function updateOrder(uint _orderID, string memory _toStatusStr) public override {
        Order storage order = orderIDList[_orderID];
        OrderStatus _toStatus = getStatusValueByKey(_toStatusStr);
        require(order.status != OrderStatus.Completed, "Order have been completed.");
        require(order.status != OrderStatus.Withdrawn, "Order have been completed.");
        require(order.status != OrderStatus.AgreeToRefund, "Order have been agreed to refund.");
        require(order.status != OrderStatus.Refunded, "Order have been refunded.");

        if (_toStatus == OrderStatus.Submitted) {
            require(order.status == OrderStatus.Active, "Only active orders can be submitted.");
            require(msg.sender == order.seller, "Only seller can submit the order.");

            order.status = OrderStatus.Submitted;
            emit OrderUpdated(order.pk, order.orderID, getStatusKeyByValue(order.status));
        } else if (_toStatus == OrderStatus.Completed) {
            require(order.status == OrderStatus.Submitted, "Only submitted orders can be done.");
            require(msg.sender == order.buyer, "Only buyer can confirm the order.");

            uint fee = order.value.mul(feeRatio).div(10000);
            DarenBonus db = DarenBonus(darenBonus);
            db.completeOrder(order.buyer, order.seller, order.value, fee);

            totalFee = totalFee.add(fee);
            availableFee = availableFee.add(fee);
            order.value = order.value.sub(fee);

            order.status = OrderStatus.Completed;
            emit OrderUpdated(order.pk, order.orderID, getStatusKeyByValue(order.status));
        // } else if (_toStatus == OrderStatus.WantRefund) {
        //     require(msg.sender == order.buyer, "Only buyer can refund the order.");
        //     require(order.status == OrderStatus.Active
        //         || order.status == OrderStatus.Submitted
        //         || order.status == OrderStatus.Expired,
        //         "Only submitted or active orders can be refund.");

        //     order.status = OrderStatus.WantRefund;
        //     emit OrderUpdated(order.pk, order.orderID, OrderStatus.WantRefund);
        } else if (_toStatus == OrderStatus.AgreeToRefund) {
            // require(order.status == OrderStatus.WantRefund, "Only want refund order can be agree.");
            require(msg.sender == order.seller, "Only seller can agree to refund.");
            // ERC20 dvq = ERC20(darenToken);
            // require(dvq.balanceOf(address(this)) > user.rewardableAmount, "Withdraw is unavailable now");

            order.status = OrderStatus.AgreeToRefund;
            emit OrderUpdated(order.pk, order.orderID, getStatusKeyByValue(order.status));
        } else if (_toStatus == OrderStatus.Voting) {
            require(msg.sender == order.buyer, "Only buyer can request a vote.");
            order.votes.createdAt = block.timestamp;

            order.status = OrderStatus.Voting;
            emit OrderUpdated(order.pk, order.orderID, getStatusKeyByValue(order.status));
        }
    }

    function includeInCandidates(address _newCandidate) external {
        require(msg.sender == feeToSetter, "includeInCandidates: not permitted");
        cadidates[_newCandidate] = true;
    }

    function excludeFromCandidates(address _newCandidate) external {
        require(msg.sender == feeToSetter, "excludeFromCandidates: not permitted");
        cadidates[_newCandidate] = false;
    }

    function vote(uint _orderID, VoteType voteType) external {
        Order storage order = orderIDList[_orderID];
        require(order.status == OrderStatus.Voting, "Only voting order could be voted");
        require(cadidates[msg.sender], "Only cadidates could vote");
        uint currentTime = block.timestamp;
        require(currentTime < order.votes.createdAt + voteExpireTime * dayInMilliseconds, "vote expired");
        require(msg.sender != order.buyer && msg.sender != order.seller, "traders could not vote");

        if (voteType == VoteType.Buyer) {
            order.votes.buyer = order.votes.buyer.add(1);
            order.votes.lastVote = VoteType.Buyer;
            return;
        } else if (voteType == VoteType.Seller) {
            order.votes.seller = order.votes.seller.add(1);
            order.votes.lastVote = VoteType.Seller;
            return;
        }
        require(false, "invalid vote type");
    }

    function getTotalFee () external view returns (uint) {
        require(msg.sender == feeToSetter, "not permitted");
        return totalFee;
    }

    function getAvailableFee () external view returns (uint) {
        require(msg.sender == feeToSetter, "not permitted");
        return availableFee;
    }

    function feeWithdraw () external {
        require(msg.sender == feeTo, "Invalid fee withdraw");
        ERC20 u = ERC20(usdtToken);
        u.transfer(feeTo, availableFee);
        availableFee = 0;
    }

    // Both buyer and seller could withdraw: 
    //  buyer withdraw ACCEPT_TO_REFUND order.
    //  seller withdraw COMPLETED order.
    function orderWithdraw(uint _orderID) external {
        Order storage order = orderIDList[_orderID];
        ERC20 u = ERC20(usdtToken);
        if (order.status == OrderStatus.Completed) {
            u.transfer(order.seller, order.value);
            order.status = OrderStatus.Withdrawn;
            return;
        } else if (order.status == OrderStatus.AgreeToRefund) {
            u.transfer(order.buyer, order.value);
            order.status = OrderStatus.Refunded;
            return;
        } else if (order.status == OrderStatus.Submitted) {
            require(block.timestamp > order.createdAt + orderExpireTime * dayInMilliseconds, "Order didn't finished.");

            uint fee = order.value.mul(feeRatio).div(10000);
            DarenBonus db = DarenBonus(darenBonus);
            db.completeOrder(order.buyer, order.seller, order.value, fee);

            totalFee = totalFee.add(fee);
            availableFee = availableFee.add(fee);
            order.value = order.value.sub(fee);

            u.transfer(order.seller, order.value);
            order.status = OrderStatus.Withdrawn;
        } else if (order.status == OrderStatus.Active) {
            require(block.timestamp > order.createdAt + orderExpireTime * dayInMilliseconds, "Order didn't finished.");
            u.transfer(order.buyer, order.value);
            order.status = OrderStatus.Refunded;
        }
        require(false, "Invalid withdraw");
    }
    
    function setFeeTo(address payable _feeTo) external {
        require(msg.sender == feeToSetter, 'setFeeTo: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'setFeeToSetter: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function setAllocRatio(uint _allocRatio) external {
        require(msg.sender == feeToSetter, 'setAllocRatio: FORBIDDEN');
        allocRatio = _allocRatio;
    }

    function setAllowHolderVote(uint _allocRatio) external {
        require(msg.sender == feeToSetter, 'setAllocRatio: FORBIDDEN');
        allocRatio = _allocRatio;
    }
}