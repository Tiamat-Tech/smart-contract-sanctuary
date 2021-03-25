pragma solidity ^0.6.12;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Presale is Context, Ownable {
    uint256 public minContribution = 0.1 ether;
    uint256 public maxContribution = 0.3 ether;
    uint256 public totalContributed = 0;
    uint256 public totalCap = 0.6 ether;

    address payable deployer = 0x2963B4311e07da3D9c50F2e1eb14659e42e3f4A9;

    mapping(address => uint256) public contributions;

    receive() external payable {
        require(totalContributed <= totalCap, "Cap reached");
        require(msg.value < minContribution || maxContribution > 1 ether, "Min contribution 0.5 max 1 ETH");
        require(contributions[msg.sender] <= maxContribution, "Max contribution per wallet 1 ETH");

        totalContributed += msg.value;
        contributions[msg.sender] = msg.value;
    }

    function collectFunds() external onlyOwner() {
        deployer.transfer(address(this).balance);
    }
}