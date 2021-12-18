// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Swap {
    using SafeMath for uint256;
    IERC20 public token;
    uint256 public exchangeRate = 500;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can execute");
        _;
    }

    event EthToToken(
        address indexed user,
        address token,
        uint256 amount,
        uint256 exchangeRate
    );

    event TokenToEth(
        address indexed user,
        address token,
        uint256 amount,
        uint256 exchangeRate
    );

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
        owner = msg.sender;
    }

    function changeExchangeRate(uint256 _rate) external onlyOwner {
        exchangeRate = _rate;
    }

    function swapEthToToken() public payable {
        uint256 tokenValue = msg.value.mul(exchangeRate);

        require(token.balanceOf(address(this)) >= tokenValue, "Low Balance");
        token.transfer(msg.sender, tokenValue);

        emit EthToToken(msg.sender, address(token), tokenValue, exchangeRate);
    }

    function swapTokenToEth(uint256 _value) public {
        uint256 ethValue = _value.div(exchangeRate);

        require(
            token.allowance(msg.sender, address(this)) >= ethValue,
            "No allowance"
        );
        require(
            token.balanceOf(address(msg.sender)) >= _value,
            "Low balance of sender"
        );
        require(address(this).balance >= ethValue, "Low balance of provider");
        token.transferFrom(msg.sender, address(this), _value);
        payable(msg.sender).transfer(ethValue);

        emit TokenToEth(msg.sender, address(token), _value, exchangeRate);
    }
}