// SPDX-License-Identifier: GPL-3.0-only

/**
    ASpace Apes (ASA) is an exclusive collection of 5,050 NFTs that govern the Aspace decentralized social network, provide travel perks & real-life rewards,
    and produce $AETH for holders in the Aspace Ecosystem.
    Created by the Aspace Development Team. Welcome to the future of decentralized social networks ;-)
    // https://aspaceape.com // https://aspace.app
    Based on generative-art-node, maintained by @HashLips. Thanks for everything, you south-african madman.
        --The AspaceApe development team
*/

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ASpaceApes is ERC721Enumerable, Ownable {
    using Strings for uint256;

    string baseURI;
    string public baseExtension = ".json";
    uint256 public cost = 0.05 ether;
    uint256 public maxSupply = 5050;
    uint256 public maxMintAmount = 20;
    bool public paused = true;
    bool public revealed = false;
    string public notRevealedUri;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI,
        string memory _initNotRevealedUri
    ) ERC721(_name, _symbol) {
        setBaseURI(_initBaseURI);
        setNotRevealedURI(_initNotRevealedUri);
    }

    /* ####### Internals ######## */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }
  
    /* ####### Privates (heh) ######## */
    function isOwner() internal view returns (bool) {
        if(msg.sender == owner()) {
            return true;
        }
        return false;
    }

    /* ####### Publics ######## */
    function mint(uint256 _mintAmount) public payable {
        uint256 supply = totalSupply();
        require(!paused || isOwner() );
        require(_mintAmount > 0);
        require(_mintAmount <= maxMintAmount || isOwner() );
        require(supply + _mintAmount <= maxSupply);

        if (!isOwner()) {
            require(msg.value >= cost * _mintAmount);
        }

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }

    function walletOfOwner(address _owner) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId),"ERC721Metadata: URI query for nonexistent token");
        
        if(!revealed) {
            return notRevealedUri;
        }

        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0
            ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
            : "";
    }

    /* ####### OnlyOwner functions ######## */
    function reveal() public onlyOwner() {
        revealed = true;
    }
  
    function setCost(uint256 _newCost) public onlyOwner() {
        cost = _newCost;
    }

    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner() {
        maxMintAmount = _newmaxMintAmount;
    }
  
    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
        baseExtension = _newBaseExtension;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }
 
    function withdraw() public payable onlyOwner {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success);
    }
}