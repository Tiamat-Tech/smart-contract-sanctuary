// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract TheAbsoluteUnitNFT is ERC721URIStorage, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant TOKEN_ID = 1;
    uint256 public constant SERVICE_FEE = 50;

    uint256 public lastPrice;
    address payable public serviceAddress;
    OwnerHistory[] public ownersHistory;
    uint256 public awesomenessFee;

    event BecomeTheAbsoluteUnit(address indexed newOwner, address indexed oldOwner, uint256 price);

    struct OwnerHistory {
        address owner;
        uint256 startTimeStamp;
        uint256 startBlock;
        uint256 endTimeStamp;
        uint256 endBlock;
        uint256 price;
    }

    modifier onlyTokenOwner() {
        require(msg.sender == ERC721.ownerOf(TOKEN_ID), "Only token owner can call this function.");
        _;
    }

    modifier onlyServiceAddress() {
        require(msg.sender == serviceAddress, "Only service address can call this function.");
        _;
    }

    constructor(address payable _serviceAddress, string memory tokenURI) ERC721("THE Absolute Unit", "THEABSUNIT") {
        lastPrice = 0.000001 ether;
        awesomenessFee = 0;
        serviceAddress = _serviceAddress;
        _mint(serviceAddress, TOKEN_ID);
        _setTokenURI(TOKEN_ID, tokenURI);
        _afterTokenTransfer(payable(0), serviceAddress, TOKEN_ID);
    }

    function _isApprovedOrOwner(address, uint256) internal view virtual override returns (bool) {
        return true;
    }

    function becomeTheAbsoluteUnit(address payable recipient) public payable virtual nonReentrant {
        address payable owner = payable(ERC721.ownerOf(TOKEN_ID));

        safeTransferFrom(owner, recipient, TOKEN_ID);

        _afterTokenTransfer(owner, recipient, TOKEN_ID);

        emit BecomeTheAbsoluteUnit(recipient, owner, msg.value);
    }

    function claimAwesomenessFee() public onlyTokenOwner nonReentrant {
        require(awesomenessFee > 0, "No fees yet, but you are still awesome!");
        address payable owner = payable(ERC721.ownerOf(TOKEN_ID));
        _sendAwesomenessFee(owner);
    }

    function absoluteUnitSaleFee() external payable virtual {
        awesomenessFee += msg.value;
    }

    function getOwnersHistory() public view returns (OwnerHistory[] memory) {
        return ownersHistory;
    }

    function salvageTokens(address asset) public onlyServiceAddress {
        uint256 balance = IERC20(asset).balanceOf(address(this));
        IERC20(asset).safeTransfer(serviceAddress, balance);
    }

    function salvageETH() public onlyServiceAddress {
        uint256 balance = address(this).balance;
        if (balance - awesomenessFee > 0) {
            Address.sendValue(serviceAddress, balance - awesomenessFee);
        }
    }

    function updateServiceAddress(address payable _serviceAddress) public virtual onlyServiceAddress {
        require(_serviceAddress != address(0), "Service address can't be zero");
        serviceAddress = _serviceAddress;
    }

    // ---

    function _beforeTokenTransfer(
        address from,
        address,
        uint256
    ) internal virtual override {
        if (from == address(0)) {
            // Minting
            return;
        }

        require(msg.value == (lastPrice * 2), "You need to send twice the amount of previous price");
    }

    function _afterTokenTransfer(
        address payable from,
        address payable to,
        uint256
    ) internal virtual {
        if (from != address(0)) {
            lastPrice = msg.value;
        }

        if (ownersHistory.length > 0) {
            OwnerHistory storage currentOwner = ownersHistory[ownersHistory.length - 1];
            currentOwner.endTimeStamp = block.timestamp;
            currentOwner.endBlock = block.number;
        }

        ownersHistory.push(OwnerHistory(to, block.timestamp, block.number, 0, 0, lastPrice));

        uint256 serviceFee = (msg.value * SERVICE_FEE) / 1000;
        if (serviceFee > 0) {
            Address.sendValue(serviceAddress, serviceFee);
        }
        if (msg.value - serviceFee > 0) {
            Address.sendValue(from, msg.value - serviceFee);
        }

        _sendAwesomenessFee(from);
    }

    function _sendAwesomenessFee(address payable to) internal virtual {
        uint256 rewards = awesomenessFee;
        awesomenessFee = 0;
        if (rewards > 0) {
            Address.sendValue(to, rewards);
        }
    }

    receive() external payable {}
}