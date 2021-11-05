//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import './LToken.sol';
import './BookFactory.sol';
import 'hardhat/console.sol';


contract BookLibrary is BookFactory {

    constructor(address _address){
        _token = LToken(_address);
    }

    LToken private _token;

    event BookBorrow(address indexed _address, uint bookId, uint price , string title);
    event BookRetur(address indexed _address, uint bookId, uint price , string title);

    modifier atLeastOneCopy(uint _bookId) {
        //The users should not be able to borrow a book more times than the copies in the libraries unless copy is returned.
        require(books[_bookId].copies > 0, 'Not enough copies');
        _;
    }

    ///@dev Should not spend gas if called from outside
    function addressHasBook(address _address, uint _bookId) public view returns(bool,uint){
        for (uint i=0; i<userBooks[_address].length; i++){
            if (userBooks[_address][i] == _bookId){
                return (true,i);
            }
        }
        return (false,0);
    }

    function _transferFrom(address _from, address _to, uint _ammount) private {
        //console.log("from '%s' to '%s' : BookLibrary contract %s", _from, _to, address(this));
        _token.transferFrom(_from, _to, _ammount);
    }

    function _removeArrayElement(uint[] storage _arr,uint _index) internal {
        _arr[_index] = _arr[_arr.length -1];
        _arr.pop();
    }

    ///@dev Can run into Out-Of-Gas-Exceptions because of _addBookHistory
    function borrowBook(uint _bookId) public atLeastOneCopy(_bookId) {
        bool hasBook;
        uint index;
        (hasBook,index) = addressHasBook(msg.sender, _bookId);
        require(hasBook == false, 'This book is already borrowed');

        _transferFrom(msg.sender, owner(), books[_bookId].price);
        userBooks[msg.sender].push(_bookId);
        books[_bookId].copies --;
        _addBookHistory(msg.sender, _bookId);

        emit BookBorrow(msg.sender, _bookId, books[_bookId].price , books[_bookId].title);
    }

    function returnBook(uint _bookId) public {
        //Users should be able to return books.
        bool hasBook;
        uint index;
        (hasBook,index) = addressHasBook(msg.sender, _bookId);
        require(hasBook == true, 'This book is not borrowed');

        _removeArrayElement(userBooks[msg.sender],index);
        books[_bookId].copies ++;

        emit BookRetur(msg.sender, _bookId, books[_bookId].price , books[_bookId].title);
    }

    function availableBooks() external view returns(uint[] memory){
        //Users should be able to see the available books and borrow them by their id.
        
        //Need to count the length for new idArr
        uint length = 0;
        for (uint i=0; i<books.length; i++){
            if(books[i].copies > 0){
                length++;
            }
        }

        uint[] memory idArr = new uint[](length);
        uint counter = 0;

        //Now assigning to the array
        for (uint i=0; i<books.length; i++){
            if(books[i].copies > 0){
                idArr[counter]=i;
                counter++;
            }
        }

        return idArr;
    }

    function viewBook(uint _bookId) external view returns(Book memory){
        return books[_bookId];
    }

    function bookHistory(uint _bookId) public view returns(address[] memory) {
        //Everyone should be able to see the addresses of all people that have ever borrowed a given book.
        return bookHolderHistory[_bookId];
    }

    ///@dev Can be converted to external view that returns bool and another function (onlyOwner) to simply push()
    function _addBookHistory(address _address, uint _bookId) private {
        // A flag to check if the address is allready in book History
        bool addAddress = true;

        for (uint i=0; i<bookHolderHistory[_bookId].length; i++){
            if (bookHolderHistory[_bookId][i] == _address){
                addAddress = false;
                break;
            }
        }

        if (addAddress){
            bookHolderHistory[_bookId].push(_address);
        }
    }

}