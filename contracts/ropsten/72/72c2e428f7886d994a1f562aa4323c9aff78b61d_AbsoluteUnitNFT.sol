// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface ITHEAbsoluteUnit {
    function absoluteUnitSaleFee() external payable;
}

contract AbsoluteUnitNFT is ERC1155Supply, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant TOKEN_ID = 1;

    uint256 public constant SERVICE_FEE = 50;
    uint256 public constant HOLDERS_FEE = 40;
    uint256 public constant AWESOMENESS_FEE = 10;

    string public name;
    string public symbol;

    uint256 public lastPrice;
    address payable public serviceAddress;
    address public theAbsoluteUnitAddress;
    address payable[1000] public buyers;
    uint256 public buysCount;
    uint256 public totalHoldersFee;
    uint256 public maxBuys;

    event BecomeAnAbsoluteUnit(address indexed owner, uint256 amount, uint256 price);

    modifier onlyServiceAddress() {
        require(msg.sender == serviceAddress, "Only service address can call this function.");
        _;
    }

    constructor(
        address payable _serviceAddress,
        string memory tokenURI,
        uint256 totalSupply,
        address _theAbsoluteUnitAddress,
        uint256 _maxBuys
    ) ERC1155(tokenURI) {
        lastPrice = 0.00125 ether;
        buysCount = 0;
        serviceAddress = _serviceAddress;
        maxBuys = _maxBuys;
        theAbsoluteUnitAddress = _theAbsoluteUnitAddress;
        name = "Absolute Unit";
        symbol = "ABSUNIT";
        _mint(serviceAddress, TOKEN_ID, totalSupply, "");
    }

    function isApprovedForAll(address, address) public view virtual override returns (bool) {
        return true;
    }

    function becomeAnAbsoluteUnit(address payable recipient, uint256 amount) public payable virtual nonReentrant {
        require(amount <= maxBuys, "Trying to buy more than allowed amount");
        _beforeTokenTransfer(amount);
        for (uint256 index = 0; index < amount; index++) {
            uint256 nextSellerIndex = buysCount % totalSupply(TOKEN_ID);
            address nextSeller = buyers[nextSellerIndex] == address(0) ? serviceAddress : buyers[nextSellerIndex];
            safeTransferFrom(nextSeller, recipient, TOKEN_ID, 1, ""); // Only 1 token at a time
            _afterTokenTransfer(recipient);
        }

        // After the loop to save gas
        uint256 serviceFee = (msg.value * SERVICE_FEE) / 1000;
        uint256 awesomenessFee = (msg.value * AWESOMENESS_FEE) / 1000;
        if (serviceFee > 0) {
            Address.sendValue(serviceAddress, serviceFee);
        }
        if (awesomenessFee > 0) {
            ITHEAbsoluteUnit(theAbsoluteUnitAddress).absoluteUnitSaleFee{value: awesomenessFee}();
        }

        emit BecomeAnAbsoluteUnit(recipient, amount, lastPrice);
    }

    function salvageTokens(address asset) public onlyServiceAddress {
        uint256 balance = IERC20(asset).balanceOf(address(this));
        IERC20(asset).safeTransfer(serviceAddress, balance);
    }

    function salvageETH() public onlyServiceAddress {
        uint256 balance = address(this).balance;
        if (balance - totalHoldersFee > 0) {
            Address.sendValue(serviceAddress, balance - totalHoldersFee);
        }
    }

    function updateServiceAddress(address payable _serviceAddress) public virtual onlyServiceAddress {
        require(_serviceAddress != address(0), "Service address can't be zero");
        serviceAddress = _serviceAddress;
    }

    function updateMaxBuys(uint256 _maxBuys) public virtual onlyServiceAddress {
        require(
            _maxBuys > 0 && _maxBuys <= totalSupply(TOKEN_ID),
            "Max buys must be above zero and below total supply"
        );
        maxBuys = _maxBuys;
    }

    // ---

    function _beforeTokenTransfer(uint256 amount) internal virtual {
        uint256 totalSupply = totalSupply(TOKEN_ID);
        uint256 buysLeftTillDoublePrice = totalSupply - (buysCount % totalSupply);

        if (buysLeftTillDoublePrice > amount) {
            require(msg.value == (lastPrice * 2 * amount), "You need to send twice the amount of previous price");
        } else {
            uint256 buysInCurrentPrice = buysLeftTillDoublePrice;
            uint256 buysInNextPrice = amount - buysInCurrentPrice;
            require(
                msg.value == ((lastPrice * 2 * buysInCurrentPrice) + (lastPrice * 4 * buysInNextPrice)),
                "You need to send twice the amount of previous price"
            );
        }
    }

    function _afterTokenTransfer(address payable to) internal virtual {
        uint256 sellingPrice = lastPrice * 2;

        uint256 totalSupply = totalSupply(TOKEN_ID);
        uint256 nextSellerIndex = buysCount % totalSupply;
        address payable nextSeller = buyers[nextSellerIndex] == address(0) ? serviceAddress : buyers[nextSellerIndex];
        buyers[nextSellerIndex] = to;
        if (nextSellerIndex == (totalSupply - 1)) {
            lastPrice = sellingPrice;
        }

        // --
        uint256 serviceFee = (sellingPrice * SERVICE_FEE) / 1000;
        uint256 holdersFee = (sellingPrice * HOLDERS_FEE) / 1000;
        uint256 awesomenessFee = (sellingPrice * AWESOMENESS_FEE) / 1000;

        // Only the first batch of sellers not getting holdersBonus because it is the service address
        uint256 holdersBonus = buysCount < totalSupply ? 0 : totalHoldersFee / totalSupply;
        // Current buyer fee not included in current seller bonus
        totalHoldersFee = totalHoldersFee - holdersBonus + holdersFee;
        buysCount += 1;
        Address.sendValue(nextSeller, sellingPrice - serviceFee - holdersFee - awesomenessFee + holdersBonus);
    }

    receive() external payable {}
}