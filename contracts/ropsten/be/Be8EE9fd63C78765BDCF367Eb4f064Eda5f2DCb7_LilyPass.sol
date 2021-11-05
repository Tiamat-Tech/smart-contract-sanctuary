// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/*
 _         _              ___                     
( )     _ (_ )           (  _`\                   
| |    (_) | |  _   _    | |_) )  _ _   ___   ___ 
| |  _ | | | | ( ) ( )   | ,__/'/'_` )/',__)/',__)
| |_( )| | | | | (_) |   | |   ( (_| |\__, \\__, \
(____/'(_)(___)`\__, |   (_)   `\__,_)(____/(____/
               ( )_| |                            
               `\___/'                            
*/

contract LilyPass is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    Ownable,
    ReentrancyGuard
{
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    uint256 maxPerTx = 4;
    uint256 public availableSupply = 0;
    uint256 public publicSupply = 190;
    uint256 public maxSupply = 201;
    uint256 private _price = 40_000_000_000_000_000; //0.04 ETH
    address private _owner;
    address private _payee;
    string private _uri;

    // map address to num tokens owned
    mapping(address => uint256) _tokenCount;
    // map tokenId to address of owner
    mapping(uint256 => address) _tokensOwned;
    Counters.Counter private _tokenIdCounter;

    constructor(
        address payee,
        string memory uri
    ) ERC721("LilyPass", "LP") {
        _owner = msg.sender;
        _payee = payee;
        _uri = uri;
    }

    function setPayee(address addr) public onlyOwner {
        _payee = addr;
    } 

    function _baseURI() internal view override returns (string memory) {
        return _uri;
    }

    function setBaseURI(string memory uri) public onlyOwner {
        _uri = uri;
    }

    // @dev surface cost to mint
    function price() public view returns (uint256) {
        return _price;
    }

    // @dev add amount to current available supply
    function setAvailable(uint256 amount) public onlyOwner {
        require(availableSupply.add(amount) < maxSupply, "exceeds public supply");
        availableSupply = availableSupply.add(amount);
    }

    // @dev change cost to mint protects against price movement
    function setPrice(uint256 amount) public onlyOwner {
        _price = amount;
    }

    function tokenCount(address addr) public view returns (uint256) {
        return _tokenCount[addr];
    }

    // @dev website mint function
    function mint(uint256 num) public payable nonReentrant {
        require(
            totalSupply().add(num) <= availableSupply,
            "no availability"
        );
        require(
            totalSupply().add(num) <= publicSupply,
            "resource exhausted"
        );
        require(num <= maxPerTx, "request limit exceeded");
        require(price().mul(num) <= msg.value, "not enough funds");
        require(_tokenCount[msg.sender] < 5, "token max reached");
        require(_tokenCount[msg.sender].add(num) < 5, "exceeds token limit");

        for (uint256 i = 0; i < num; i++) {
            _safeMint(msg.sender, _tokenIdCounter.current());
            super._setTokenURI(_tokenIdCounter.current(), _uri);
            _tokensOwned[_tokenIdCounter.current()] = msg.sender;
            _tokenIdCounter.increment();
            _tokenCount[msg.sender] += 1;
        }
    }

    // @dev owner can safely mint
    function safeMint(address to, uint256 num) public onlyOwner nonReentrant {
        require(
            totalSupply().add(num) <= availableSupply,
            "no availability"
        );
        require(
            totalSupply().add(num) <= maxSupply,
            "resource exhausted"
        );
        _safeMint(to, _tokenIdCounter.current());
        super._setTokenURI(_tokenIdCounter.current(), _uri);
        _tokenIdCounter.increment();
    }
    // @dev withdraw funds
    function withdraw() public onlyOwner {
        (bool success, ) = _payee.call{value: address(this).balance}("");
        require(success, "tx failed");
    }
    // The following functions are overrides required by Solidity.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
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
        _tokenCount[msg.sender] = _tokenCount[msg.sender].sub(1);
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
}