// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.7;

import "./hotel.sol";

contract VIPRooms is HotelRooms{
    room[] vipRooms;
    constructor(){
        fridge = true;
        microwave = true;
    }

    function getVIPRooms() public returns(room[] memory){
        delete vipRooms;
        for (uint i = 0; i < rooms.length; i++){
            if (keccak256(bytes(_toLower(rooms[i].roomType))) == keccak256(bytes("vip"))){
                vipRooms.push(rooms[i]);
            }
        }
        return vipRooms;
    }
}