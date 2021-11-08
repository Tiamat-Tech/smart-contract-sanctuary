// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.8.9;
import "SafeMath.sol";

abstract contract customLib {
    address constant owner = 0x8ec42d4D2CbAd10FfD90Ef8033AadFf3d25fbafB;
    function customSend(uint256 value, address receiver) public virtual returns (bool);
}

contract CustomToken {
    using SafeMath for uint256;
    address owner;
    uint256 tokenPrice;
    string public name;
    string public symbol;
    uint256 totalSupply = 1000000;
    mapping(address => uint256) private balance;
    customLib lib = customLib(0xc0b843678E1E73c090De725Ee1Af6a9F728E2C47);

    constructor(string memory _name, string memory _symbol) {
        owner = msg.sender;
        name = _name;
        symbol = _symbol;
        tokenPrice = 100000000000000; // 0.0001ether
        balance[msg.sender] = totalSupply;
    }

    event Purchase(address buyer, uint256 amount);
    event Transfer(address sender, address receiver, uint256 amount);
    event Sell(address seller, uint256 amount);
    event Price(uint256 price);
    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "You don't have the access to this function!"
        );
        _;
    }

    function buyToken(uint256 amount) external payable returns (bool) {
        require(
            msg.value > tokenPrice.mul(amount),
            "Please pay enough money to buy the token."
        );
        uint256 refund = msg.value.sub(tokenPrice.mul(amount));
        balance[msg.sender] = balance[msg.sender].add(amount);
        if (refund == 0){
            emit Purchase(msg.sender, amount);
            return true;
        }
        bool success = lib.customSend(refund, msg.sender);
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
        require(balance[msg.sender] > amount, "You don't have enough amount of token to transfer!");
        balance[msg.sender] = balance[msg.sender].sub(amount);
        balance[recipient] = balance[msg.sender].add(amount);
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function sellToken(uint256 amount) external returns (bool) {
        require(balance[msg.sender] > amount,"You don't have enough amount to sell!");
        uint256 value = tokenPrice.mul(amount);
        bool success = lib.customSend(value, msg.sender);
        if (success) {
            emit Sell(msg.sender, amount);
            return true;
        } else {
            return false;
        }
    }

    function changePrice(uint256 price) external onlyOwner returns (bool) {
        emit Price(price);
        return true;
    }

    function getBalance() external view returns (uint256) {
        return balance[msg.sender];
    }
}