// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;
pragma abicoder v2;
import "@openzeppelin/contracts/access/Ownable.sol";

contract Library is Ownable {

    struct Book {
        uint id;
        string title;
        uint totalCopies;
        uint availableCopies;
        address[] borrowersHistory;
    }

    Book[] public books;
    mapping(string => bool) public existingBooks;
    mapping(uint => mapping(address => bool)) public currentlyBorrowing;

    function addNewBook(string memory bookTitle, uint numberOfCopies) onlyOwner external {
        if (!existingBooks[bookTitle]) {
            Book memory book = Book({
                id: books.length,
                title: bookTitle, 
                totalCopies: numberOfCopies, 
                availableCopies: numberOfCopies,
                borrowersHistory: new address[](0)
            });
            books.push(book);
            existingBooks[bookTitle] = true;
        } else {
            revert("This book already exists in the library.");
        }
    }

    function addCopies(uint id, uint numberOfCopies) onlyOwner external {
        require(existingBooks[books[id].title]);
        books[id].totalCopies += numberOfCopies;
        books[id].availableCopies += numberOfCopies;
    }

    function borrowBook(uint id) external payable {
        bool isAborrower = currentlyBorrowing[id][msg.sender];
        require(!isAborrower, "You already borrow this book");
        require(books[id].availableCopies > 0, "No copies available");
        books[id].availableCopies--;
        books[id].borrowersHistory.push(msg.sender);
        currentlyBorrowing[id][msg.sender] = true;
    }

    function returnBook(uint id) external payable {
        bool isAborrower = currentlyBorrowing[id][msg.sender];
        require(isAborrower, "You have not borrowed this book");
        books[id].availableCopies++; 
        currentlyBorrowing[id][msg.sender] = false;
    }

    function getBorrowersHistory(uint id) public view returns (address[] memory) {
        return books[id].borrowersHistory;
    }

    function getBooksCount() public view returns (uint) {
        return books.length;
    }

    function checkIfCurrentlyBorrowing(uint id, address addr) public view returns (bool isRented) {
        return isRented = currentlyBorrowing[id][addr];    
    }

    function returnBooksArray() public view returns (Book[] memory){
        return books;
    }

}