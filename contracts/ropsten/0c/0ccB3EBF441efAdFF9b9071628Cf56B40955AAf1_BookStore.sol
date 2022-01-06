// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";

contract BookStore is Ownable{

    uint public bookIds;
    mapping (uint => Book) private books;
    mapping (string => inStock) private book;

       struct inStock {
        bool exists;
        uint id;
    }

    struct Book {
        uint id;
        string bookName;
        uint copies;
    }

    function addBook(string memory _bookName, uint _copies) external onlyOwner {
        if (book[_bookName].exists) {
            uint id = book[_bookName].id;
            books[id].copies += _copies;
        } else {
            uint newId = bookIds + 1;
            books[newId] = Book(newId, _bookName, _copies);
            book[_bookName].exists = true;
            book[_bookName].id = bookIds + 1;
            bookIds++;
        }
    }

        function showBooks() external view returns (Book[] memory) {
        Book[] memory results = new Book[](bookIds);
        for (uint i=0; i<bookIds; i++) {
            results[i] = books[i+1];
        }
        return results;
    }
    
}