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
    uint private primaryKey = 0; // Order index

    address public usdtToken;   // The USDT token
    address public darenToken;  // The Daren token
    address public darenBonus;  // The DarenBonus contract

    // uint private totalFee = 0;
    // uint private availableFee = 0;
    uint public feeRatio = 500; // 5%
    address public feeTo;
    address public feeToSetter;

    uint constant dayInMilliseconds = 1000 * 60 * 60 * 24;

    mapping(uint => Order) public orderPKList;
    mapping(uint => Order) public orderIDList;
    
    uint public totalTransactionAmount;
    uint public allocRatioBase = 1000;  // 50% of fee
    uint public allocRatio = 2000;      // 50% of fee

    uint public orderExpireTime = 30;   // Exipre after 30 days
    uint public voteExpireTime = 7;     // Exipie after 7 days

    bool public allowHolderVote = false;
    uint public allowVoteFromAmount = 1000;

    // Vote: orderID => voter => bool
    mapping(uint => mapping(address => bool)) private orderVotedAddresses;
    mapping(uint => address[]) private orderVotedAddressList;
    mapping(address => bool) private candidates;

    constructor(address _darenBonus, address _darenToken, address _usdtToken) {
        require(_darenToken != address(0), 'darenToken should not be zero');
        require(_usdtToken != address(0), 'usdtToken should not be zero');
        require(_darenBonus != address(0), 'darenBonus should not be zero');

        feeToSetter = msg.sender;
        feeTo = msg.sender;

        darenBonus = _darenBonus;
        usdtToken = _usdtToken;
        darenToken = _darenToken;

        candidates[msg.sender] = true;
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
        require(_value >= 5 * 10 ** ERC20(usdtToken).decimals(), "No free service.");

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
        orderPKList[primaryKey] = order;
        emit OrderCreated(
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

        // if (OrderStatus.Expired == _status) return "EXPIRED";

        // if (OrderStatus.WantRefund == _status) return "WANT_REFUND";
        if (OrderStatus.AgreeToRefund == _status) return "AGREE_TO_REFUND";
        if (OrderStatus.Refunded == _status) return "REFUNDED";

        if (OrderStatus.Voting == _status) return "VOTING";
        // if (OrderStatus.Voted == _status) return "VOTED";
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

        // if (cmpstr("EXPIRED", _status)) return OrderStatus.Expired;

        // if (cmpstr("WANT_REFUND", _status)) return OrderStatus.WantRefund;
        if (cmpstr("AGREE_TO_REFUND", _status)) return OrderStatus.AgreeToRefund;
        if (cmpstr("REFUNDED", _status)) return OrderStatus.Refunded;

        if (cmpstr("VOTING", _status)) return OrderStatus.Voting;
        // if (cmpstr("VOTED", _status)) return OrderStatus.Voted;
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

    function getOrderByPK(uint _pk) public view override returns (
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
        require(_pk > 0, "order ID should greater than 0.");
        Order memory order = orderPKList[_pk];
        // require(order > 0, "order does not exist.");

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

    function updateOrder(uint _orderID, string memory _toStatusStr) public override {
        Order storage order = orderIDList[_orderID];
        OrderStatus _toStatus = getStatusValueByKey(_toStatusStr);
        require(order.status != OrderStatus.Completed, "Order have been completed.");
        require(order.status != OrderStatus.Withdrawn, "Order have been completed.");
        require(order.status != OrderStatus.AgreeToRefund, "Order have been agreed to refund.");
        require(order.status != OrderStatus.Refunded, "Order have been refunded.");
        require(order.status != OrderStatus.Voting, "Order is voting.");

        if (_toStatus == OrderStatus.Submitted) {
            require(order.status == OrderStatus.Active, "Only active orders can be submitted.");
            require(msg.sender == order.seller, "Only seller can submit the order.");

            order.status = OrderStatus.Submitted;
            emit OrderUpdated(order.pk, order.orderID, getStatusKeyByValue(order.status));
        } else if (_toStatus == OrderStatus.Completed) {
            require(order.status == OrderStatus.Submitted, "Only submitted orders can be done.");
            require(msg.sender == order.buyer, "Only buyer can confirm the order.");

            order.status = OrderStatus.Completed;
            emit OrderUpdated(order.pk, order.orderID, getStatusKeyByValue(order.status));
        } else if (_toStatus == OrderStatus.AgreeToRefund) {
            require(msg.sender == order.seller, "Only seller can agree to refund.");

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
        candidates[_newCandidate] = true;
    }

    function excludeFromCandidates(address _newCandidate) external {
        require(msg.sender == feeToSetter, "excludeFromCandidates: not permitted");
        candidates[_newCandidate] = false;
    }

    function vote(uint _orderID, VoteType voteType) external {
        Order storage order = orderIDList[_orderID];
        require(voteType == VoteType.Buyer || voteType == VoteType.Seller, "Invalid vote type");
        require(order.status == OrderStatus.Voting, "Only voting order could be voted");
        require(candidates[msg.sender], "Only candidates could vote");
        uint currentTime = block.timestamp;
        require(currentTime < order.votes.createdAt + voteExpireTime * dayInMilliseconds, "vote expired");
        require(msg.sender != order.buyer && msg.sender != order.seller, "Traders could not vote");
        require(orderVotedAddresses[_orderID][msg.sender] != true, "You already voted");

        if (voteType == VoteType.Buyer) {
            orderVotedAddresses[_orderID][msg.sender] = true;
            orderVotedAddressList[_orderID].push(msg.sender);
            order.votes.buyer = order.votes.buyer.add(1);
            order.votes.lastVote = VoteType.Buyer;
            return;
        } else if (voteType == VoteType.Seller) {
            orderVotedAddresses[_orderID][msg.sender] = true;
            orderVotedAddressList[_orderID].push(msg.sender);
            order.votes.seller = order.votes.seller.add(1);
            order.votes.lastVote = VoteType.Seller;
            return;
        } else {
            require(false, "Invalid vote type");
        }
    }

    // Both buyer and seller could withdraw: 
    //  buyer withdraws ACCEPT_TO_REFUND order.
    //  seller withdraws COMPLETED order.
    function withdrawOrder(uint _orderID) external override {
        Order storage order = orderIDList[_orderID];
        ERC20 u = ERC20(usdtToken);
        DarenBonus db = DarenBonus(darenBonus);
        
        uint fee = order.value.mul(feeRatio).div(10000);
        uint finalValue = order.value.sub(fee);

        if (order.status == OrderStatus.Completed) {
            // order completed, seller withdraw the order.
            db.completeOrder(order.buyer, order.seller, order.value, fee);

            u.transfer(order.seller, finalValue);
            u.transfer(feeTo, fee);
            order.status = OrderStatus.Withdrawn;

            emit OrderWithdrawn(order.pk, _orderID, getStatusKeyByValue(OrderStatus.Withdrawn));
        } else if (order.status == OrderStatus.AgreeToRefund) {
            // seller agree to refund, buyer withdraw the order.
            u.transfer(order.buyer, order.value);
            order.status = OrderStatus.Refunded;

            emit OrderWithdrawn(order.pk, _orderID, getStatusKeyByValue(OrderStatus.Refunded));
        } else if (order.status == OrderStatus.Submitted) {
            // order expired and seller submitted, seller withdraw the order.
            require(block.timestamp > order.createdAt + orderExpireTime * dayInMilliseconds, "Submitted order didn't finished.");

            db.completeOrder(order.buyer, order.seller, order.value, fee);

            u.transfer(order.seller, finalValue);
            u.transfer(feeTo, fee);
            order.status = OrderStatus.Withdrawn;
            
            emit OrderWithdrawn(order.pk, _orderID, getStatusKeyByValue(OrderStatus.Withdrawn));
        } else if (order.status == OrderStatus.Active) {
            // active order expired and order in active, buyer withdraw the order.
            require(block.timestamp > order.createdAt + orderExpireTime * dayInMilliseconds, "Active order didn't finished.");
            u.transfer(order.buyer, order.value);
            order.status = OrderStatus.Refunded;
            
            emit OrderWithdrawn(order.pk, _orderID, getStatusKeyByValue(OrderStatus.Refunded));
        } else if (order.status == OrderStatus.Voting) {
            require(block.timestamp > order.votes.createdAt + voteExpireTime * dayInMilliseconds, "Voting didn't finished.");
            if (fee < ERC20(usdtToken).decimals() * 5) {
                fee = ERC20(usdtToken).decimals() * 5;
                finalValue = order.value.sub(fee);
            }

            if (order.votes.buyer > order.votes.seller) {
                require(msg.sender == order.buyer, "You didn't win the Vote. Buyer winned.");
            } else if (order.votes.seller > order.votes.buyer) {
                require(msg.sender == order.seller, "You didn't win the Vote. Seller winned.");
            } else {
                // TODO: ...
                // require(false, "Vote draw");
            }

            if (order.votes.buyer > order.votes.seller || (order.votes.buyer == order.votes.seller && order.votes.lastVote == VoteType.Seller)) {
                require(msg.sender == order.buyer, "You didn't win the Vote. Buyer winned.");

                u.transfer(order.buyer, finalValue);
                u.transfer(feeTo, fee);
                db.voteToCompleteOrder(orderVotedAddressList[order.orderID], order.buyer, order.seller, order.value, fee);
                order.status = OrderStatus.Refunded;
                
                emit OrderWithdrawn(order.pk, _orderID, getStatusKeyByValue(OrderStatus.Refunded));
            } else if (order.votes.seller > order.votes.buyer || (order.votes.buyer == order.votes.seller && order.votes.lastVote == VoteType.Buyer)) {
                require(msg.sender == order.seller, "You didn't win the Vote. Seller winned.");

                u.transfer(order.seller, finalValue);
                u.transfer(feeTo, fee);
                db.voteToCompleteOrder(orderVotedAddressList[order.orderID], order.buyer, order.seller, order.value, fee);
                order.status = OrderStatus.Withdrawn;
                
                emit OrderWithdrawn(order.pk, _orderID, getStatusKeyByValue(OrderStatus.Withdrawn));
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

    function getPK () external view returns (uint) {
        require(msg.sender == feeToSetter, 'getPK: FORBIDDEN');
        return primaryKey;
    }
    
    function setFeeTo(address payable _feeTo) external {
        require(msg.sender == feeToSetter, 'setFeeTo: FORBIDDEN');
        require(_feeTo != address(0), 'Should not be zero address');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'setFeeToSetter: FORBIDDEN');
        require(_feeToSetter != address(0), 'Should not be zero address');
        feeToSetter = _feeToSetter;
    }

    function setAllocRatio(uint _allocRatio) external {
        require(msg.sender == feeToSetter, 'setAllocRatio: FORBIDDEN');
        require(_allocRatio > 0, 'Alloc ratio should be positive');
        allocRatio = _allocRatio;
    }

    function setOrderExpireTime(uint _expireDay) external {
        require(msg.sender == feeToSetter, 'setOrderExpireTime: FORBIDDEN');
        require(_expireDay > 0, 'Expire days should be positive');
        orderExpireTime = _expireDay;
    }

    function setVoteExpireTime(uint _expireDay) external {
        require(msg.sender == feeToSetter, 'setVoteExpireTime: FORBIDDEN');
        require(_expireDay > 0, 'Expire days should be positive');
        voteExpireTime = _expireDay;
    }

    function setAllowHolderVote(uint _holdAmount) external {
        require(msg.sender == feeToSetter, 'setAllowHolderVote: FORBIDDEN');
        if (_holdAmount > 0) {
            allowHolderVote = true;
            allowVoteFromAmount = _holdAmount;
        } else {
            allowHolderVote = false;
        }
    }
}