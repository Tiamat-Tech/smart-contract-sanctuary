pragma solidity ^0.6.12;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Presale is Context, Ownable {
    uint256 public minContribution = 0.1 ether;
    uint256 public maxContribution = 0.3 ether;
    uint256 public totalContributed = 0;
    uint256 public totalCap = 0.6 ether;

    address payable deployer = 0x8D68C698917D6D1e447562bD226eB1698F0D98FA;

    mapping(address => uint256) public contributions;

    receive() external payable {
        require(totalContributed + msg.value <= totalCap, "Cap reached");
        require(msg.value >= minContribution && msg.value <= maxContribution, "Min contribution 0.5 max 1 ETH");
        require(contributions[msg.sender] + msg.value <= maxContribution, "Max contribution per wallet 1 ETH");

        totalContributed += msg.value;
        contributions[msg.sender] += msg.value;
    }

    function collectFunds() external onlyOwner() {
        deployer.transfer(address(this).balance);
    }
}