// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";

contract BookStore is Ownable{

    // Constants
    string constant private WRONG_ID = "Wrong ID";
    string constant private NO_COPIES = "No copies available";
    string constant private NOT_RENTED = "Book not rented";

    // Variables
    uint32 public bookIds;
    address[] private users;
    mapping (uint32 => Book) private books; // Library
    mapping (string => inStock) private book;
    mapping (address => bool) private existingUser;
    mapping (address => mapping(uint32 => uint32)) private rentedBooks; // ID => COPIES

    // Events
    event bookAdded(string indexed _bookName, uint32 _copies);
    event bookUpdated(string indexed _bookName, uint32 _copies);
    event bookRented(address indexed _rentedBy, string indexed _bookName);
    event bookReturned(address indexed _returnedBy, string indexed _bookName);

    // Structs
    struct inStock {
        bool exists;
        uint32 id;
    }

    struct Book {
        uint32 id;
        uint32 copies;
        string bookName;
    }

    // Functions
    function addBook(string memory _bookName, uint32 _copies) external onlyOwner {
        if (book[_bookName].exists) {
            uint32 id = book[_bookName].id;
            books[id].copies += _copies;
            emit bookUpdated(_bookName, _copies);
        } else {
            uint32 newId = bookIds + 1;
            books[newId] = Book(newId, _copies, _bookName);
            book[_bookName].exists = true;
            book[_bookName].id = newId;
            bookIds++;
            emit bookAdded(_bookName, _copies);
        }
    }

    function rentBook(uint32 _bookId) external {
        address userAddress = msg.sender;
        require(_bookId > 0 && _bookId <= bookIds, WRONG_ID);
        require(books[_bookId].copies > 0, NO_COPIES);

        rentedBooks[userAddress][_bookId]++;
        books[_bookId].copies--;
        if (!existingUser[userAddress]) { // If user rents for a first time.
            users.push(userAddress);
            existingUser[userAddress] = true;
        }
        emit bookRented(userAddress, books[_bookId].bookName);
    }

    function returnBook(uint32 _bookId) external {
        address userAddress = msg.sender;
        require(_bookId > 0 && _bookId <= bookIds, WRONG_ID);
        require(rentedBooks[userAddress][_bookId] > 0, NOT_RENTED);

        rentedBooks[userAddress][_bookId]--;
        books[_bookId].copies++;
        emit bookReturned(userAddress, books[_bookId].bookName);    
    }

    // Gas-free functions:

    function showBooks() external view returns (Book[] memory) {
        Book[] memory results = new Book[](bookIds);
        for (uint32 i=0; i<bookIds; i++) {
            results[i] = books[i+1];
        }
        return results;
    }

    function showUsers() external view returns (address[] memory) {
        return users;
    }
}