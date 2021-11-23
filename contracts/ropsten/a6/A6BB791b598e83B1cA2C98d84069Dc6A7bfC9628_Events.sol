// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Events is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdTracker;

    constructor() ERC721("SU event system", "SUE") {}

    struct Event {
        uint256 fundsCollected;
        uint128 ticketPrice;
        uint128 availableTickets;
        address eventCreator;
    }

    Event[] public events;

    mapping(address => uint256[]) creatorToEvents;
    mapping(uint256 => uint256) ticketToEvent;

    function createEvent(uint128 numberOfTickets, uint128 pricePerTicket)
        external
    {
        events.push(Event(0, pricePerTicket, numberOfTickets, msg.sender));
        creatorToEvents[msg.sender].push(events.length - 1);
    }

    function mintTicket(uint256 eventId) external payable returns (uint256) {
        require(events.length > eventId);
        require(events[eventId].availableTickets > 0);
        require(msg.value >= events[eventId].ticketPrice);
        events[eventId].availableTickets--;
        events[eventId].fundsCollected += msg.value;
        uint256 ticketId = _tokenIdTracker.current();
        _tokenIdTracker.increment();
        ticketToEvent[ticketId] = eventId;
        _mint(msg.sender, ticketId);
        return ticketId;
    }

    function verifyTicketOwner(uint256 ticketId, string memory signedMessage)
        external
        view
        returns (bool)
    {
        // TODO
        console.log(signedMessage);
        address signerAddress = address(0);
        return ownerOf(ticketId) == signerAddress;
    }

    function withdrawFunds() external {
        uint256 sum = 0;
        for (uint256 i = 0; i < creatorToEvents[msg.sender].length; i++) {
            sum += events[creatorToEvents[msg.sender][i]].fundsCollected;
            events[creatorToEvents[msg.sender][i]].fundsCollected = 0;
        }
        (bool success, ) = msg.sender.call{value: sum}("");
        require(success, "Transfer failed.");
    }
}