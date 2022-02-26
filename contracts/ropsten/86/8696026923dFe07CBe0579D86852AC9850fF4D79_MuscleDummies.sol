// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MuscleDummies is ERC721Enumerable, Ownable {
  using Strings for uint256;

  string public baseURI;
  string public notRevealedUri;
  string public baseExtension = ".json";

  uint256 public cost = 0.15 ether;
  uint256 public maxSupply = 30;
  uint256 public maxMintAmount = 10;

  bool public paused = false;
  bool public revealed = false;

  constructor(
    string memory _initBaseURI,
    string memory _initNotRevealedUri
  ) ERC721("Muscle Dummies", "MD") {
    setBaseURI(_initBaseURI);
    setNotRevealedURI(_initNotRevealedUri);
  }

  // ========================= PUBLIC =========================
    function mintUser(uint256 _mintAmount) public payable {
      require(!paused, "We are not currently minting!"); //MAKE sure sales have not been paused
      require(_mintAmount > 0, "Please select how many you would like to mint");

      uint256 supply = totalSupply(); //GET total amount already minted
      require(supply < maxSupply, "We are all out of Muscle Dummies!");
      require(supply + _mintAmount <= maxSupply, "We do not have this many Muscle Dummies left!");

      //MAKE sure they have the funds and not the max amount of dummies
      if(msg.sender != owner()) {
        require(_mintAmount <= maxMintAmount, "You cannot mint this many Muscle Dummies.");
        require(msg.value >= cost * _mintAmount);
      }

      for (uint256 i = 1; i <= _mintAmount; i++) {
        //MAKE sure token has not been minted already
        uint256 toMint = 1;
        while(_exists(toMint)){
          toMint += 1;
        }
        _safeMint(msg.sender, toMint);
      }
    }

    function walletOfOwner(address _owner)
      public
      view
      returns (uint256[] memory)
    {
      uint256 ownerTokenCount = balanceOf(_owner);
      uint256[] memory tokenIds = new uint256[](ownerTokenCount);
      for (uint256 i; i < ownerTokenCount; i++) {
        tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
      }
      return tokenIds;
    }

    function tokenURI(uint256 tokenId)
      public
      view
      virtual
      override
      returns (string memory)
    {
      require(
        _exists(tokenId),
        "ERC721Metadata: URI query for nonexistent token"
      );
      
      string memory currentBaseURI = _baseURI();

      if(revealed == false) {
          return bytes(currentBaseURI).length > 0
              ? string(abi.encodePacked(notRevealedUri, tokenId.toString(), baseExtension))
              : "";
      }

      return bytes(currentBaseURI).length > 0
          ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
          : "";
    }

  // ========================= OWNER FUNCTIONS =========================
    function mintGift(address _to, uint256 tokenId) public payable onlyOwner{
      require(!_exists(tokenId), "Token has already been minted");
      require(tokenId <= maxSupply, "Token is out of range");
      _safeMint(_to, tokenId);
    }

    function reveal() public onlyOwner {
      revealed = true;
    }

    function setCost(uint256 _newCost) public onlyOwner {
      cost = _newCost;
    }

    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
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
      // =============================================================================
      (bool os, ) = payable(owner()).call{value: address(this).balance}("");
      require(os);
      // =============================================================================
    }
  

  // ========================= INTERNAL FUNCTIONS =========================
    function _baseURI() internal view virtual override returns (string memory) {
      return baseURI;
    }
}