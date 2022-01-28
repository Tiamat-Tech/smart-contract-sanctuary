// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;
pragma abicoder v2;
import "@openzeppelin/contracts/access/Ownable.sol";

contract Library is Ownable {

    // address public owner;

    // constructor() {
    //     owner = msg.sender;
    // }

    struct Book {
        uint id;
        string title;
        uint totalCopies;
        uint availableCopies;
        address[] currentlyBorrowing;
        address[] borrowersHistory;
    }


    // modifier adminOnly {
    //     require(msg.sender == owner);
    //     _;
    // }

    Book[] public books;

    function addNewBook(string memory bookTitle, uint numberOfCopies) onlyOwner external {
        bool bookExists;

        for(uint i = 0; i < books.length; i++) {
            if (keccak256(abi.encode(bookTitle)) == keccak256(abi.encode(books[i].title))) {
                bookExists = true;
                revert("Book exists");
            }
        }

        if (!bookExists) {
            Book memory book = Book({
                id: books.length,
                title: bookTitle, 
                totalCopies: numberOfCopies, 
                availableCopies: numberOfCopies,
                currentlyBorrowing: new address[](0),
                borrowersHistory: new address[](0)
            });
            books.push(book);
        }
    }

    function addCopies(string memory bookTitle, uint numberOfCopies) onlyOwner external {
        bool bookExists;
        for(uint i = 0; i < books.length; i++) {
            if (keccak256(abi.encode(books[i].title)) == keccak256(abi.encode(bookTitle))) {
                books[i].totalCopies += numberOfCopies;
                books[i].availableCopies += numberOfCopies;
                bookExists = true;
            }
        }
        if (!bookExists) {
            revert("Book does not exist");
        }
    }

    function borrowBook(uint id) external payable {
        (bool isAborrower, ) = checkIfCurrentlyBorrowing(id, msg.sender);
        require(!isAborrower, "You already borrow this book");
        require(books[id].availableCopies > 0, "No copies available");
        books[id].availableCopies--;
        books[id].currentlyBorrowing.push(msg.sender);
        books[id].borrowersHistory.push(msg.sender);
    }

    function returnBook(uint id) external payable {
        (bool isAborrower, uint index) = checkIfCurrentlyBorrowing(id, msg.sender);
        require(isAborrower, "You have not borrowed this book");
        // last borrowing address overwrites the borrower
        // the last address is popped
        books[id].currentlyBorrowing[index] = books[id].currentlyBorrowing[books[id].currentlyBorrowing.length - 1];
        books[id].currentlyBorrowing.pop();
        books[id].availableCopies++;
    }

    function getCurrentlyBorrowingList(uint id) public view returns (address[] memory){
        return books[id].currentlyBorrowing;
    }

    // returns 2 variables
    // 1. bool if address is borrowing     
    // 2. index of the address in the book's currentlyBorrowing array
    function checkIfCurrentlyBorrowing(uint id, address addr) public view returns (bool isBorrowing, uint index) {
        for (uint i = 0; i < books[id].currentlyBorrowing.length; i++) {
            if(books[id].currentlyBorrowing[i] == addr) {
                isBorrowing = true;
                index = i;
            }
        }
        // return (isBorrowing, index);
    }

    function getBorrowersHistory(uint id) public view returns (address[] memory) {
        return books[id].borrowersHistory;
    }

    function getBooksCount() public view returns (uint) {
        return books.length;
    }

}