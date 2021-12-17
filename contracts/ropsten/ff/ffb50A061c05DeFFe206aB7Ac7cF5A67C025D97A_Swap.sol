// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Swap {
    IERC20 public token;

    uint256 public exchangeRate = 500;

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
    }

    function swapEthToToken() public payable {
        uint256 tokenValue = msg.value * exchangeRate;
        require(token.balanceOf(address(this)) >= tokenValue, "Low Balance");
        token.transfer(msg.sender, tokenValue);
    }

    function swapTokenToEth(uint256 _value) public {
        uint256 ethValue = _value / exchangeRate;
        require(
            token.balanceOf(address(msg.sender)) >= ethValue,
            "Low Balance of sender"
        );
        require(address(this).balance >= ethValue, "Low Balance to provide");
        token.transferFrom(msg.sender, address(this), ethValue);
        payable(msg.sender).transfer(ethValue);
    }
}