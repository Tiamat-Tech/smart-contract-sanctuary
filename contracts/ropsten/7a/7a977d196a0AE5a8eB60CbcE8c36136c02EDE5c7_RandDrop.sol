// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface NFTinterface {
    function mint(
        address account,
        string memory _uri,
        bytes memory data
    ) external;
}

contract RandDrop is Ownable {
    IERC20 tokenVVPT;
    IERC1155 tokenNFT;
    NFTinterface tokenNFTinterface;
    using Counters for Counters.Counter;
    Counters.Counter private _RandNFTIdCounter;
    uint256 delay = 1 minutes;
    address admin;
    mapping(address => uint256) public balancesLocked;
    mapping(address => uint256) public lockTime;
    event RandDropSalary(uint256 sallary);

    constructor(address erc20, address erc1155) {
        admin = msg.sender;
        tokenVVPT = IERC20(address(erc20));
        tokenNFT = IERC1155(address(erc1155));
        tokenNFTinterface = NFTinterface(address(erc1155));
    }

    function lockTokenErc20(uint256 amountToken) external {
        require(tokenVVPT.balanceOf(msg.sender) >= 10);
        tokenVVPT.transferFrom(msg.sender, address(this), amountToken);
        balancesLocked[msg.sender] += amountToken;
        lockTime[msg.sender] = block.timestamp + delay;
    }

    function withdrawRandNFT(string memory uri, bytes memory data) external {
        require(
            balancesLocked[msg.sender] >= 10 &&
                block.timestamp > lockTime[msg.sender],
            "Timelock: locked"
        );
        _RandNFTIdCounter.increment();
        tokenNFTinterface.mint(msg.sender, uri, data);
        balancesLocked[msg.sender] = 0;
    }

    function exhaust() external onlyOwner {
        uint256 RandDropBalance = tokenVVPT.balanceOf(address(this));
        emit RandDropSalary(RandDropBalance);
        tokenVVPT.transfer(msg.sender, RandDropBalance);
    }

    function setDelay(uint256 _delay) external {
        require(block.timestamp > delay, "Timelock: locked");
        require(msg.sender == admin, "Ownable: caller is not the owner");
        delay = block.timestamp + _delay;
    }

    function getDelay() external view returns (uint256) {
        return delay;
    }
}