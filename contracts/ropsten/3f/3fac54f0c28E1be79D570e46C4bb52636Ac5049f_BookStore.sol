// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.6;
pragma abicoder v2;

import "./LibraryToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BookStore is Ownable {
    LibraryToken public LIBToken;

    constructor() public {
        LIBToken = new LibraryToken();
    }

    // Constants
    uint constant private BOOK_RENT_PRICE = 100000000000000000;
    string constant private WRONG_ID = "Wrong ID";
    string constant private NOT_RENTED = "Book not rented";
    string constant private NO_COPIES = "No copies available";

    // Variables
    uint[] bookIds;
    mapping (uint => Book) private books; // Library
    mapping (address => mapping(uint => bool)) private existingUser; // Address -> bookId => bool
    mapping (address => mapping(uint => uint)) private rentedBooks; // ID => COPIES

    // Events
    event tokenPurchased(address _buyer, uint _amount);
    event LogETHWrapped(address sender, uint amount);
    event LogETHUnwrapped(address sender, uint amount);
    event bookAdded(string indexed _bookName, string indexed _author, uint _copies);
    event bookUpdated(string indexed _bookName, string indexed _author, uint _copies);
    event bookRented(address indexed _rentedBy, string indexed _author, string indexed _bookName);
    event bookReturned(address indexed _returnedBy, string indexed _author, string indexed _bookName);

    // Structs
    struct Book {
        uint id;
        uint copies;
        uint rentPrice;
        string bookName;
        string author;
        address[] borrowers;
    }

    // Functions
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

    // Gas-free functions:

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

    // WRAPPER FUNCTIONS

    function buyLibToken() public payable {
        require(msg.value > 0, "We need to wrap at least 1 wei");
        LIBToken.mint(msg.sender, msg.value);
        emit LogETHWrapped(msg.sender, msg.value);
    }

    // function unwrap(uint value) public {
    //     require(value > 0, "We need to unwrap st least 1 wei");
    //     LIBToken.transferFrom(msg.sender, address(this), value);
    //     LIBToken.burn(value);
    //     msg.sender.transfer(value);
    //     emit LogETHUnwrapped(msg.sender, value);
    // }

    receive() external payable {
        buyLibToken();
    }

    fallback() external payable {
        buyLibToken();
    }

    // function convertContractLIBToETH(uint _value) external onlyOwner {
    //     wrapper.unwrap(_value);
    // }

}