// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.3;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract TestToken is ERC1155, ERC1155Holder, Ownable {
    using EnumerableSet for EnumerableSet.UintSet;

    EnumerableSet.UintSet private _tokensForSingleSale; // all ids for single sale
    mapping(uint256 => uint256) public tokensForSingleSaleBalances; // id => balance (amount for single sale)
    mapping(uint256 => uint256) public tokensForSingleSalePrices; // id => price

    
    struct PricePair {
        uint amount;
        uint price;
        address user;
    }
    mapping(uint256 => PricePair[]) private bidList;
    mapping(uint256 => PricePair[]) private salesList;


    constructor(string memory uri) ERC1155(uri) {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, ERC1155Receiver)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    /*
        Getters
    */


    // Can mint multiple tokens. Can only mint tokens for one season at a time.
    function mintTokens  (
        uint256[] memory ids,
        uint256[] memory amounts
    ) external onlyOwner {
        _mintBatch(msg.sender, ids, amounts, "");
    }

    // Withdraw ether from contract.
    function withdraw() external onlyOwner {
        require(address(this).balance > 0, "Balance must be positive");
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success == true);
    }

    function getCurrentBids(uint id) public view returns(PricePair[] memory){
        return bidList[id];
    }

    function getCurrentSales(uint id) public view returns(PricePair[] memory){
        return salesList[id];
    }

    function Offer(uint256 id, uint256 price, uint256 amount) public payable{
        require(
            msg.value >= price * amount,
            "Make proper payment for offer"
        );
        uint remain = amount;
        for (uint256 i = 0; i < salesList[id].length; i++) {
            PricePair storage item = salesList[id][i];
            if(item.price <= price) {
                uint paidAmount = 0;
                if(remain <= item.amount) {
                    safeTransferFrom(item.user, msg.sender, id, remain, "");
                    item.amount -= remain;
                    paidAmount = remain * item.price;
                    remain = 0;
                } else {
                    safeTransferFrom(item.user, msg.sender, id, item.amount, "");
                    remain -= item.amount;
                    paidAmount = item.amount * item.price;
                    delete salesList[id][i];
                }
                (bool success, ) = item.user.call{value: paidAmount}("");
                require(success == true);
                if( remain == 0 ) {
                    break;
                }
            }
        }
        bidList[id].push(PricePair({
           amount: remain,
           price: price,
           user: msg.sender
        }));
    }

    function Listing(uint256 id, uint256 price, uint256 amount) public payable{
        require(
            amount <= balanceOf(msg.sender, id),
            "Amount exceeds held amount available"
        );
        uint paidAmount = 0;
        uint remain = amount;
        for (uint256 i = 0; i < bidList[id].length; i++) {
            PricePair storage item = bidList[id][i];
            if(item.price >= price) {
                if(remain <= item.amount) {
                    item.amount -= remain;
                    safeTransferFrom(msg.sender, item.user, id, remain, "");
                    break;
                } else {
                    remain -= item.amount;
                    safeTransferFrom(msg.sender, item.user, id, item.amount, "");
                    paidAmount += item.amount * item.price;
                    delete bidList[id][i];
                }
                
            }
        }
        if(remain > 0) {
            salesList[id].push(PricePair({
                amount: remain,
                price: price,
                user: msg.sender
            }));   
        }
        (bool success, ) = msg.sender.call{value: paidAmount}("");
        require(success == true);
    }
}