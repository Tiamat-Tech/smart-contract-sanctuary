//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract FLUTTER is ERC721, ERC721Enumerable, ERC721URIStorage {
    
    address payable public _originalowner;
    address payable public _royaltyreceiver; //add this to all contracts
    address payable public _jelly;

    bool public _saleRunning;
    mapping(uint => NFT_Metadata) public nft_metadata;

    mapping(uint => uint) public resaleTokenIndex;
    mapping(uint => uint) public resaleTokenByIndex;
    uint[] public resaleToken;

    struct NFT_Metadata {
        uint price;
        bool forSale;
    }

    /*
     * constructor, initializing variables
     */
    constructor() ERC721("FLUTTER", "FLT") {

    _originalowner = payable(address(0x77a06Af353bA3d792c1f704601c3440160e741d1)); //enter name of client here to clarify
    _royaltyreceiver = payable(address(0x77a06Af353bA3d792c1f704601c3440160e741d1)); //enter name of client here to clarify
    _jelly = payable(address(0xBFb977f7D14BbA00D014d33698E0B49208de2A7e)); //address of jelly

    }

    /*
     * _; means that if the owner calls this function, the
     * function is executed and otherwise, an exception is thrown.
     */
    modifier onlyOwner {
        require(msg.sender == _originalowner,"only _originalowner can call this function");
        _;

    }

    /**
     * See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);

    }

    /*
     * overrides _baseURI function of parent to return baseURI variable set in constructor
     */
    function _baseURI() internal view override returns (string memory) {
        return super._baseURI(); //before was accessing my custom baseURI variable...

    }

    /*
     * mints 'tokenId' and transfers it to the account of _originalowner
     * stores corresponding ipfs and on-chain metadata
     * returns 'tokenId' to enable minter to store file on IPFS with 'tokenId' as name
     */
    function mintClientOwn(string memory _tokenURI) external onlyOwner returns (uint createdtokenId) {
        require(totalSupply()<1000, "too many tokens have been minted, the limit is set at 1000");
        uint tokenId = totalSupply()+1;
        _mint(_originalowner, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        nft_metadata[tokenId] = NFT_Metadata(0, false);
        return tokenId;

    }

    /*
     * allows client to set a price of 'tokenId'
     * puts 'tokenId' up for Sale
     */
    function setPriceAndSell(uint tokenId, uint price) external onlyOwner {
        require(msg.sender == ownerOf(tokenId), "Non-Owner trying to set price");
        require(price > 0, "Price can't be 0");
        nft_metadata[tokenId].price = price;
        nft_metadata[tokenId].forSale = true;

    }

    /*
     * allows buyers to set a (new) price of 'tokenId'
     * puts 'tokenId' up for Sale again
     */
    function setPriceAndSellMarket(uint tokenId, uint price) external {
        require(msg.sender == ownerOf(tokenId), "Non-Owner trying to set price");
        require(price > 0, "Price can't be 0");
        nft_metadata[tokenId].price = price;
        nft_metadata[tokenId].forSale = true;

        resaleTokenIndex[tokenId] = resaleToken.length;
        resaleTokenByIndex[resaleToken.length] = tokenId;
        resaleToken.push(tokenId);

    }

    /*
     * allows client to revoke a token that they put on sale
     */
    function revokeToken(uint tokenId) external onlyOwner {
        require(msg.sender == ownerOf(tokenId), "Non-Owner trying to set price");
        require(nft_metadata[tokenId].forSale == true, "This token is currently not set for sale");
        require(_saleRunning == false, "can't revoke a token while a sale is active");

        nft_metadata[tokenId].price = 0;
        nft_metadata[tokenId].forSale = false;

    }

    /*
     * allows buyers to revoke a token that they put on sale
     */
    function revokeTokenMarket(uint tokenId) external {
        require(msg.sender != _originalowner, "only buyers can use Market-functions");
        require(msg.sender == ownerOf(tokenId), "Non-Owner trying to set price");
        require(nft_metadata[tokenId].forSale == true, "This token is currently not set for sale");

        nft_metadata[tokenId].price = 0;
        nft_metadata[tokenId].forSale = false;
        
        _removeFromEnumeration(tokenId);

    }

    /*
     * allows to start or stop a sale;
     * stop will be called automatically once client wants to set a token forSale 
     * while _saleRunning is true, and there are no token for Sale anymore
     */
    function startOrStopSale(bool newVal) onlyOwner public {
        _saleRunning = newVal;

    }

    /*
     * takes payment from buyer, distributes it, and calls the transfer function
     * sends 80% of ether to _originalowner (client), 20% to _jelly (us)
     */
    function initAcceptPayment(uint tokenId) external payable {
        require(_saleRunning == true, "There is currently no active sale");
        require(_originalowner == ownerOf(tokenId), "This function may only be called for initial transfers");
        require(nft_metadata[tokenId].forSale == true, "This token is currently not on sale");
        require(msg.value == nft_metadata[tokenId].price, "Payment-Amount is wrong");
        _originalowner.transfer(msg.value * 80/100);
        _jelly.transfer(msg.value * 20/100);

        _transfer(_originalowner, payable(msg.sender), tokenId);
        nft_metadata[tokenId].forSale = false;

    }

    /*
     * takes payment from buyer, distributes it, and calls the transfer function
     * sends 90% of ether to former owner, 3% to originalowner (us), 7% to client
     */
    function regAcceptPayment(uint tokenId) external payable {
        require(_originalowner != ownerOf(tokenId), "This function may only be called for regular transfers");
        require(msg.value == nft_metadata[tokenId].price, "Payment-Amount is wrong");
        require(nft_metadata[tokenId].forSale == true, "This Token is not for sale");
        address payable _owner = payable(ownerOf(tokenId));
        _owner.transfer(msg.value * 90/100);
        _originalowner.transfer(msg.value * 7/100);
        _jelly.transfer(msg.value * 3/100);
        
        _transfer(_owner, payable(msg.sender), tokenId);
        nft_metadata[tokenId].forSale = false;

        _removeFromEnumeration(tokenId);

    }

    /*
     * returns total amount of token currently listed on the marketplace
     */
    function balanceMarketPlace() external view returns(uint256 length) {
        return resaleToken.length;

    }

    /*
     * removes a token that was listed on the marketplace from all enumerations
     * see @openzeppelin docs for insights on the pattern used
     */
    function _removeFromEnumeration(uint256 tokenId) internal {
        uint256 lastTokenIndex = resaleToken.length - 1;
        uint256 tokenIndex = resaleTokenIndex[tokenId];

        // using swap&pop pattern as in openZeppelin library
        uint256 lastTokenId = resaleToken[lastTokenIndex];
        resaleToken[tokenIndex] = lastTokenId;
        resaleToken[lastTokenIndex] = tokenId;
        resaleTokenIndex[lastTokenId] = tokenIndex;
        resaleTokenIndex[tokenId] = lastTokenIndex;

        delete resaleTokenByIndex[resaleTokenIndex[tokenId]];
        delete resaleTokenIndex[tokenId];
        resaleToken.pop();

    }

    /*
     * removes token 'tokenId' from all relevant enumerations
     */
    function _beforeTokenTransfer(address from, address to, uint tokenId) internal override (ERC721Enumerable, ERC721) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /*
     * burns token as per IERC-721 specification
     */
    function _burn(uint tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);

    }

    /*
     * returns bytes required for safeTransfer
     */
    function supportsInterface(bytes4 interfaceId) public view override (ERC721, ERC721Enumerable) returns (bool) {
        return 
            interfaceId == type(IERC721Enumerable).interfaceId || 
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

}