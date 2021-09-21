// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SpatioveryGenX is ERC721, ReentrancyGuard, Ownable
{
    uint constant MAX_SHIPS = 500;
    uint constant PRICE = 0.02 ether;
    uint constant MAX_MINT_PER_WALLET = 5;
    uint256 tokenCounter = 0;
    string private baseTokenURI = "https://ipfs.io/ipfs/QmYVtYM7jdGoVuZ4uhNKgPa5S6BRVKgXhACaeEnsGaQ2UF/";

    bool private _presaleActive = false;
    bool private _publicsaleActive = false;

    constructor() ERC721("SpatioveryGenX", "STGX"){}

    address private _governor_address = 0xf4fc60922Bea79308Cb7f73c4338ca764ECFD07B;

    mapping (address => uint) private _mintedShipsCount;
    mapping (address => bool) private _isPresaleAddress;
    mapping (uint256 => string) private _tokenURIs;

    function addPresaler(address _addr) external onlyOwner
    {
        _isPresaleAddress[_addr] = true;
    }

    function togglePresale() external onlyOwner
    {
        _presaleActive = !_presaleActive;
    }

    function togglePublicSale() external onlyOwner
    {
        _publicsaleActive = !_publicsaleActive;
    }

    function buildSpaceship() internal
    {
        uint256 newID = tokenCounter;
        _safeMint(msg.sender, newID);
        _setTokenURI(newID, string(abi.encodePacked(baseTokenURI, uint2str(newID), ".json")));
        tokenCounter++;
    }

    function mint(uint numberToMint) external payable
    {
        
        require(msg.value == PRICE * numberToMint, "Price is incorrect for the number of ships to mint");
        require(tokenCounter < MAX_SHIPS, "No more ships are available to mint");
        require(_mintedShipsCount[msg.sender] < MAX_MINT_PER_WALLET, "Max amount of ships Minted on this wallet already");
        require(_publicsaleActive, "Public minting isn't activated yet");
        buildSpaceship();
    }

    function presaleMint(uint numberToMint) external payable
    {
        
        require(msg.value == PRICE * numberToMint, "Price is incorrect for the number of ships to mint");
        require(tokenCounter < MAX_SHIPS, "No more ships are available to mint");
        require(_mintedShipsCount[msg.sender] < MAX_MINT_PER_WALLET, "Max amount of ships Minted on this wallet already");
        require(_presaleActive, "Presale minting isn't activated yet");
        buildSpaceship();
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal onlyOwner {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function withdraw() external onlyOwner
    {
        payable(_governor_address).transfer(address(this).balance);
    }

    function uint2str(uint _i) internal pure returns (string memory _uintAsString) 
    {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}