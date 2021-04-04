// SPDX-License-Identifier: MIT
pragma solidity >=0.4.25 <=0.8.3;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract BookingManager is AccessControl {
    // Creates a new role identifier for partners
    bytes32 public constant PARTNER_ROLE = keccak256("PARTNER_ROLE");
    
    enum RoomId { None, C01, C02, C03, C04, C05, C06, C07, C08, C09, C10, P01, P02, P03, P04, P05, P06, P07, P08, P09, P10 }

    event RoomBooked(RoomId roomId, uint hour, bytes32 userId, bytes32 userName);
    event RoomBookingCancelled(RoomId roomId, uint hour);

    struct UserBooking {
        bytes32 id;
        bytes32 name;
    }

    struct RoomBooking {
        mapping (uint => UserBooking) bookings;
    }
    
    mapping (uint => RoomBooking) roomBookings;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function book(RoomId roomId, uint hour, bytes32 userId, bytes32 userName) public {
        require(hasRole(PARTNER_ROLE, msg.sender), "Caller is not a partner");        
        require(hour <= 23, "The hour must be between 0 and 23 (inclusive)");
        require(userId != 0, "A user ID must be provided");
		require(roomBookings[uint(roomId)].bookings[hour].id == 0, "This room is already booked at this hour");
        
		roomBookings[uint(roomId)].bookings[hour].id = userId;
		roomBookings[uint(roomId)].bookings[hour].name = userName;

        emit RoomBooked(roomId, hour, userId, userName);
    }

	function cancelBooking(RoomId roomId, uint hour) public {
        require(hasRole(PARTNER_ROLE, msg.sender), "Caller is not a partner");        
        require(hour <= 23, "The hour must be between 0 and 23 (inclusive)");
		require(roomBookings[uint(roomId)].bookings[hour].id != 0, "This room is not booked at this hour");
        
		roomBookings[uint(roomId)].bookings[hour].id = 0;
		roomBookings[uint(roomId)].bookings[hour].name = 0;

		emit RoomBookingCancelled(roomId, hour);
	}

    function isBooked(RoomId roomId, uint hour) public view returns (bytes32, bytes32) {
        return (roomBookings[uint(roomId)].bookings[hour].id, roomBookings[uint(roomId)].bookings[hour].name);
    }
}