// SPDX-License-Indentifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;
import "@openzeppelin/contracts/access/Ownable.sol";

contract BookLib is Ownable {     //  REMINDER DO NOT USE ARRAYs, care with mapping sync, try to use memory instead of storrage whereven you can, watch transaction expence

    
    mapping(address=>mapping(bytes32=>bool)) public borowedBooks; // addresses of the owners of the books
    mapping(bytes32=>Book) public bytesToBooks;
    
    bytes32[] private availableBooksIds;
    
    struct Book {
        string name;
        uint count;
        address[] borowers;
    }
    
    // only administrator can add books
    function addBook(string calldata _name, uint _count) public onlyOwner {
        address[] memory borrowed;
        bytes32 bookByteId = keccak256(abi.encodePacked(_name));
        bytesToBooks[bookByteId]=Book(_name,_count,borrowed);     // BOOKS name to bytes and use it for ID
        availableBooksIds.push(bookByteId);
    }

    // user can borrow just 1 copy of a book
    function borrowBook(bytes32 _id) public  {
        require(bytesToBooks[_id].count>0 && borowedBooks[msg.sender][_id]==false);
        if(borowedBooks[msg.sender][_id]){
              bytesToBooks[_id].borowers.push(msg.sender);
        }
        bytesToBooks[_id].count--;
        borowedBooks[msg.sender][_id]=true;
    }
    
    // return borrowBook
    function returnBorrowedBook(bytes32 _id) public {
        borowedBooks[msg.sender][_id]=false;
        bytesToBooks[_id].count++;
    }
    
    // show all owners that Borrowed that Book
     function getBorowersBookAddreses(bytes32 _id) public view returns (address[] memory){
        return bytesToBooks[_id].borowers;
    }
    
    // return available books
    function getAvailableBookIds() public view returns (bytes32[] memory bookIDS) {
        bookIDS = availableBooksIds;
    }

}