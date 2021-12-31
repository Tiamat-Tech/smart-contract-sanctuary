// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.4;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Dex is Ownable {
    enum Side {
        BUY,
        SELL
    }
    struct Order {
        uint id;
        Side side;
        address trader;
        bytes32 ticker;
        uint amount;
        uint filled; // part of the amount filled through trades
        uint price;
        uint date;
    }
    struct Token {
        bytes32 ticker;
        address tokenAddress;
    }
    mapping(bytes32 => Token) public tokens;
    mapping(address => mapping(bytes32 => uint)) public traderBalances;
    mapping(bytes32 => mapping(uint => Order[])) public orderBook; // uint is the side of the order, and the list of orders is sorted
    bytes32[] public tokenList;
    uint public nextOrderId;
    uint public nextTradeId;
    bytes32 constant DAI = bytes32("DAI");

    event TokenAdded(bytes32 _ticker, address _tokenAddress);
    event NewTrade(
        uint _tradeId,
        uint _orderId,
        bytes32 indexed _ticker,
        address indexed _trader1,
        address indexed _trader2,
        uint _amount,
        uint _price,
        uint _date
    );

    modifier tokenExist(bytes32 ticker) {
        require(tokens[ticker].tokenAddress != address(0), "token does not exist");
        _;
    }
    modifier tokenIsNotDai(bytes32 ticker) {
        require(ticker != DAI, "cannot trade DAI");
        _;
    }


    /* Getters */

    function getOrders(
        bytes32 ticker,
        Side side)
    external
    view
    returns(Order[] memory) {
        return orderBook[ticker][uint(side)];
    }
    function balanceInOf(
        bytes32 ticker,
        address trader)
    external
    view
    returns(uint) {
        return traderBalances[trader][ticker];
    }


    function getTokens()
    external
    view
    returns(Token[] memory) {
        Token[] memory _tokens = new Token[](tokenList.length);
        for (uint i = 0; i < tokenList.length; i++) {
            _tokens[i] = Token(
                tokens[tokenList[i]].ticker,
                tokens[tokenList[i]].tokenAddress
            );
        }
        return _tokens;
    }
    /* functions */
    function addToken(
        bytes32 ticker,
        address tokenAddress
    )
    onlyOwner()
    external {
        tokens[ticker] = Token(ticker, tokenAddress);
        tokenList.push(ticker);
        emit TokenAdded(
            ticker,
            tokenAddress
        );
    }

    function deposit(
        uint amount,
        bytes32 ticker
    )
    tokenExist(ticker)
    external
    {
        IERC20(tokens[ticker].tokenAddress).transferFrom(
            msg.sender,
            address(this),
            amount
    );
        traderBalances[msg.sender][ticker] += amount;
    }
    function withdraw(
        uint amount,
        bytes32 ticker
    )
    tokenExist(ticker)
    external {
        require(
            traderBalances[msg.sender][ticker] >= amount,
            "balance too low"
        );
        traderBalances[msg.sender][ticker] -= amount;
        IERC20(tokens[ticker].tokenAddress).transfer(msg.sender, amount);
    }


    function createLimitOrder(
        bytes32 ticker,
        uint amount,
        uint price,
        Side side)
    tokenExist(ticker)
    tokenIsNotDai(ticker)
    external {
        if (side == Side.SELL) {
            require(traderBalances[msg.sender][ticker] >= amount, "token balance too low");
        } else {
            require(traderBalances[msg.sender][DAI] >= amount * price, "DAI balance too low");
        }
        Order[] storage orders = orderBook[ticker][uint(side)];
        orders.push(Order(
            nextOrderId,
            side,
            msg.sender,
            ticker,
            amount,
            0,
            price,
            block.timestamp
        ));
        // bubble sort algorithm (easy)
        uint i = orders.length - 1;
        while(i > 0) {
            // set stop conditions
            if(side == Side.BUY && orders[i - 1].price > orders[i].price) {
                break;
            }
            if(side == Side.SELL && orders[i - 1].price < orders[i].price) {
                break;
            }
            // swap orders
            Order memory order = orders[i-1];
            orders[i - 1] = orders[i];
            orders[i] = order;
            i--;
        }
        nextOrderId++;
    }
    function createMarketOrder(
        bytes32 ticker,
        uint amount,
        Side side
    )
    tokenExist(ticker)
    tokenIsNotDai(ticker) 
    external {
        if(side == Side.SELL) {
            require(traderBalances[msg.sender][ticker] >= amount, "token balance too low");
        } // cannot verify here if balance is ok in case of BUY

        Order[] storage orders = orderBook[ticker][uint(side == Side.SELL ? Side.BUY : Side.SELL)];
        uint i;
        uint remaining = amount;

        //matching process
        while(i< orders.length && remaining > 0) {
            uint available = orders[i].amount - orders[i].filled;
            uint matched = (remaining > available) ? available : remaining;
            remaining -= matched;
            orders[i].filled += matched;
            emit NewTrade(
                nextTradeId,
                orders[i].id,
                ticker,
                orders[i].trader,
                msg.sender,
                matched,
                orders[i].price,
                block.timestamp
            );
            if(side == Side.SELL) {
                traderBalances[msg.sender][ticker] -= matched;
                traderBalances[msg.sender][DAI] += matched * orders[i].price;

                traderBalances[orders[i].trader][ticker] += matched;
                traderBalances[orders[i].trader][DAI] -= matched * orders[i].price;
            } else { // we can now verify if the balance of DAI is enough for this trade price
                require(traderBalances[msg.sender][DAI] >= matched * orders[i].price, "DAI balance too low");
                traderBalances[msg.sender][ticker] += matched;
                traderBalances[msg.sender][DAI] -= matched * orders[i].price;

                traderBalances[orders[i].trader][ticker] -= matched;
                traderBalances[orders[i].trader][DAI] += matched * orders[i].price;
            }
            nextTradeId++;
            i++;
        }
        // prune orderBook
        i = 0;
        while(i < orders.length && orders[i].filled == orders[i].amount) {
            // shift array
            for(uint j = i; j < orders.length - 1; j++) {
                orders[j] = orders[j+1];
            }
            orders.pop();
            i++;
        }
    }

}