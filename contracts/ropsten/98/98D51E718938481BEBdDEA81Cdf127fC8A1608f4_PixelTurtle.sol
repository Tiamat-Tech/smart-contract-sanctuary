// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract PixelTurtle is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {

    using Strings for uint256;
    using SafeMath for uint256;
    
    uint public price;
    uint public presalePrice;
    address [] public whitelist;
    mapping(address => bool) purchased;
    string [] private URLs;
    string [] private reserved;
    bool public presaleEnabled = false;
    bool public saleEnabled = false;
    uint public counter = 0;
    uint public pcounter = 0;
    uint private currentID = 0;


    address private turtleWallet = 0xA61c620a13eF5C987E9969fD29e2077c10f5da21;
    address private BrkWallet = 0xf60F4Ab1259a3212e1fec485724122636Bce7a99;


    
    constructor() ERC721("PIXEL TURTLE CLUB", "PTC") {}

    function setWhitelist(address[] memory _whitelist) public onlyOwner {
        whitelist = _whitelist;
    }
    
    function setReserved(string[] memory _reserved) public onlyOwner {
        reserved = _reserved;
    }

    function setURLS(string[] memory _URLs) public onlyOwner {
        URLs = _URLs;
    }

    function setPrice(uint _price) public onlyOwner{
        price = _price;
    }
    
    function setPresalePrice(uint _preprice) public onlyOwner{
        presalePrice = _preprice;
    }
    
    function enablePresale(bool sale) public onlyOwner{
        presaleEnabled = sale;
    }

    function enableSale(bool sale) public onlyOwner{
        saleEnabled = sale;
    }
    function _baseURI() internal pure override returns (string memory) {
        return "";
    }

    function safeMint(address to, uint256 tokenId, string memory uri)
        public
        onlyOwner
    {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }
    function reservedMint() public onlyOwner{
        _safeMint(msg.sender, currentID);
        _setTokenURI(currentID, reserved[pcounter]);
        currentID += 1;
        pcounter += 1;
    }
    function presaleMint() public payable{
        require (counter < 500);
        require(msg.value == presalePrice,"You need to pay the appropriate amount");
        require(presaleEnabled == true, "Sale not enabled");
        bool temp = false;
        for (uint i = 0; i< whitelist.length ;i++){
            if (msg.sender == whitelist[i]){
                temp = true;
            }
        }
        require(temp == true, "You are not whitelisted");
        require(purchased[msg.sender] == false, "Already purchased");
        _safeMint(msg.sender, currentID);
        _setTokenURI(currentID, URLs[counter]);
        currentID += 1;
        counter += 1;
        purchased[msg.sender] = true;
        payable(owner()).transfer(msg.value);
    }
    function publicMint(uint amount) public payable{
        require (saleEnabled == true, "Sale not enabled");
        require (msg.value == price * amount, "You need to pay the appropriate amount");
        require (amount <= 3);
        require (URLs.length - counter + 1 >= amount, "Not enough remaining");
        for (uint i = 1; i <= amount; i++){
            _safeMint(msg.sender, currentID);
            _setTokenURI(currentID, URLs[counter]);
            currentID += 1;
            counter += 1;
        }
        payable(owner()).transfer(msg.value);
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
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


    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance!");
        payable(BrkWallet).transfer(balance.div(100).mul(10));
        payable(turtleWallet).transfer(balance.div(100).mul(90));
    }
}