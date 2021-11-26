// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./SafeMath.sol";

contract Market {
    using SafeMath for uint;
    struct Commodity {
        string  name;
        string  url;
        uint    price;      // 单位ether
        address seller;
        address buyer;
        uint    time;
        uint    timeInterval;       // 间隔多长时间卖出
        bool    isFinish;
    }

    mapping(address => Commodity)   warehouse_;

    modifier commodityExist(address seller) {
        Commodity storage commodity = warehouse_[seller];
        require(commodity.seller != address(0x0));
        _;
    }

    function addCommodity(string memory name, string memory url, uint price) public {
        require(bytes(name).length > 0);
        require(bytes(url).length > 0);

        warehouse_[msg.sender] = Commodity(name, url, price /(1 ether), msg.sender, address(0x0), block.timestamp, 0, false);
    }

    function removeCommodity() public commodityExist(msg.sender){

        delete warehouse_[msg.sender];
    }

    function updateCommodity(string memory name, uint price) public commodityExist(msg.sender){
        Commodity storage commodity = warehouse_[msg.sender];

        commodity.name = name;
        commodity.price = price / (1 ether);
        commodity.time = block.timestamp;
    }

    function buy(address seller) payable public commodityExist(seller) returns (uint) {
        Commodity storage commodity = warehouse_[seller];

        require(msg.value == commodity.price);

        commodity.buyer = msg.sender;
        return commodity.price;
    }

    function confirmFinish(address seller) public commodityExist(seller){
        Commodity storage commodity = warehouse_[seller];
        require(commodity.buyer == msg.sender);

        commodity.isFinish = true;
        commodity.timeInterval = block.timestamp.sub(commodity.time);

        payable(commodity.seller).transfer(commodity.price);
    }
}