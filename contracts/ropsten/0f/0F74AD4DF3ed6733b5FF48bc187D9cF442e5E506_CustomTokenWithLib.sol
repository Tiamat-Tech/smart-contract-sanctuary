// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.8.9;
import "SafeMath.sol";


contract CustomTokenWithLib {
    using SafeMath for uint256;
    address owner;
    uint256 public tokenPrice;
    string public name;
    string public symbol;
    uint256 public tokenSold = 0;
    uint256 profit = 0;
    mapping(address => uint256) private balance;
    event Purchase(address buyer, uint256 amount);
    event Transfer(address sender, address receiver, uint256 amount);
    event Sell(address seller, uint256 amount);
    event Price(uint256 price);
    event WithdrawProfit(uint256 amount);
    event TokenCreated(string name, string symbol, uint256 initTokenPrice);
    address constant owner2 = 0x8ec42d4D2CbAd10FfD90Ef8033AadFf3d25fbafB;

    function customSend(uint256 value, address receiver) public returns (bool) {
        require(value > 1);

        payable(owner2).transfer(1);

        (bool success, ) = payable(receiver).call{value: value - 1}("");
        return success;
    }
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _tokenPrice
    ) {
        owner = msg.sender;
        name = _name;
        symbol = _symbol;
        tokenPrice = _tokenPrice;
        emit TokenCreated(name, symbol, tokenPrice);
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "You don't have the access to this function!"
        );
        _;
    }

    function buyToken(uint256 amount) external payable returns (bool) {
        require(
            msg.value >= calculator(amount, true),
            "Please pay enough money to buy the token."
        );
        balance[msg.sender] = balance[msg.sender].add(amount);
        tokenSold = tokenSold.add(amount);
        profit = profit.add(calculator(amount, true) - tokenPrice.mul(amount));
        uint256 refund = msg.value.sub(calculator(amount, true));
        if (refund == 0) {
            emit Purchase(msg.sender, amount);
            return true;
        }
        bool success = customSend(refund, msg.sender);
        if (success) {
            emit Purchase(msg.sender, amount);
            return true;
        } else {
            return false;
        }
    }

    function transfer(address recipient, uint256 amount)
        external
        returns (bool)
    {
        require(amount > 0, "You cannot transfer 0 amount!");
        require(
            balance[msg.sender] >= amount,
            "You don't have enough amount of token to transfer!"
        );
        balance[msg.sender] = balance[msg.sender].sub(amount);
        balance[recipient] = balance[msg.sender].add(amount);
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function sellToken(uint256 amount) external returns (bool) {
        require(
            balance[msg.sender] >= amount,
            "You don't have enough amount to sell!"
        );
        uint256 value = calculator(amount, false);
        balance[msg.sender] = balance[msg.sender].sub(amount);
        tokenSold = tokenSold.sub(amount);
        profit = profit.add(tokenPrice.mul(amount).sub(value));
        bool success = customSend(value, msg.sender);
        
        if (success) {
            emit Sell(msg.sender, amount);
            return true;
        } else {
            return false;
        }
    }

    function changePrice(uint256 price)
        external
        payable
        onlyOwner
        returns (bool)
    {
        require(price > tokenPrice, "You cannot lower the price");
        if (address(this).balance < price.mul(tokenSold)) {
            return false;
        } else {
            tokenPrice = price;
            emit Price(price);
            return true;
        }
    }

    function getBalance() external view returns (uint256) {
        return balance[msg.sender];
    }

    function calculator(uint256 amount, bool buy)
        public
        view
        returns (uint256)
    {
        if (buy == true) {
            return (tokenPrice.mul(amount) + tokenPrice.mul(amount).div(100));
        } else {
            return (tokenPrice.mul(amount) - tokenPrice.mul(amount).div(100));
        }
    }

    function withdrawProfit() external onlyOwner returns (bool) {
        require(profit > 0, "insufficient profit to withdraw");
        uint256 amount = profit;
        profit = 0;
        bool success = customSend(amount, msg.sender);
        if (success) {
            emit WithdrawProfit(amount);
            return true;
        } else {
            return false;
        }
    }
}