// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @dev Implementation of P2P Trading contract that allows creation
 * of trades by {seller} or {buyer}.
 *
 * Buyer or seller can start trades by making the seller deposit the trade
 * amount of tokens. Buyer marks the trade as paid and then seller
 * completes the trade by transferring trade amount less the escrow fee
 * to buyer. Escrow fee is sent to the contract owner.
 *
 * Trade can be disputed by either party when it is in the state of
 * {processing} or {paid}. Buyer can cancel trade when it is {pending}
 * or {paid} and seller can cancel trade when it is {pending}.
 *
 * Admin can complete or cancel the trade and {Godspeed} tokens are
 * sent to both parties amounting to roughly 90%+ of the gas spent
 * by the respective party.
 */

contract GodspeedP2P is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Variable

    address public owner;
    using Counters for Counters.Counter;
    Counters.Counter public tradeId;

    IERC20 public godSpeed;

    // price of 1 eth to Godspeed tokens
    // e.g. 1e18 of eth is equal to 100e18 of Godspeed tokens,
    // the price is (100e18 * 10**18)/1e18 = 100e18
    uint256 public ethToGodspeed;

    constructor(
        uint256 _ethToGodspeed,
        address _godSpeed
    ) {
        owner = msg.sender;
        godSpeed = IERC20(_godSpeed);
        setEthToGodSpeedPrice(_ethToGodspeed);
    }

    enum Status{
        pending,
        processing,
        paid,
        cancelled,
        completed,
        disputed,
        waiting
    }

    struct Trade {
        uint256 tradeId;
        address seller;
        address buyer;
        uint256 amount;
        address tokenContractAddress;
        Status status;
        string offerId;
        uint256 buyerSpentGas;
        uint256 sellerSpentGas;
    }

    uint256 public feeInPercent = 25;
    uint256 public percentFraction = 1000;

    mapping(uint256 => Trade) public trades;


    // Events
    event TradeCreated(
        uint256 tradeId,
        address seller,
        address buyer,
        uint256 amount,
        address tokenContractAddress,
        Status status
    );

    event TradeStarted(
        uint256 tradeId,
        address seller,
        address buyer,
        uint256 amount,
        address tokenContractAddress,
        Status status
    );

    event TradePaid(
        uint256 tradeId,
        address seller,
        address buyer,
        uint256 amount,
        address tokenContractAddress,
        Status status
    );

    event TradeCompleted(
        uint256 tradeId,
        address seller,
        address buyer,
        uint256 amount,
        address tokenContractAddress,
        Status status);

    event TradeCancelled(
        uint256 tradeId,
        address seller,
        address buyer,
        uint256 amount,
        address tokenContractAddress,
        Status status);

    event TradeDisputed(
        uint256 tradeId,
        address seller,
        address buyer,
        uint256 amount,
        address tokenContractAddress,
        Status status);


    // Public functions

    // Seller : Who sells token for money / other items
    // Buyer : Who Buys token

    // @ Method :Trade create
    // @ Description: Seller will create a trade for a Buyer
    // @ Params : Buyer Address, Amount (token amount * decimals) , token contract Address
    function createTrade(
        address _buyer,
        uint256 _amount,
        address _tokenAddress,
        string memory _offerId
    ) external {
        uint256 gasBefore = gasleft();

        require(
            _amount != 0,
            "Amount must be greater than zero"
        );
        require(
            _buyer != address(0),
            "Buyer must be an valid address"
        );
        require(
            _tokenAddress != address(0),
            "Token Address must be an valid address"
        );
        tradeId.increment();
        uint256 currentId =  tradeId.current();
        trades[currentId] = Trade(
            currentId,
            msg.sender,
            _buyer,
            _amount,
            _tokenAddress,
            Status.pending,
            _offerId,
            0,
            0
        );

        emit TradeCreated(
            currentId,
            msg.sender,
            _buyer,
            _amount,
            _tokenAddress,
            Status.pending
        );

        uint256 gasAfter = gasleft();

        uint256 gasConsumed =
            gasBefore
            - gasAfter
            + 22500 // gas cost for the message call.
            + 20000; // gas cost for performing storage write on the next line.

        trades[currentId].sellerSpentGas = gasConsumed * tx.gasprice;
    }



    // @ Method : Trade create by  buyer
    // @ Description: Buyer will create a trade for a Seller
    // @ Params : Seller Address, Amount (token amount * decimals) , token contract Address
    function createTradeByBuyer(
        address _seller,
        uint256 _amount,
        address _tokenAddress,
        string memory _offerId
    ) external {
        uint256 gasBefore = gasleft();

        require(
            _amount != 0,
            "Amount must be greater than zero"
        );
        require(
            _seller != address(0),
             "Seller must be an valid address"
        );
        require(
            _tokenAddress != address(0),
            "Token Address must be an valid address"
        );
        tradeId.increment();
        uint256 currentId =  tradeId.current();

        trades[currentId] = Trade(
            currentId,
            _seller,
            msg.sender,
            _amount,
            _tokenAddress,
            Status.waiting,
            _offerId,
            0,
            0
        );

        emit TradeCreated(
            currentId,
            _seller,
            msg.sender,
            _amount,
            _tokenAddress,
            Status.waiting
        );

        uint256 gasAfter = gasleft();
        uint256 gasConsumed =
            gasBefore
            - gasAfter
            + 22500 // gas cost for the message call.
            + 20000; // gas cost for performing storage write on the next line.

        trades[currentId].buyerSpentGas = gasConsumed * tx.gasprice;
    }

    // @ Method : start trade By seller
    // @ Description : Seller will start the trade. Seller need to approve this contract first then this method to deposit.
    // @ Params : tradeId
    function startTradeBySeller(uint256 _tradeId)
        external
        nonReentrant
    {
        uint256 gasBefore = gasleft();

        require(
            trades[_tradeId].seller == msg.sender,
            "You are not seller"
        );
        require(
            trades[_tradeId].status == Status.waiting,
            "Trade already proceed"
        );
        trades[_tradeId].status = Status.processing;
        IERC20(trades[_tradeId].tokenContractAddress).safeTransferFrom(
            trades[_tradeId].seller,
            address(this),
            trades[_tradeId].amount
        );

        emit TradeStarted(
            _tradeId,
            trades[_tradeId].seller,
            trades[_tradeId].buyer,
            trades[_tradeId].amount,
            trades[_tradeId].tokenContractAddress,
            Status.processing
        );

        uint256 gasAfter = gasleft();
        uint256 gasConsumed =
            gasBefore
            - gasAfter
            + 22500 // gas cost for the message call.
            + 20800; // gas cost for performing storage write on the next line.

        trades[_tradeId].sellerSpentGas += gasConsumed * tx.gasprice;
    }

    // @ Method : Start trade
    // @ Description : Buyer will start the trade. Seller need to approve this contract with the trade amount . Otherwise this action can't be done.
    // @ Params : tradeId
    function startTrade(uint256 _tradeId)
        external
        nonReentrant
    {
        uint256 gasBefore = gasleft();

        require(
            trades[_tradeId].buyer == msg.sender,
            "You are not buyer"
        );
        require(
            trades[_tradeId].status == Status.pending,
            "Trade already proceed or not deposited"
        );
        trades[_tradeId].status = Status.processing;
        IERC20(trades[_tradeId].tokenContractAddress).safeTransferFrom(
            trades[_tradeId].seller,
            address(this),
            trades[_tradeId].amount
        );

        emit TradeStarted(
            _tradeId,
            trades[_tradeId].seller,
            trades[_tradeId].buyer,
            trades[_tradeId].amount,
            trades[_tradeId].tokenContractAddress,
            Status.processing
        );

        uint256 gasAfter = gasleft();
        uint256 gasConsumed =
            gasBefore
            - gasAfter
            + 22500 // gas cost for the message call.
            + 20800; // gas cost for performing storage write on the next line.

        trades[_tradeId].buyerSpentGas += gasConsumed * tx.gasprice;
    }

    // @ Method : Mark the trade as paid
    // @ Description : Buyer will mark the trade as paid when he gives the service / money to Token Seller
    // @ Params : tradeId
    function markedPaidTrade(uint256 _tradeId) external {
        uint256 gasBefore = gasleft();

        require(
            trades[_tradeId].buyer == msg.sender,
            "You are not buyer"
        );
        require(
            trades[_tradeId].status == Status.processing,
            "Trade is not processing"
        );
        trades[_tradeId].status = Status.paid;
        emit TradePaid(
            _tradeId,
            trades[_tradeId].seller,
            trades[_tradeId].buyer,
            trades[_tradeId].amount,
            trades[_tradeId].tokenContractAddress,
            Status.paid
        );

        uint256 gasAfter = gasleft();
        uint256 gasConsumed =
            gasBefore
            - gasAfter
            + 22500 // gas cost for the message call.
            + 5800; // gas cost for performing storage write on the next line.

        trades[_tradeId].buyerSpentGas += gasConsumed * tx.gasprice;
    }

    // @Method : Complete the trades
    // @Description : Seller will complete the trade when seller paid him / her
    // @ Params : tradeId
    function completeTrade(uint256 _tradeId)
        external
        nonReentrant
    {
        uint256 gasBefore = gasleft();

        require(
            trades[_tradeId].seller == msg.sender,
            "You are not seller"
        );
        require(
            trades[_tradeId].status == Status.paid,
            "Buyer not paid yet"
        );
        uint256 fee = escrowFee(trades[_tradeId].amount);
        uint256 amount = trades[_tradeId].amount - fee;

        IERC20 token = IERC20(trades[_tradeId].tokenContractAddress);
        token.safeTransfer(trades[_tradeId].buyer, amount);
        token.safeTransfer(owner,fee);
        trades[_tradeId].status = Status.completed;

        emit TradeCompleted(
            _tradeId,
            trades[_tradeId].seller,
            trades[_tradeId].buyer,
            trades[_tradeId].amount,
            trades[_tradeId].tokenContractAddress,
            Status.completed
        );

        uint256 gasAfter = gasleft();
        uint256 gasConsumed =
            gasBefore
            - gasAfter
            + 22500 // gas cost for the message call.
            + 5800 // gas cost for performing storage write on the next line.
            + 17289; // gas consumed in reimbursement

        trades[_tradeId].sellerSpentGas += gasConsumed * tx.gasprice;

        reimburseGas(_tradeId); // 17289
    }

    // @Method: Dispute the trades
    // @Description :  Buyer or seller can dispute the trade (processing and paid stage)
    // @ Params : tradeId

    function disputeTrade(uint256 _tradeId) external {
        uint256 gasBefore = gasleft();

        require(
            trades[_tradeId].seller == msg.sender ||
            trades[_tradeId].buyer == msg.sender,
            "You are not buyer or seller"
        );
        require(
            trades[_tradeId].status == Status.processing ||
            trades[_tradeId].status == Status.paid,
            "Trade is not processing nor marked as paid"
        );

        trades[_tradeId].status = Status.disputed;

        emit TradeDisputed(
            _tradeId,
            trades[_tradeId].seller,
            trades[_tradeId].buyer,
            trades[_tradeId].amount,
            trades[_tradeId].tokenContractAddress,
            Status.disputed
        );

        uint256 gasAfter = gasleft();
        uint256 gasConsumed =
            gasBefore
            - gasAfter
            + 22500 // gas cost for the message call.
            + 7900; // gas cost for performing storage write on the next line.

        if (trades[_tradeId].seller == msg.sender) {
            trades[_tradeId].sellerSpentGas += gasConsumed * tx.gasprice;
        } else {
            trades[_tradeId].buyerSpentGas += gasConsumed * tx.gasprice;
        }
    }

    // @Method: Cancel the trades by seller
    // @Description :  Seller can cancel the trade only before start the trade
    // @ Params : tradeId

    function cancelTradeBySeller(uint256 _tradeId) external {
        uint256 gasBefore = gasleft();

        require(
            trades[_tradeId].seller == msg.sender,
            "You are not seller"
        );
        require(
            trades[_tradeId].status == Status.pending,
            "Trade already started"
        );
        trades[_tradeId].status = Status.cancelled;

        emit TradeCancelled(
            _tradeId,
            trades[_tradeId].seller,
            trades[_tradeId].buyer,
            trades[_tradeId].amount,
            trades[_tradeId].tokenContractAddress,
            Status.cancelled
        );

        uint256 gasAfter = gasleft();
        uint256 gasConsumed =
            gasBefore
            - gasAfter
            + 21000 // gas cost for the message call.
            + 5000 // gas cost for performing storage write on the next line.
            + 17289; // gas for reimbursement

        trades[_tradeId].sellerSpentGas += gasConsumed * tx.gasprice;
        reimburseGas(_tradeId);
    }

    // @Method:  Cancel the trades by buyer
    // @Description : Buyer can cancel the trade if the trade on pending or paid stage. Token will reverted to Seller.
    // @ Params : tradeId
    function cancelTradeByBuyer(uint256 _tradeId)
        external
        nonReentrant
    {
        uint256 gasBefore = gasleft();

        require(
            trades[_tradeId].buyer == msg.sender,
            "You are not buyer"
        );
        require(
            trades[_tradeId].status == Status.processing
            || trades[_tradeId].status == Status.paid,
            "Trade not strated or already finished"
        );
        trades[_tradeId].status = Status.cancelled;
        IERC20(trades[_tradeId].tokenContractAddress).safeTransfer(
            trades[_tradeId].seller,
            trades[_tradeId].amount
        );

        emit TradeCancelled(
            _tradeId,
            trades[_tradeId].seller,
            trades[_tradeId].buyer,
            trades[_tradeId].amount,
            trades[_tradeId].tokenContractAddress,
            Status.cancelled
        );

        uint256 gasAfter = gasleft();
        uint256 gasConsumed =
            gasBefore
            - gasAfter
            + 21000 // gas cost for the message call.
            + 5000 // gas cost for performing storage write on the next line.
            + 17289;

        trades[_tradeId].buyerSpentGas += gasConsumed * tx.gasprice;
        reimburseGas(_tradeId); // 17289
    }

    // @ Method:  Cancel the trades by Admin
    // @ Description : Admin can cancel the trade. only for disputed trade. Token will reverted to Seller.
    // @ Params : tradeId
    function cancelTradeByAdmin(uint256 _tradeId)
        external
        onlyOwner
    {
        require(
            trades[_tradeId].status == Status.disputed,
            "Trade not disputed"
        );
        trades[_tradeId].status = Status.cancelled;
        IERC20(trades[_tradeId].tokenContractAddress).safeTransfer(
            trades[_tradeId].seller,
            trades[_tradeId].amount
        );

        reimburseGas(_tradeId);

        emit TradeCancelled(
            _tradeId,
            trades[_tradeId].seller,
            trades[_tradeId].buyer,
            trades[_tradeId].amount,
            trades[_tradeId].tokenContractAddress,
            Status.cancelled
        );
    }

    // @ Method: Complete the trades by Admin
    // @ Description : admin can complete the trades
    // @ Params : tradeId
    function completeTradeByAdmin(uint256 _tradeId)
        external
        onlyOwner
    {
        require(
            trades[_tradeId].status == Status.disputed,
            "Trade not disputed"
        );
        trades[_tradeId].status = Status.completed;
        IERC20(trades[_tradeId].tokenContractAddress).safeTransfer(
            trades[_tradeId].buyer,
            trades[_tradeId].amount
        );

        reimburseGas(_tradeId);

        emit TradeCompleted(
            _tradeId,
            trades[_tradeId].seller,
            trades[_tradeId].buyer,
            trades[_tradeId].amount,
            trades[_tradeId].tokenContractAddress,
            Status.completed
        );
    }

    // The gas reimbursed in godspeed tokens is roughly 90% or above
    // of the original gas consumed by the network.
    function reimburseGas(uint256 _tradeId) private {
        uint256 toSeller =
            trades[_tradeId].sellerSpentGas
            * ethToGodspeed
            / 10 ** 9; // gas spent is in gwei so we only divide by 1e9 instead of 1e18

        uint256 toBuyer =
            trades[_tradeId].buyerSpentGas
            * ethToGodspeed
            / 10 ** 9; // gas spent is in gwei so we only divide by 1e9 instead of 1e18

        IERC20(godSpeed).safeTransfer(
            trades[_tradeId].seller,
            toSeller
        );

        IERC20(godSpeed).safeTransfer(
            trades[_tradeId].buyer,
            toBuyer
        );
    }

    // Private Function
    function escrowFee(uint256 amount)
        private
        view
        returns(uint256 adminFee)
    {
        uint256 x = amount.mul(feeInPercent);
        adminFee = x.div(percentFraction);
    }


    // Admin function
    function changeFee(uint256 fee, uint256 fraction)
        external
        onlyOwner
    {
        feeInPercent = fee;
        percentFraction = fraction;
    }

    function setEthToGodSpeedPrice(uint256 _price)
        public
        onlyOwner
    {
        require(
            _price != 0,
            "price cannot be zero"
        );
        ethToGodspeed = _price;
    }

    modifier onlyOwner() {
        require(
            owner == msg.sender,
            "You are not owner"
        );
        _;
    }
}