// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract businesstwinCore is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC721Burnable,
    Ownable
{
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    string public collectionName;
    // this contract's token symbol
    string public collectionNameSymbol;

    // define businesstwin struct
    struct Businesstwin {
        uint256 tokenId;
        string tokenName;
        string tokenURI;
        address payable mintedBy;
        address payable currentOwner;
        address payable previousOwner;
        uint256 price;
        uint256 numberOfTransfers;
        bool forSale;
    }

    // map businesstwin token id to businesstwin
    mapping(uint256 => Businesstwin) public businesstwinNFTs;
    // check if token name exists
    mapping(string => bool) public tokenNameExists;
    // check if token URI exists
    mapping(string => bool) public tokenURIExists;

    constructor() ERC721("BusinesstwinNFT", "BusinesstwinNFT") {}

    // mint a new businesstwin
    function mintbusinesstwinNFT(
        string memory _name,
        string memory _tokenURI,
        uint256 _price
    ) public {
        // check if thic fucntion caller is not an zero address account
        require(msg.sender != address(0));

        uint256 currentTokenId = _tokenIdCounter.current();

        // check if a token exists with the above token id => incremented counter
        require(!_exists(currentTokenId));

        // check if the token URI already exists or not
        require(!tokenURIExists[_tokenURI]);
        // check if the token name already exists or not
        require(!tokenNameExists[_name]);

        // mint the token
        _safeMint(msg.sender, currentTokenId);
        // set token URI (bind token id with the passed in token URI)
        _setTokenURI(currentTokenId, _tokenURI);
        _tokenIdCounter.increment();

        // make passed token URI as exists
        tokenURIExists[_tokenURI] = true;
        // make token name passed as exists
        tokenNameExists[_name] = true;

        // creat a new businesstwin (struct) and pass in new values
        Businesstwin memory newbusinesstwin = Businesstwin(
            currentTokenId,
            _name,
            _tokenURI,
            payable(msg.sender),
            payable(msg.sender),
            payable(address(0)),
            _price,
            0,
            true
        );
        // add the token id and it's businesstwin to all businesstwins mapping
        businesstwinNFTs[currentTokenId] = newbusinesstwin;

        emit NFTCreated(msg.sender, currentTokenId);
    }

        // get tokens owned by address
    function getOwnerTokens(address _address)
        public
        view
        returns (uint256[] memory)
    {

        require(balanceOf(_address) > 0);

        uint256[] memory tokens;

        for (uint i = 0; i <= balanceOf(_address) - 1; i++){
            tokens[i] = (tokenOfOwnerByIndex(_address, i));
        }
        return tokens;
    }

    // get token data
    function getTokenData(uint256 _tokenId)
        public
        view
        returns (
            uint256 tokenId,
            string memory tokenName,
            string memory tokenMedata,
            address payable mintedBy,
            address payable currentOwner,
            address payable previousOwner,
            uint256 price,
            uint256 numberOfTransfers,
            bool forSale
        )
    {
        Businesstwin memory tokenData = businesstwinNFTs[_tokenId];
        return (
            tokenData.tokenId,
            tokenData.tokenName,
            tokenData.tokenURI,
            tokenData.mintedBy,
            tokenData.currentOwner,
            tokenData.previousOwner,
            tokenData.price,
            tokenData.numberOfTransfers,
            tokenData.forSale
        );
    }

    function changeTokenPrice(uint256 _tokenId, uint256 _newPrice) public {
        // require caller of the function is not an empty address
        require(msg.sender != address(0));
        // require that token should exist
        require(_exists(_tokenId));
        // check that token's owner should be equal to the caller of the function
        require(ownerOf(_tokenId) == msg.sender);
        // get that token from all businesstwins mapping and create a memory of it defined as (struct => businesstwin)
        Businesstwin memory businesstwin = businesstwinNFTs[_tokenId];
        // update token's price with new price
        businesstwin.price = _newPrice;
        // set and update that token in the mapping
        businesstwinNFTs[_tokenId] = businesstwin;
    }

    // switch between set for sale and set not for sale
    function toggleForSale(uint256 _tokenId) public {
        // require caller of the function is not an empty address
        require(msg.sender != address(0));
        // require that token should exist
        require(_exists(_tokenId));
        // get the token's owner
        address tokenOwner = ownerOf(_tokenId);
        // check that token's owner should be equal to the caller of the function
        require(tokenOwner == msg.sender);
        // get that token from all businesstwins mapping and create a memory of it defined as (struct => businesstwin)
        Businesstwin memory businesstwin = businesstwinNFTs[_tokenId];
        // if token's forSale is false make it true and vice versa
        if (businesstwin.forSale) {
            businesstwin.forSale = false;
        } else {
            businesstwin.forSale = true;
        }
        // set and update that token in the mapping
        businesstwinNFTs[_tokenId] = businesstwin;
    }

    // buy a token by passing in the token's id
    function buyToken(uint256 _tokenId) public payable {
        // check if the function caller is not an zero account address
        require(msg.sender != address(0));
        // check if the token id of the token being bought exists or not
        require(_exists(_tokenId));
        // get the token's owner
        address tokenOwner = ownerOf(_tokenId);
        // token's owner should not be an zero address account
        require(tokenOwner != address(0));
        // the one who wants to buy the token should not be the token's owner
        require(tokenOwner != msg.sender);
        // get that token from all businesstwins mapping and create a memory of it defined as (struct => businesstwin)
        Businesstwin memory businesstwin = businesstwinNFTs[_tokenId];
        // price sent in to buy should be equal to or more than the token's price
        require(msg.value >= businesstwin.price, "low Price");
        // token should be for sale
        require(businesstwin.forSale);
        // transfer the token from owner to the caller of the function (buyer)
        _transfer(tokenOwner, msg.sender, _tokenId);
        // get owner of the token
        // send token's worth of ethers to the owner
        payable(businesstwin.currentOwner).transfer(msg.value);
        // update the token's previous owner
        businesstwin.previousOwner = businesstwin.currentOwner;
        //Converting Address to Address payable
        // update the token's current owner
        businesstwin.currentOwner = payable(msg.sender);
        // update the how many times this token was transfered
        businesstwin.numberOfTransfers += 1;
        // set and update that token in the mapping
        businesstwinNFTs[_tokenId] = businesstwin;

        emit BuySuccess(tokenOwner, msg.sender, _tokenId);
    }

    function updateTokenOwnership(uint256 _tokenId, address _newOwner) public {
        require(_exists(_tokenId));
        Businesstwin memory businesstwin = businesstwinNFTs[_tokenId];
        businesstwin.previousOwner = businesstwin.currentOwner;
        businesstwin.currentOwner = payable(_newOwner);
        businesstwin.numberOfTransfers += 1;
        businesstwinNFTs[_tokenId] = businesstwin;

        emit OwenershipUpdateSuccess(
            businesstwin.previousOwner,
            businesstwin.currentOwner,
            _tokenId
        );
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function changeContractOnwner(address newOwner) public onlyOwner {
        if (newOwner != address(0)) {
            transferOwnership(newOwner);
        }
    }

    // NFTCreated is fired when an auction is created
    event NFTCreated(address _owner, uint256 _tokenId);

    // BuySuccess is fired when an buy is made
    event BuySuccess(address from, address to, uint256 _tokenId);

    // OwenershipUpdateSuccess is fired when nft data is updated
    event OwenershipUpdateSuccess(address from, address to, uint256 _tokenId);
}