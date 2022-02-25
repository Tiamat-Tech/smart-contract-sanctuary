//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

contract Baller {
    mapping(address => uint256) public _totals; // address => total over all time
    mapping(address => address) public _nfts; // maps owner address to nft
    mapping(address => uint256) public _txcount; // maps target address to number of transactions
    address payable _owner; // Me!
    uint256 _listing_fee; // Fixed wei fee for listing an NFT
    uint256 _support_fee; // Percentage i.e. 25 = 25%
    event Bumped(address sender, address target, uint256 weiAmount);

    constructor() {
        _owner = payable(msg.sender);
        _listing_fee = 0.025 ether;
        _support_fee = 30;
    }

    function updateNFT(address nft) public payable {
        // Require update fee
        require(msg.value > _listing_fee, "Listing / updating fee is required");

        // Update totals
        _nfts[msg.sender] = nft;
        _totals[msg.sender] = SafeMath.add(_totals[msg.sender], _listing_fee);
        _txcount[msg.sender] = SafeMath.add(_txcount[msg.sender], 1);

        // Emit event
        emit Bumped(msg.sender, msg.sender, msg.value);
    }

    function support(address target) public payable {
        uint256 fee;
        uint256 remainder;

        // Must be supporting an address that is on our contract
        require(_nfts[target] != address(0x00), "Address not on contract");

        // Calculate fees
        fee = (msg.value * _support_fee * 100) / 10000;
        remainder = SafeMath.sub(msg.value, fee);

        // Transfer Fee to owner
        (bool success,) = _owner.call{value: fee}("");
        require(success);

        // Transfer remainder to target
        (success, ) = target.call{value: remainder}("");
        require(success);

        // Update totals
        _totals[target] = _totals[target] = SafeMath.add(_totals[target], msg.value);
        _txcount[target] = SafeMath.add(_txcount[target], 1);

        // Emit event
        emit Bumped(msg.sender, target, msg.value);
    }

    function getTxCount(address _addr) public view returns (uint256) {
        return _txcount[_addr];
    }

    function getTotal(address _addr) public view returns (uint256) {
        return _totals[_addr];
    }

    function getListingFee() public view returns (uint256) {
        return _listing_fee;
    }

    function getSupportFee() public view returns (uint256) {
        return _support_fee;
    }

    function getListingFor(address _addr) public view returns (address) {
        return _nfts[_addr];
    }

    function setListingFee(uint256 fee) public {
        require(msg.sender == _owner, 'Only owner can change listing fee');
        require(fee > 0);
        _listing_fee = fee;
    }

    function setSupportFee(uint256 fee) public {
        require(msg.sender == _owner, 'Only owner can change support fee');
        require(fee >= 1);
        require(fee <= 100);
        _support_fee = fee;
    }

}