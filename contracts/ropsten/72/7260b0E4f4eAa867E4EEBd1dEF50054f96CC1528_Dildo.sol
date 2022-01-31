pragma solidity ^0.6.1;


import "./ERC20/StandardToken.sol";

contract Dildo is StandardToken {
    uint256 public decimals = 8;
    uint256 public totalSupply = 100e14;
    string public name = "Dildo Company Unlimited";
    string public symbol = "DIL";
    address public owner;

    uint256 public minimumBalanceForAccounts;
    uint256 public sellPrice;
    uint256 public buyPrice;

    modifier onlyOwner() {
        require(msg.sender == owner, "owner must be set");
        _;
    }

    constructor() public {
        owner = msg.sender;
        balances[owner] = totalSupply;
        minimumBalanceForAccounts = 5 finney;
        buyPrice = 100e14;
        sellPrice = 100e14;
    }

    // Change the owner of the contract
    function changeOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Address is empty");
        owner = newOwner;
    }

    // Burn and Mint
    event Burn(address indexed burner, uint256 value);

    function burn(address target, uint256 amount) external onlyOwner {
        require(amount <= balances[target], "burn require");
        balances[target] = balances[target].sub(amount);
        totalSupply = totalSupply.sub(amount);
        emit Burn(target, amount);
        emit Transfer(target, address(0), amount);
    }

    function mint(address target, uint256 mintedAmount) external onlyOwner {
        balances[target] += mintedAmount;
        totalSupply += mintedAmount;
        emit Transfer(address(0), address(this), mintedAmount);
        emit Transfer(address(this), target, mintedAmount);
    }

    // Buy and Sell
    // this is 0.001 ether for 1 token
    // https://www.etherchain.org/tools/unitConverter
    // uint256 public coinPrice = 1000000000000000;

    function setPrices(uint256 newSellPrice, uint256 newBuyPrice)
        external
        onlyOwner
    {
        sellPrice = newSellPrice;
        buyPrice = newBuyPrice;
    }

    function getSellPrice() public view onlyOwner returns (uint256) {
        return sellPrice;
    }

    function getBuyPrice() public view onlyOwner returns (uint256) {
        return buyPrice;
    }

    function getAmountBuyPrice(uint256 amount)
        public
        view
        onlyOwner
        returns (uint256)
    {
        return amount / buyPrice;
    }

    function buy() public payable returns (uint256 amount) {
        amount = msg.value / buyPrice;
        require(balances[owner] >= amount, "buy require");
        balances[owner] -= amount;
        balances[address(this)] += amount;
        emit Transfer(owner, address(this), amount);
        return amount;
    }

    function sell(uint256 amount) public returns (uint256 revenue) {
        require(balances[address(this)] >= amount, "sell require");
        balances[address(this)] = -amount;
        balances[owner] += amount;
        revenue = amount * sellPrice;
        //require(owner.send(revenue), "sell require 2");
        emit Transfer(address(this), owner, amount);
        return revenue;
    }
}