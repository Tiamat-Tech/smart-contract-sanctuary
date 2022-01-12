// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.6;
pragma abicoder v2;

import "./Wrapper.sol";

contract BookStore is Wrapper {

    constructor() public {
        string memory bookName = "initBook";
        string memory authorName = "initAuthor";
        address[] memory addresses;
        uint bookId = uint(keccak256(abi.encodePacked(bookName, authorName))) % 10 ** 10;
        books[bookId] = Book(bookId, 100, BOOK_RENT_PRICE, bookName, authorName, addresses);
        bookIds.push(bookId);
    }

    // CONSTANTS
    uint constant private BOOK_RENT_PRICE = 100000000000000000;
    string constant private WRONG_ID = "Wrong ID";
    string constant private NOT_RENTED = "Book not rented";
    string constant private NO_COPIES = "No copies available";
    string constant private NOT_ENOUGH_BALANCE = "Not enough LIB balance";

    // VARIABLES
    uint[] bookIds;
    mapping (uint => Book) private books; // Library
    mapping (address => mapping(uint => bool)) private existingUser; // Address -> bookId => bool
    mapping (address => mapping(uint => uint)) private rentedBooks; // ID => COPIES

    // EVENTS
    event bookAdded(string indexed _bookName, string indexed _author, uint _copies);
    event bookUpdated(string indexed _bookName, string indexed _author, uint _copies);
    event bookRented(address indexed _rentedBy, string indexed _author, string indexed _bookName);
    event bookReturned(address indexed _returnedBy, string indexed _author, string indexed _bookName);

    // STRUCTS
    struct Book {
        uint id;
        uint copies;
        uint rentPrice;
        string bookName;
        string author;
        address[] borrowers;
    }

    // FUNCTIONS
    function addBook(string memory _bookName, string memory _author, uint _copies) external onlyOwner {
        uint bookId = uint(keccak256(abi.encodePacked(_bookName, _author))) % 10 ** 10;

        if (bookExists(bookId)) {
            books[bookId].copies += _copies;
            emit bookUpdated(_bookName, _author, _copies);
        } else {
            address[] memory addresses;
            books[bookId] = Book(bookId, _copies, BOOK_RENT_PRICE, _bookName, _author, addresses);
            bookIds.push(bookId);
            emit bookAdded(_bookName, _author, _copies);
        }
    }

    function rentBook(uint _bookId) external {
        address userAddress = msg.sender;
        require(bookExists(_bookId), WRONG_ID);
        require(books[_bookId].copies > 0, NO_COPIES);
        require(LIBToken.balanceOf(msg.sender) >= BOOK_RENT_PRICE, NOT_ENOUGH_BALANCE);

        LIBToken.transferFrom(msg.sender, address(this), BOOK_RENT_PRICE);
        emit successfullPayment(msg.sender, address(this), BOOK_RENT_PRICE);

        rentedBooks[userAddress][_bookId]++;
        books[_bookId].copies--;

        if (!existingUser[userAddress][_bookId]) { // If the user rents the particular book for a first time.
            books[_bookId].borrowers.push(userAddress);
            existingUser[userAddress][_bookId] = true;
        }

        emit bookRented(userAddress, books[_bookId].author, books[_bookId].bookName);
    }

    function returnBook(uint _bookId) external {
        address userAddress = msg.sender;
        require(bookExists(_bookId), WRONG_ID);
        require(rentedBooks[userAddress][_bookId] > 0, NOT_RENTED);

        rentedBooks[userAddress][_bookId]--;
        books[_bookId].copies++;
        emit bookReturned(userAddress, books[_bookId].author, books[_bookId].bookName);    
    }

    function bookExists(uint _id) internal view returns (bool) {
        return bytes(books[_id].bookName).length > 0;
    }

    // GAS-FREE FUNCTIONS
    function showBooks() external view returns (Book[] memory) {
        uint availableBooks = bookIds.length;
        Book[] memory results = new Book[](availableBooks);
        for (uint i=0; i<availableBooks; i++) {
            results[i] = books[bookIds[i]];
        }
        return results;
    }

    function showBorrowers(uint _bookId) external view returns (address[] memory) {
        return books[_bookId].borrowers;
    }

}