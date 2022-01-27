// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/access/Ownable.sol";

contract BookLibrary is Ownable {
    mapping(uint256 => Book) books;
    uint256 totalBooksCount;
    mapping(uint256 => address[]) borrowersLedger;
    mapping(address => mapping(uint256 => bool)) booksBorrowedByAddress;
    //not used at the moment
    Book[] allAvailableBooks;

    constructor() {
        totalBooksCount = 0;
    }

    struct Book {
        string title;
        uint256 copies;
        bool available;
        bool valid;
    }

    modifier bookIsValid(uint256 _id) {
        require(books[_id].valid, "This book doesn't exist...");
        _;
    }

    event NewBookAdded(string title, uint256 copies);

    //add new book
    function addBook(string memory _title, uint256 _copies) external onlyOwner {
        //TODO check external vs public in terms of gas usage
        Book memory newBook = Book({
            title: _title,
            copies: _copies,
            available: true,
            valid: true
        });
        books[totalBooksCount] = newBook;
        totalBooksCount++;
        allAvailableBooks.push(newBook);
        emit NewBookAdded(_title, _copies);
    }

    //get tatal number books in the library
    function getTotalBooksCount() external view returns (uint256) {
        return totalBooksCount;
    }

    //add new copies
    function increaseCopies(uint256 _id, uint256 _numToIncrease)
        public
        onlyOwner
    {
        require(
            _numToIncrease > 0,
            "Please provide a number greater than zero!"
        );
        books[_id].copies += _numToIncrease;

        if (books[_id].copies > 0) {
            books[_id].available = true;
        }
    }

    //get book by id
    function getBookById(uint256 _id)
        external
        view
        bookIsValid(_id)
        returns (Book memory)
    {
        return books[_id];
    }

    //borrow a book by id
    function borrowBook(uint256 _id) public bookIsValid(_id) {
        Book storage book = books[_id];
        require(book.valid, "This book doesn't exist...");
        require(
            book.available && !booksBorrowedByAddress[msg.sender][_id],
            "Sorry, you won't be able to borrow this book now..."
        );

        book.copies--;
        borrowersLedger[_id].push(msg.sender);
        booksBorrowedByAddress[msg.sender][_id] = true;

        if (book.copies == 0) {
            book.available = false;
        }
    }

    //return borrowed book
    function returnBook(uint256 _id) public bookIsValid(_id) {
        Book storage book = books[_id];
        require(
            booksBorrowedByAddress[msg.sender][_id],
            "It seems that you didn't borrow this book...hence you cannot return it..."
        );

        book.copies++;
        booksBorrowedByAddress[msg.sender][_id] = false;

        if (book.copies > 0) {
            book.available = true;
        }
    }

    //get all books ever borrowed by address
    function getBorrowersLedger(uint256 _id)
        external
        view
        returns (address[] memory)
    {
        return borrowersLedger[_id];
    }

    //get books currently borrowed by address
    function getBooksBorrowedByAddress(address _user, uint256 _id)
        external
        view
        returns (bool)
    {
        return booksBorrowedByAddress[_user][_id];
    }
}