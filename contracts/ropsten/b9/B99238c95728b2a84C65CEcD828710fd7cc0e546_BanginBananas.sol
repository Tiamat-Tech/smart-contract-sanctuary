//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract BanginBananas is ERC721A, Ownable {
    using Strings for uint256;

    string private baseURI;
    string public baseExtension = ".json";
    string public unrevealdURI;
    uint256 public immutable mintMax = 5;
    uint256 public maxSupply = 7000;
    uint256 public price = 0.05 ether;
    bool public isPresale = true;
    bool public paused = true;
    bool public revealed = false;
    mapping(address => uint256) public presaleList;


    constructor(string memory _name, string memory _symbol, string memory _initBaseURI, string memory _initUnrevealedURI) ERC721A(_name, _symbol){
        setBaseURI(_initBaseURI);
        setUnrevealedURI(_initUnrevealedURI);
    }

    function presaleMint(uint256 _quantity) external payable {
        require(isPresale, "presale not active");
        require(presaleList[msg.sender] > 0, "not eligible for presale");
        require(_quantity > 0, "quantity is zero");
        require(totalSupply() + _quantity <= maxSupply, "reached max supply");
        require(numberMinted(msg.sender) + _quantity <= mintMax, "user reached max number of mints");
        require(price * _quantity == msg.value, "Ether value sent is not correct");
        _safeMint(msg.sender, _quantity);
    }

    function mint(uint256 _quantity) external payable {
        require(!paused, "sale is not live");
        require(_quantity > 0, "quantity is zero");
        require(totalSupply() + _quantity <= maxSupply, "reached max supply");
        require(numberMinted(msg.sender) + _quantity <= mintMax, "user reached max number of mints");
        require(price * _quantity == msg.value, "Ether value sent is not correct");
        _safeMint(msg.sender, _quantity);
    }

    function numberMinted(address _owner) public view returns (uint256) {
        return _numberMinted(_owner);
    }

    function getOwnershipData(uint256 _tokenId) public view returns (TokenOwnership memory) {
        return ownershipOf(_tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
    
        if(revealed == false) {
            return unrevealdURI;
        }

        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0
            ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
            : "";
    }

    //only owner
    function editPresaleList(address[] calldata _addresses) public onlyOwner {
        for(uint256 i=0; i<_addresses.length; i++){
            presaleList[_addresses[i]] = 1;
        }
    }

    function reveal() public onlyOwner() {
        revealed = true;
    }

    function togglePresale(bool _state) public onlyOwner {
        isPresale = _state;
    }  

    function togglePause(bool _state) public onlyOwner {
        paused = _state;
    }

     function withdraw() public onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function setBaseURI(string memory _uri) public onlyOwner {
        baseURI = _uri;
    }

    function setUnrevealedURI(string memory _uri) public onlyOwner {
        unrevealdURI = _uri;
    }
}