// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract TicketBookingSystem {
    struct Seat {
        uint16 rowNumber;
        uint16 seatNumber;
        // each TicketBookingSystem handles a single show title,
        // which may be played multiple times, distinguished by the timestamp
        uint64 timestamp; // unix timestamp (in seconds) of the show
        string seatViewURL;
        uint256 price;
    }

    //Public attributes
    string public showTitle;
    uint64 public validationTimeframe;
    Seat[] public seats;            //Array of seats created during deploy

    // tokens must be public for everyone to see ownership
    Ticket public tickets = new Ticket();
    Poster public posters = new Poster();

    //Private attributes
    address private creator;

    //modifiers
    modifier onlySalesManager() {   //Only the Sales Manager can call the function
        require(
            msg.sender == creator,
            "The calling address is not authorized."
        );
        _;
    }

    modifier correctTimeFrame(uint256 tokenId) { //The function can only be called during the specific timeframe
        require(
            block.timestamp <= seats[tokenId].timestamp,
            "The ticket has expired"
        );
        require(
            block.timestamp >= seats[tokenId].timestamp - validationTimeframe,
            "The validation period hasn't started."
        );
        _;
    }

    constructor(
        string memory title,
        uint64 _validationTimeframe, // time before show timestamp when the ticket can be validated (in seconds)
        Seat[] memory _seats
    ) {
        creator = msg.sender;
        showTitle = title;
        validationTimeframe = _validationTimeframe;
        for (uint256 i = 0; i < _seats.length; ++i) {
            seats.push(_seats[i]);
        }
    }

    //Function for buying tickets
    function buy(uint256 seatId) public payable returns (uint256 newTokenId) {
        require(
            msg.value == seats[seatId].price,
            "The price of the ticket is not correct."
        ); //The paid value needs to be the same as the price
        require(
            seats[seatId].timestamp > block.timestamp,
            "The specified ticket is no longer valid."
        ); //The show time is in the future
        require(
            seats[seatId].timestamp - validationTimeframe >= block.timestamp,
            "The Validation already started and the ticket can't be bought anymore"
            // tickets cannot be bought once the validation has started
        );
        return tickets.mintTKT(msg.sender, seatId);
    }

    //verifies tickets owners
    function verify(uint256 tokenId) public view returns (address) {
        address ticketOwner = tickets.ownerOf(tokenId);
        require(
            block.timestamp <= seats[tokenId].timestamp,
            "The ticket has expired"
        );//The ticket must not be expired
        return ticketOwner;
    }

    /**
    Invoked when the show has been cancelled.
    Refunds all ticket owners and destroys their tickets.
    Can only be called by the Sales Manager.
    */
    function refund() public onlySalesManager {
        for (uint256 id = 0; id < seats.length; ++id) {
            // do not refund tickets for past shows
            if (seats[id].timestamp > block.timestamp) {
                try tickets.ownerOf(id) returns (address owner) {
                    tickets.burnTKT(id);
                    payable(owner).transfer(seats[id].price);
                } catch {
                    // if the ticket does not exist, there is nothing to return
                    continue;
                }
            }
        }
    }

    //Destroys the ticket and creates a POSTER token. Can only be called during a specific timeframe
    function validate(uint256 tokenId)
        public
        correctTimeFrame(tokenId)
        returns (uint256)
    {
        require(
            tickets.ownerOf(tokenId) == msg.sender,
            "The owner of the ticket is invalid."
        ); //The owner of the ticket needs to call this
        tickets.burnTKT(tokenId); //Destroy original ticket
        return posters.mintPTR(msg.sender, tokenId); //Create poster that serves as proof-of-purchase
    }
}

contract Ticket is ERC721, ERC721Burnable {
    address public minterAddress;

    //Mappings for re-selling purchased tickets
    mapping(uint256 => uint256) private _salePrice;
    mapping(uint256 => bool) private _isSellable;

    //Mapping for swapping purchased tickets
    mapping(uint256 => uint256[]) private _swappableWith;

    constructor() ERC721("Ticket", "TKT") {
        minterAddress = msg.sender;
    }

    //Only the TicketBookingSystem contract can call the function
    modifier onlyBookingSystem() {
        require(
            msg.sender == minterAddress,
            "The calling address is not authorized."
        );
        _;
    }

    //The ticket must exist
    modifier ticketExists(uint256 tokenId) {
        require(_exists(tokenId), "The ticket with this ID does not exist.");
        _;
    }

    //Only the owner of the ticket can call the function
    modifier onlyOwner(uint256 tokenId) {
        require(
            msg.sender == ownerOf(tokenId),
            "The calling address is not the owner."
        );
        _;
    }

    //Mint a new ticket after purchase
    function mintTKT(address recipient, uint256 seatId)
        public
        onlyBookingSystem
        returns (uint256)
    {
        _safeMint(recipient, seatId);
        return seatId;
    }

    //Burn the ticket 
    function burnTKT(uint256 seatId) public onlyBookingSystem {
        _burn(seatId);
    }

    //Set whether the ticket can be re-sold. Available only to the owner.
    function setSellable(
        uint256 tokenId,
        bool isSellable,
        uint256 price
    ) public ticketExists(tokenId) onlyOwner(tokenId) {
        _isSellable[tokenId] = isSellable;  //Specifies whether others can buy this ticket or not
        if (isSellable) {
            _salePrice[tokenId] = price; //Price of the ticket on secondary market. Ignored if `isSellable` is false
        } else {
            _salePrice[tokenId] = 0;
        }
    }

    //Set whether the ticket can be swapped with other tickets. Available only to the owner.
    function setSwappable(uint256 tokenId, uint256[] memory tokens)
        public
        ticketExists(tokenId)
        onlyOwner(tokenId)
    {
        //Set Tokens that can be swapped with the offered token. Empty array means that the token is not swappable.
        _swappableWith[tokenId] = tokens; 
    }

    /**
    Returns information if given ticket is sellable.
    If it is sellable, returns the price. If not, the second returned value should be ignored.
     */
    function getResalePrice(uint256 tokenId)
        public
        view
        ticketExists(tokenId)
        returns (bool isSellable, uint256 price)
    {
        isSellable = _isSellable[tokenId];
        if (isSellable) {
            price = _salePrice[tokenId];
        }
    }

    /**
    Returns the list of ticket IDs that can be swapped with the given ticket ID.
     */
    function getSwappableTickets(uint256 tokenId)
        public
        view
        ticketExists(tokenId)
        returns (uint256[] memory tokens)
    {
        tokens = _swappableWith[tokenId];
    }

    //Stops a ticket from being "sellable" and "swappable"
    function stopTicketTradeability(uint256 tokenId) private {
        _isSellable[tokenId] = false;
        delete _swappableWith[tokenId];
    }

    //Buys a ticket marked as "sellable"
    function buySellableTicket(uint256 tokenId)
        public
        payable
        ticketExists(tokenId)
    {
        require(_isSellable[tokenId], "The ticket is not sellable.");   //The ticket must have been marked as "sellable" beforehand
        require(
            msg.value == _salePrice[tokenId],
            "The payment amount is not correct."
        );//The payment sent must match the ticket's new price

        address payable owner = payable(ownerOf(tokenId));
        _transfer(owner, msg.sender, tokenId); // Change ownership
        stopTicketTradeability(tokenId); // the new owner decides about ticket tradeability
        owner.transfer(msg.value); // Transfer payment
    }

    //Swap two tickets if one is marked as "swappable" based on the `swappableWith` list
    function swapTickets(uint256 tokenToGetId, uint256 tokenToGiveId)
        public
        ticketExists(tokenToGetId)
        ticketExists(tokenToGiveId)
        onlyOwner(tokenToGiveId)
    {
        bool tokensAreSwappable = false;
        for (uint256 i = 0; i < _swappableWith[tokenToGetId].length; i++) {
            if (tokenToGiveId == _swappableWith[tokenToGetId][i]) {
                tokensAreSwappable = true;
            }
        }
        require(tokensAreSwappable, "The tickets are not swappable."); // The tickets must match the swappable list

        address owner = ownerOf(tokenToGetId);
        _transfer(owner, msg.sender, tokenToGetId); // Change the ownership of both tickets
        _transfer(msg.sender, owner, tokenToGiveId);
        // the new owner decides about ticket tradeability
        stopTicketTradeability(tokenToGetId);
        stopTicketTradeability(tokenToGiveId);
    }

    //Returns the title of the show for which the ticket is valid
    function getTitle() public view returns (string memory) {
        return TicketBookingSystem(minterAddress).showTitle();
    }

    //Returns the seat row for the specific ticket
    function getRow(uint256 tokenId)
        public
        view
        ticketExists(tokenId)
        returns (uint16)
    {
        (uint16 rowNumber, , , , ) = TicketBookingSystem(minterAddress).seats(
            tokenId
        );
        return rowNumber;
    }

    //Returns the seat number for the specific ticket
    function getSeatNumber(uint256 tokenId)
        public
        view
        ticketExists(tokenId)
        returns (uint16)
    {
        (, uint16 seatNumber, , , ) = TicketBookingSystem(minterAddress).seats(
            tokenId
        );
        return seatNumber;
    }

    //Returns the timestamp of the show for which the ticket is valid
    function getTimestamp(uint256 tokenId)
        public
        view
        ticketExists(tokenId)
        returns (uint64)
    {
        (, , uint64 timestamp, , ) = TicketBookingSystem(minterAddress).seats(
            tokenId
        );
        return timestamp;
    }

    //Returns the seat view URL for the specific ticket
    function getSeatViewURL(uint256 tokenId)
        public
        view
        ticketExists(tokenId)
        returns (string memory)
    {
        (, , , string memory url, ) = TicketBookingSystem(minterAddress).seats(
            tokenId
        );
        return url;
    }

    //Returns the seat price for the specific ticket
    function getPrice(uint256 tokenId)
        public
        view
        ticketExists(tokenId)
        returns (uint256)
    {
        (, , , , uint256 price) = TicketBookingSystem(minterAddress).seats(
            tokenId
        );
        return price;
    }
}

contract Poster is ERC721 {
    address public minterAddress;
    uint256 private tokenId;

    constructor() ERC721("Poster", "PTR") {
        minterAddress = msg.sender;
    }

    //Only the TicketBookingSystem contract can call the function
    modifier onlyBookingSystem() {
        require(
            msg.sender == minterAddress,
            "The calling address is not authorized."
        );
        _;
    }

    //Mint a POSTER after ticket validation
    function mintPTR(address recipient, uint256 itemId)
        public
        onlyBookingSystem
        returns (uint256)
    {
        _safeMint(recipient, itemId);
        return itemId;
    }

    //Returns the title of the show for which the poster is valid
    function getTitle() public view returns (string memory) {
        return TicketBookingSystem(minterAddress).showTitle();
    }
}