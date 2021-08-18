//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./IPets.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Market is Ownable{
    //Battle order types
    uint private ORDER_TYPE_ASK = 1;
    uint private ORDER_TYPE_BID = 2;
    uint private ORDER_TYPE_ASK_RENT = 11;
    uint private ORDER_TYPE_BID_RENT = 12;
    uint private ORDER_TYPE_RENTING = 10;

    uint256 lastOrderId;

    struct Orders{
        uint256 id;
        address user;
        uint256 orderType;
        uint256 pet_id;
        address new_owner;
        uint256 placed_at;
        uint256 ends_at;
        uint256 transfer_ends_at;
        uint256 value;
    }

    Orders[] public orders;

    IPets public pet;

    constructor(address _petAddress) {
        pet = IPets(_petAddress);
    }

    function updatePetAddress(address _petAddress) public onlyOwner{
        pet = IPets(_petAddress);
    }

    function newId() internal returns(uint256) {
        lastOrderId++;
        require(lastOrderId > 0, "_next_id overflow detected");
        //_update_pet_config(pc);
        return lastOrderId;
    }
    function findOrder(uint _id) internal view returns(bool, uint){
        for(uint i =0; i < orders.length; i++){
            if(orders[i].pet_id == _id){
                return(true, i);
            }
        }
        return(false, 0);    
    }

    function orderAsk(uint256 _petId, address _newOwner, uint256 _amount, uint256 _until) public payable{
        IPets.Pet memory pets = pet.getPets(_petId);
        require(pets.id != 0, "Pet not found or invalid pet");

        require(pets.owner != _newOwner, "new owner must be different than current owner");
        require(_amount >= 0, "amount cannot be negative");



        uint placedAt = block.timestamp;

        (bool isOrder, uint ix) = findOrder(_petId);

        uint256 _orderType;
        if (_until > 0) {
            require(_until > placedAt, "End of temporary transfer must be in the future");
            _orderType = ORDER_TYPE_ASK_RENT; // temporary transfer
        } else {
            _orderType = ORDER_TYPE_ASK; // indefinite transfer
        }

        if (isOrder) {
            Orders storage order = orders[ix];

            require(order.orderType != ORDER_TYPE_RENTING, "order can't be updated during temporary transfers");
            order.value = _amount;
            order.new_owner = _newOwner;
            order.orderType = _orderType;
            order.placed_at = placedAt;
            order.transfer_ends_at = _until;
        } else {
            Orders memory order = Orders({
                id:newId(),
                user: pets.owner,
                new_owner: _newOwner,
                pet_id: pets.id,
                orderType: _orderType,
                value: _amount,
                placed_at: placedAt,
                ends_at: 0,
                transfer_ends_at: _until
            });

            orders.push(order);
        }
    } 

    function removeAsk(uint256 _orderID) public {
    
        (bool isOrder, uint index) = getOrder(_orderID);
        require(isOrder, "Order not found or invalid order");
        require(orders[index].user == _msgSender(), "order can only be removed by owner of order");

        require(orders[index].orderType != ORDER_TYPE_RENTING, "orders can't be removed during temporary transfers");

        delete(orders[index]);
    }

    function getOrder(uint _id) internal view returns(bool, uint){
        for(uint i =0; i < orders.length; i++){
            if(orders[i].id == _id){
                return(true, i);
            }
        }
        return(false, 0);
    }

    uint public id;

    function claimPet(address _oldOwner, uint _petId, address _claimer) public {

        IPets.Pet memory pets = pet.getPets(_petId);
        require(pets.id != 0, "Pet not found or invalid pet");
        (bool isFindorder, uint i) = findOrder(_petId);
        require(isFindorder, "Order not found or invalid order");
        
        require(_claimer == orders[i].new_owner || orders[i].new_owner != address(0), "E404|Invalid claimer");

        require(_oldOwner == pets.owner, "Pet already transferred");

        require(orders[i].orderType != ORDER_TYPE_RENTING || orders[i].transfer_ends_at < block.timestamp, "E404|Temporary transfer not yet over");
        require(orders[i].value == 0, "orders requires value transfer");

        // Transfer Pet to claimer 
      
        pet.transferFromPet(_petId, _msgSender(), _claimer);

        // pet.transferPet(_petId, _claimer);

        if (orders[i].transfer_ends_at > 0) {
            if (orders[i].orderType == ORDER_TYPE_ASK_RENT) {
                orders[i].user = _claimer;
                orders[i].new_owner = _oldOwner;
                orders[i].value = 0;
                orders[i].orderType = ORDER_TYPE_RENTING;
            } else if (orders[i].orderType == ORDER_TYPE_RENTING) {
                delete(orders[i]);
            }
        } // else {
            //delete(orders[i]);
        //}
    }

    function bidPet(uint256 _petId, address _bidder, uint256 _amount, uint256 _until) public payable{
        IPets.Pet memory pets = pet.getPets(_petId);
        require(pets.id != 0, "Pet not found or invalid pet"); 

        (bool isFindorder, uint ix) = findOrder(_petId);

        require(pets.owner != _bidder, "bidder must be different than current owner");

        // validate eos
        require(_amount >= 0, "amount cannot be negative");

        uint order_type ;
        if (_until > 0) {
            order_type = ORDER_TYPE_BID_RENT; // temporary transfer
        } else {
            order_type = ORDER_TYPE_BID; // indefinite transfer
        }

        uint placedAt = block.timestamp;
        if (isFindorder) {
            orders[ix].value = _amount;
            orders[ix].placed_at = placedAt;
            orders[ix].transfer_ends_at = _until;
        } else {
            
            Orders memory order = Orders({
                id:newId(),
                user: _bidder,
                new_owner: _bidder,
                pet_id: pets.id,
                orderType: order_type,
                value: _amount,
                placed_at: placedAt,
                ends_at: 0,
                transfer_ends_at: _until
            });

            orders.push(order);
        }
    }

    function removeBid(uint orderId) public {
        (bool isOrder, uint index) = getOrder(orderId);
        require(isOrder, "Order not found or invalid order");

        require(orders[index].user != _msgSender(), "bids can only be removed by owner of bid");

        delete(orders[index]);
    }
}