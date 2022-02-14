// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./Utils.sol";


contract TokenTransaction is AccessControl, Pausable, Utils {

    using SafeMath for uint256;

    address internal tokenAddress;
    uint256 internal dividePercentage;
    address internal divideWalletAddress;
    address internal signerAddress;

    constructor (address _tokenAddress, uint256 _dividePercentage, address _divideWalletAddress){
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        tokenAddress = _tokenAddress;
        dividePercentage = _dividePercentage;
        divideWalletAddress = _divideWalletAddress;
        signerAddress = msg.sender;
    }


    event TokenPay(uint256 bambPrice, uint256 eventType, uint256 eventId, uint256 dividePercentage, address divideWallet, uint256 dividePrice, address toAddress);
    event TokenCollect(uint256 amount, address fromAddress, address operator);

    function tokenPay(uint256 bambPrice, uint256 eventType, uint256 eventId, address toAddress, bytes32 hash, bytes memory signature, string memory nonce) public payable whenNotPaused {
        //验证数据参数合法性
        require(bambPrice > 0, "The bambPrice must more than 0!");
        //验证hash
        require(hashTokenPay(bambPrice, eventType, eventId, toAddress, nonce) == hash, "Invalid hash!");
        //验证签名
        require(matchAddressSigner(hash, signature), "Invalid signature!");
        //处理transfer
        if (toAddress != address(0)) {
            //计算分到的数量gv
            uint256 dividePrice = bambPrice.mul(dividePercentage).div(100);
            payable(divideWalletAddress).transfer(dividePrice);
            payable(toAddress).transfer(bambPrice.sub(dividePrice));
            emit TokenPay(bambPrice, eventType, eventId, dividePercentage, divideWalletAddress, dividePrice, toAddress);
        } else {
            payable(divideWalletAddress).transfer(bambPrice);
            emit TokenPay(bambPrice, eventType, eventId, dividePercentage, divideWalletAddress, 0, toAddress);
        }
    }

    function tokenCollect(uint256 amount, address fromAddress, bytes32 hash, bytes memory signature, string memory nonce) public payable whenNotPaused {
        //验证数据参数合法性
        require(amount > 0, "The amount must more than 0!");
        //验证hash
        require(hashTokenCollect(amount, fromAddress, msg.sender, nonce) == hash, "Invalid hash!");
        //验证签名
        require(matchAddressSigner(hash, signature), "Invalid signature!");
        //
        payable(address(this)).transfer(amount);
        payable(msg.sender).transfer(amount);
        emit TokenCollect(amount, fromAddress, msg.sender);
    }


    function hashTokenPay(uint256 _bambPrice, uint256 _eventType, uint256 _eventId, address _toAddress, string memory _nonce) private pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32",
            keccak256(abi.encodePacked(_bambPrice, _eventType, _eventId, _toAddress, _nonce))));
        return hash;
    }

    function hashTokenCollect(uint256 _amount, address _fromAddress, address _operator, string memory _nonce) private pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32",
            keccak256(abi.encodePacked(_amount, _fromAddress, _operator, _nonce))));
        return hash;
    }


    function matchAddressSigner(bytes32 hash, bytes memory signature) private view returns (bool) {
        return signerAddress == recoverSigner(hash, signature);
    }


    function setSignerAddress(address _signerAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        signerAddress = _signerAddress;
    }

    function setDividePercentage(uint256 _dividePercentage) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        dividePercentage = _dividePercentage;
    }

    function setDivideWalletAddress(address _divideWalletAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        divideWalletAddress = _divideWalletAddress;
    }


}