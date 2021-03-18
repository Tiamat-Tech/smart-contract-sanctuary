//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./AutographContract.sol";

import "hardhat/console.sol";

// TODO: Implement fees !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// TODO: Implement pending requests count !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

contract AutographRequestContract is Ownable {

    struct Request {
        address from;
        address to;
        uint price;
        uint responseTime;
        uint created;
    }

    AutographContract private autographContract;
    Request[] private requests;

    // Events
    event RequestCreated(uint id, address indexed from, address indexed to, uint price, uint responseTime, uint created);
    event RequestDeleted(uint id, address indexed from, address indexed to, uint price, uint responseTime, uint created);
    event RequestSigned(uint id, address indexed from, address indexed to, uint price, uint responseTime, uint created, string nftHash, string metadata);

    /**
     * Contract constructor.
     * - _autographContract: NFT Token address.
     */
    // TODO: Ownable methods!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    constructor(address _autographContract) {
        autographContract = AutographContract(_autographContract);
    }

    /**
     * Function used to request a new NFT (autograph) to a celeb.
     * - to: Celeb address or recipient.
     * - responseTime: Request response time.
     */
    function createRequest(address to, uint responseTime) public payable {     
        // TODO: 'to' address must be a valid address !!!!!!!!!!!!!!!!!!!!!!!!!  
        // TODO: validar siempre que las direcciones paradas son válidas (require(owner != address(0)) !!!!!!!!!!!!!!!!!!
        Request memory newRequest = Request(msg.sender, to, msg.value, responseTime, block.timestamp);
        requests.push(newRequest);
        uint id = requests.length - 1;

        emit RequestCreated(id, newRequest.from, newRequest.to, newRequest.price, newRequest.responseTime, newRequest.created);
    }

    /**
     * Method used to remove a request after the locking period expired.
     * - id: Request index.
     * - responseTime: Request response time. 
     */
    function deleteRequest(uint id, uint responseTime) public {
        Request memory request = requests[id];
        
        require(request.from == msg.sender, 'You are not the owner of the request');
        require(request.responseTime == responseTime, 'Response time do not match with this request');
        require(block.timestamp >= request.created + (request.responseTime * 1 days), 'You must wait the response time to delete this request');

        // Transfering amount payed to user
        payable(msg.sender).transfer(request.price);
        delete requests[id];
        // TODO: Item was removed successfully!!!!!!!!!!!!!!!!!!!!!!!!

        emit RequestDeleted(id, request.from, request.to, request.price, request.responseTime, request.created);
    }

    /**
     * Method used to sign a pending request.
     */
    function signRequest(uint id, uint price, string memory nftHash, string memory metadata) public {
        Request memory request = requests[id];

        // TODO: Check if request exists !!!!!!!!!!!!!!!!!!!!!!!!
        require(request.to == msg.sender, 'You are not the recipient of the request');
        require(request.price == price, 'This price do not match with this request');
        require(address(this).balance >= request.price, 'Balance should be greater than request price');

        // Minting the NFT
        autographContract.mint(request.from, nftHash, metadata);
        // TODO: Check if token was already minted !!!!!!!!!!!!!!!!!!!!!!!!!!!!

        // Adding request price to celeb balance
        address payable addr = payable(request.to);
        addr.transfer(request.price);

        // TODO: Marcar de alguna manera la request como firmada (eliminar?)

        emit RequestSigned(id, request.from, request.to, request.price, request.responseTime, request.created, nftHash, metadata);
    }

    /**
     * Method used to return the contract balance.
     */
    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    // TODO: Function to change contract owner
    // TODO: Qué funciones deben ser ownables??
    // TODO: How to implement upgradeable contract?

}