// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PaymentGateway is Ownable, ReentrancyGuard {
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address constant EthAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address payable public seller;

    struct PaymentInfo {
        uint256 amount;
        bool paid;
        address token;
    }

    mapping(bytes32 => PaymentInfo) public payments;
    mapping(address => bool) public tokens;

    event PaymentReceived(address indexed token, bytes32 indexed orderId, uint256 amount, address indexed buyer);
    event SupportedToken(address indexed token, bool support);
    event NewSeller(address indexed seller);
    event Withdrawal(address indexed tokenAddress, uint256 amount);

    constructor (address _seller) {
        require(
            _seller != address(0) && !_seller.isContract(),
            "invalid seller address"
        );
        seller = payable(_seller);
    }

    function erc20Payment(
        address erc20TokenAddress, 
        bytes32 orderId, uint256 amount) 
        external nonReentrant returns (bool) 
    {
        require(isSupportedToken(erc20TokenAddress), "token not supported");
        
        PaymentInfo storage p = payments[orderId];
        
        require(p.amount == 0 && p.paid == false, "order id already paid for");
        require(amount > 0 && orderId != 0x0, "invalid parameters");

        p.amount = amount;
        p.paid = true;
        p.token = erc20TokenAddress;

        // user must call erc20.approve before payment function
        require(IERC20(erc20TokenAddress).allowance(_msgSender(), address(this)) >= amount, "insufficient allowance to make payment");
        IERC20(erc20TokenAddress).safeTransferFrom(
            _msgSender(),
            address(this), // can also transfer to seller here
            amount
        );
        // here we can collect any fees or percentages

        emit PaymentReceived(erc20TokenAddress, orderId, amount, _msgSender());

        return true;
    }

    function ethPayment(
        bytes32 orderId, uint256 amount) 
        external payable nonReentrant returns (bool) 
    {
        // require(isSupportedToken(EthAddress), "token not supported");
        
        PaymentInfo storage p = payments[orderId];
        
        require(amount > 0 && orderId != 0x0, "invalid parameters");
        require(p.amount == 0 && p.paid == false, "order id already paid for");
        require(msg.value == amount, "amount not equal to msg.value");
        
        p.amount = msg.value;
        p.paid = true;
        p.token = EthAddress;

        // here we can collect any fees or percentages

        emit PaymentReceived(EthAddress, orderId, msg.value, _msgSender());

        return true;
    }

    function setSupportedToken(address tokenAddress, bool support) public onlyOwner {
        require(tokenAddress != address(0) && tokenAddress.isContract(), "invalid token address");
        tokens[tokenAddress] = support;
        emit SupportedToken(tokenAddress, support);
    }

    function isSupportedToken(address tokenAddress) public view returns (bool) {
        return tokens[tokenAddress];
    }

    function getPaymentInfo(bytes32 orderId) public view returns (PaymentInfo memory) {
        return payments[orderId];
    }

    function setSeller(address newSeller) public onlyOwner {
        require(
            newSeller != address(0) && !newSeller.isContract(),
            "invalid seller address"
        );
        seller = payable(newSeller);

        emit NewSeller(seller);
    }

    function withdraw(address tokenAddress) external nonReentrant {
        require(_msgSender() == seller, "only seller can withdraw");

        if (tokenAddress == EthAddress) {
            seller.transfer(address(this).balance);
            emit Withdrawal(tokenAddress, address(this).balance);
        } else {
            IERC20(tokenAddress).safeTransfer(seller, IERC20(tokenAddress).balanceOf(address(this)));
            emit Withdrawal(tokenAddress, IERC20(tokenAddress).balanceOf(address(this)));
        }
    }
}