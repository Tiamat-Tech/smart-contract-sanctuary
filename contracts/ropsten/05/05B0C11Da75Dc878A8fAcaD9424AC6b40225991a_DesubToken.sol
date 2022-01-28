// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol"; 

contract DesubToken {

    using EnumerableSet for EnumerableSet.UintSet;

     // Name and symbol for the Desub content token contract
    string private _name;
    string private _symbol;

    // This is the content price that corresponds to $1 @ 2392 ETH 
    uint256 constant public universalContentPrice = 417965181246200;

    // The owner of the Desub Token Contract
    address public owner;

    // This is the mapping of tokenIDs (content hashes) to owner addresses
    mapping(uint256 => address) private _contentTokenOwners;

    // This maps each address to an enumerable set of the tokenIds owned by that address
    mapping(address => EnumerableSet.UintSet) private _contentTokenHoldings;
    
    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // This maps each tokenID to the current subToken purchase order incrementer
    // Each time a subToken is purchased from a tokenID this value is incremented one
    mapping(uint256 => uint256) private _subTokenIncrementers;

    // This maps each token ID to another mapping of sub token purchase sequences
    // For example if you were the 6th user to purchase a sub token the final value would be 6
    // This also can be used to check if an address owns a sub token of a particular tokenID
    mapping(uint256 => mapping(address => uint256)) private _subTokenPurchaseSequences;

    // This maps each token ID to another mapping of the number of sub token sales an address has referred
    mapping(uint256 => mapping(address => uint256)) private _subTokenReferrals;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenID);

    //initialize the Desub Token Contract
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        owner = msg.sender;
    }

    function _exists(uint256 tokenID) internal view returns (bool) {
        return _contentTokenOwners[tokenID] != address(0);
    }

    function ownerOf(uint256 tokenID) public view returns (address) {
        address tokenOwner = _contentTokenOwners[tokenID];
        require(tokenOwner != address(0), "ERC721: owner query for nonexistent token");
        return tokenOwner;
    }

    function balanceOf(address tokenOwner) public view returns (uint256) {
        require(tokenOwner != address(0), "ERC721: balance query for the zero address");
        return _balances[tokenOwner];
    }

    function tokenOfOwnerByIndex(address tokenOwner, uint256 index) public view returns (uint256) {
        return _contentTokenHoldings[tokenOwner].at(index);
    }

    function numberOfSubTokensIssuedForTokenID(uint256 tokenID) public view returns (uint256) {
        return _subTokenIncrementers[tokenID];
    } 

    function numberOfReferralsForTokenIDandAddress(uint256 tokenID, address referrerAddress) public view returns (uint256){
        return _subTokenReferrals[tokenID][referrerAddress];
    }

    function getSequenceOfPurchaseOfTokenIDByAddress(uint256 tokenID, address purchaserAddress) public view returns (uint256){
        return _subTokenPurchaseSequences[tokenID][purchaserAddress];
    }

    function getNumberOfSubTokensSoldOfTokenID(uint256 tokenID) public view returns (uint256) {
        return _subTokenIncrementers[tokenID];
    }

    function mint(address to, uint256 tokenID) public {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenID), "ERC721: token already minted");

        _contentTokenOwners[tokenID] = to;

        _balances[to] += 1;

        _contentTokenHoldings[to].add(tokenID);

        _subTokenIncrementers[tokenID] = 0;

        emit Transfer(address(0), to, tokenID);
    }

    function purchaseSubToken(address referrer, uint256 tokenID) public payable {
        require(msg.value >= universalContentPrice, "Insufficient funds paid to purchase sub token");
        require(referrer != address(0), "Can't purchase using 0 address as referrer");
        require(_exists(tokenID), "Cannot purchase a non existant tokenID");
        require(_subTokenPurchaseSequences[tokenID][msg.sender] == 0, "Address has already purchased sub token");

        _subTokenIncrementers[tokenID] += 1;

        _subTokenPurchaseSequences[tokenID][msg.sender] = _subTokenIncrementers[tokenID];

        _subTokenReferrals[tokenID][referrer] += 1;

    }

}