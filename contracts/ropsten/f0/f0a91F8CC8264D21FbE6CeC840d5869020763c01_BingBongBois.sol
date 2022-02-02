// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "https://github.com/nibbstack/erc721/src/contracts/tokens/nf-token-metadata.sol";
import "https://github.com/nibbstack/erc721/src/contracts/ownership/ownable.sol";

contract BingBongBois is NFTokenMetadata {
    // by default stores all data on blockchain, ...
    // no need to specify storage location

    // constant != immutable
    string displayMessage = "Take me out to dinner, baby.";

    // address of owner, or use type <address>
    // (40 hex char * 4 bits per char) / 8 = 20 bytes
    address public owner;

    // maximum number of tokens, use scientific notation
    uint16 public constant MAX_TOKENS = 1e3;
    uint16 public tokensIssued = 0;
    uint64 public constant TOKEN_PRICE = 0.069420 ether;
    // dynamic 2d array
    uint[10][] array2D;

    // whether sales started
    bool public publicSaleStarted;

    // dynamic address array of payees
    address payable[] payees;

    // rarities
    enum Rarity {Common, Rare, Epic, Legendary}
    Rarity constant defaultRarity = Rarity.Common;

    // user defined type
    // type MyInt is uint256;

    // throw exception for non-owner function calls
    modifier onlyOwner {
        require(
        msg.sender == owner,
        "Only owner can call this function.");
    _;}

    // constructor
    constructor() {
        nftName = "Bing Bong Bois";
        nftSymbol = "BBB";

        // set address that creates contract to be owner
        owner = msg.sender;
        payees.push(payable(owner));

        // initialize state variable
        publicSaleStarted = false;
    }

    /**
    * @dev Mints a new NFT.
    * @param _to The address that will own the minted NFT.
    * @param _tokenId of the NFT to be minted by the msg.sender.
    * @param _uri String representing RFC 3986 URI.
    */
    function mint(
        address _to,
        uint256 _tokenId,
        string calldata _uri
    )
        external
        payable
        onlyOwner
    {
        if (publicSaleStarted && tokensIssued < MAX_TOKENS && msg.value == TOKEN_PRICE) {
            super._mint(_to, _tokenId);
            super._setTokenUri(_tokenId, _uri);
            tokensIssued++;
        } else {
            revert("Failed to mint");
        }
    }

    function addPayee(address payable _newPayee) public onlyOwner {
        // how to check if payee in payee list?
        payees.push(_newPayee);
    }

    function transferOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }

    // distribute contract balance between payees
    function withdraw(uint256 _amount) public onlyOwner {
        // ensure contract balance is enough
        if (_amount > address(this).balance) {return;}

        // equally distribute
        uint256 singleAmount = _amount / payees.length;

        for (uint i = 0; i<payees.length; i++) {
            payees[i].transfer(singleAmount);
        }
    }

    function startPublicSale() public onlyOwner {
        publicSaleStarted = true;
    }

    function getPubliclistSaleStarted() public view returns (bool){
        return publicSaleStarted;
    }

    function endSale() public onlyOwner {
        publicSaleStarted = false;
    }
}