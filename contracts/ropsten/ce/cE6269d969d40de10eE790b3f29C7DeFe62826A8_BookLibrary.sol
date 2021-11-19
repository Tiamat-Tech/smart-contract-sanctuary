// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./BookLibraryBase.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract BookLibrary is BookLibraryBase {
    using SafeMath for uint256;
    using ECDSA for bytes32;

    constructor(BookLibraryToken tokens) {
        _tokens = tokens;
    }

    function addNewBook(
        string calldata name,
        string calldata author,
        uint8 copies
    ) external
      onlyOwner
      onlyPositiveCopies(copies)
    {
        require(
            bytes(name).length != 0 && bytes(author).length != 0,
            "Book name and author should not be empty!"
        );
        uint bookId = getBookUniqueIdentifier(name, author);
        require(!bookExists(bookId),"Book already exists!");
        createBook(bookId, name, author, copies);
        _currentlyAvailableBooks++;
        emit NewBookAdded(bookId, name, author, copies);
    }

    function addAvailableCopies(
        uint bookId,
        uint8 copies
    ) external
      onlyOwner
      onlyExistingBook(bookId)
      onlyPositiveCopies(copies)
    {
        increaseAvailableCopies(bookId, copies);
    }

    function borrowBook(uint bookId)
      external
    {
        processBorrowRequest(bookId, msg.sender);
    }

    function borrowBookWithSignature(
        uint bookId,
        address borrower,
        bytes calldata signature
    ) external
    {
        require(
            !_submittedSignatures[signature],
            "Signature can only be used once!"
        );
        address signer = keccak256(abi.encodePacked(bookId))
            .toEthSignedMessageHash()
            .recover(signature);
        require(borrower == signer, "Invalid signature!");
        processBorrowRequest(bookId, borrower);
        _submittedSignatures[signature] = true;
    }

    function returnBook(uint bookId)
      external
      onlyExistingBook(bookId)
      currentlyBorrowedBook(bookId, msg.sender, true)
    {
        increaseAvailableCopies(bookId, 1);
        updateBorrowerStatus(bookId, msg.sender, BorrowStatus.Returned);
    }

    function getAvailableBooks()
      external
      view
      returns(uint[] memory)
    {
        uint[] memory availableBooks = new uint[](_currentlyAvailableBooks);
        uint counter = 0;
        for (uint i = 0; i < _bookIds.length; i++) {
            uint currentBookId = _bookIds[i];
            if (bookHasAvailableCopies(currentBookId)) {
                availableBooks[counter] = currentBookId;
                counter++;
            }
        }
        return availableBooks;
    }

    function getBookBorrowersList(uint bookId)
      external
      view
      onlyExistingBook(bookId)
      returns(address[] memory)
    {
        return _books[bookId].borrowerIds;
    }

    function createBook(
        uint bookId,
        string calldata name,
        string calldata author,
        uint8 copies
    ) private
    {
        Book storage book = _books[bookId];
        book.name = name;
        book.author = author;
        book.availableCopies = copies;
        _bookIds.push(bookId);
    }

    function processBorrowRequest(
        uint bookId,
        address borrower
    ) private
      onlyExistingBook(bookId)
      currentlyBorrowedBook(bookId, borrower, false)
    {
        require(
            bookHasAvailableCopies(bookId),
            "Book is currently out of stock!"
        );
        //todo fee should be 0.1 BIT. research math in solidity (decimals, precision)
        uint256 fee = 1;
        _tokens.burn(borrower, fee);
        decreaseAvailableCopies(bookId);
        updateBorrowerStatus(bookId, borrower, BorrowStatus.Borrowed);
    }

    function increaseAvailableCopies(
        uint bookId,
        uint8 copies
    ) private
    {
        Book storage book = _books[bookId];
        if (!bookHasAvailableCopies(bookId)) {
            _currentlyAvailableBooks++;
            emit BookBackInStock(bookId, book.name, book.author);
        }
        book.availableCopies += copies;
    }

    function decreaseAvailableCopies(uint bookId)
      private
    {
        Book storage book = _books[bookId];
        book.availableCopies--;
        if (!bookHasAvailableCopies(bookId)) {
            _currentlyAvailableBooks--;
            emit BookOutOfStock(bookId, book.name, book.author);
        }
    }

    function updateBorrowerStatus(
        uint bookId,
        address borrower,
        BorrowStatus status
    ) private
    {
        Book storage book = _books[bookId];
        if (status == BorrowStatus.Borrowed &&
            book.borrowers[borrower] == BorrowStatus.NeverBorrowed)
        {
            book.borrowerIds.push(borrower);
        }
        book.borrowers[borrower] = status;
    }
}