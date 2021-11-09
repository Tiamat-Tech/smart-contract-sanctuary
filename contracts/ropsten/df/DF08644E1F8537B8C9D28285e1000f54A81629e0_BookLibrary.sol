//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./LToken.sol";
import "./BookFactory.sol";
import "hardhat/console.sol";

contract BookLibrary is BookFactory {
    constructor(address _address) {
        _token = LToken(_address);
    }

    LToken private _token;

    event BookBorrow(
        address indexed _address,
        uint256 bookId,
        uint256 price,
        string title
    );
    event BookRetur(
        address indexed _address,
        uint256 bookId,
        uint256 price,
        string title
    );

    modifier atLeastOneCopy(uint256 _bookId) {
        //The users should not be able to borrow a book more times than the copies in the libraries unless copy is returned.
        require(books[_bookId].copies > 0, "Not enough copies");
        _;
    }

    ///@dev Should not spend gas if called from outside
    function addressHasBook(address _address, uint256 _bookId)
        public
        view
        returns (bool, uint256)
    {
        for (uint256 i = 0; i < userBooks[_address].length; i++) {
            if (userBooks[_address][i] == _bookId) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    function _transferFrom(
        address _from,
        address _to,
        uint256 _ammount
    ) private {
        console.log(
            "from '%s' to '%s' : BookLibrary contract %s",
            _from,
            _to,
            address(this)
        );

        _token.transferFrom(_from, _to, _ammount);
    }

    function _removeArrayElement(uint256[] storage _arr, uint256 _index)
        internal
    {
        _arr[_index] = _arr[_arr.length - 1];
        _arr.pop();
    }

    ///@dev Can run into Out-Of-Gas-Exceptions because of _addBookHistory
    function borrowBook(
        uint256 _bookId,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public atLeastOneCopy(_bookId) {
        bool hasBook;
        uint256 index;
        (hasBook, index) = addressHasBook(msg.sender, _bookId);
        require(hasBook == false, "This book is already borrowed");

        // require(_token.allowance(msg.sender, address(this)) >= books[_bookId].price, "Token allowance too low");
        _token.permit(msg.sender, address(this), value, deadline, v, r, s);
        _transferFrom(msg.sender, owner(), value);
        userBooks[msg.sender].push(_bookId);
        books[_bookId].copies--;
        _addBookHistory(msg.sender, _bookId);

        emit BookBorrow(
            msg.sender,
            _bookId,
            books[_bookId].price,
            books[_bookId].title
        );
    }

    function returnBook(uint256 _bookId) public {
        //Users should be able to return books.
        bool hasBook;
        uint256 index;
        (hasBook, index) = addressHasBook(msg.sender, _bookId);
        require(hasBook == true, "This book is not borrowed");

        _removeArrayElement(userBooks[msg.sender], index);
        books[_bookId].copies++;

        emit BookRetur(
            msg.sender,
            _bookId,
            books[_bookId].price,
            books[_bookId].title
        );
    }

    function availableBooks() external view returns (uint256[] memory) {
        //Users should be able to see the available books and borrow them by their id.

        //Need to count the length for new idArr
        uint256 length = 0;
        for (uint256 i = 0; i < books.length; i++) {
            if (books[i].copies > 0) {
                length++;
            }
        }

        uint256[] memory idArr = new uint256[](length);
        uint256 counter = 0;

        //Now assigning to the array
        for (uint256 i = 0; i < books.length; i++) {
            if (books[i].copies > 0) {
                idArr[counter] = i;
                counter++;
            }
        }

        return idArr;
    }

    function viewBook(uint256 _bookId) external view returns (Book memory) {
        return books[_bookId];
    }

    function bookHistory(uint256 _bookId)
        public
        view
        returns (address[] memory)
    {
        //Everyone should be able to see the addresses of all people that have ever borrowed a given book.
        return bookHolderHistory[_bookId];
    }

    ///@dev Can be converted to external view that returns bool and another function (onlyOwner) to simply push()
    function _addBookHistory(address _address, uint256 _bookId) private {
        // A flag to check if the address is allready in book History
        bool addAddress = true;

        for (uint256 i = 0; i < bookHolderHistory[_bookId].length; i++) {
            if (bookHolderHistory[_bookId][i] == _address) {
                addAddress = false;
                break;
            }
        }

        if (addAddress) {
            bookHolderHistory[_bookId].push(_address);
        }
    }

    function testPermit()
        public
        returns (
            uint256 value,
            uint256 deadline,
            uint8 v,
            bytes32 r,
            bytes32 s
        )
    {
        _token.permit(msg.sender, address(this), value, deadline, v, r, s);
        uint256 allowed = _token.allowance(msg.sender, address(this));
        console.log("allowed '%s' tokens", allowed);
    }

    function recoverSigner(
        bytes32 hashedMessage,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public view returns (address) {
        bytes32 messageDigest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hashedMessage)
        );
        address _address = ecrecover(messageDigest, v, r, s);
        console.log(_address);
        return _address;
    }
}