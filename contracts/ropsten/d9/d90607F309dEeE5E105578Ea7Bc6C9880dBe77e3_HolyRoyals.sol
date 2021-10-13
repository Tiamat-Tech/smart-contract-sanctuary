// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract HolyRoyals is ERC721, Ownable {
    using Counters for Counters.Counter;
    using Strings for uint256;

    uint256 public cost = 0.2 ether;
    Counters.Counter private _tokenIdCounter;
    bool public paused = false;
    uint256 private _cap = 15000;
    bool public revealed = false;
    uint256 public maxMintAmount = 2;
    string public notRevealedUri;
    string private _currentBaseURI;

    constructor() ERC721("Hollt Royals", "HOLR") {
        setNotRevealedURI('ipfs://QmNXSQPSXkKcyfz1Hv5UfXdnEce8HbPmvRxX9QiKNgaigF/hidden.json');
        setBaseURI("ipfs://QmfQYSR4gTxx7K4ctnfqEXDr3Hkbpd3btqkYrya5APWTvB/");
    }

    function mintableAtOnce() public view returns (uint256) {
      return maxMintAmount;
    }

    function mintingCost() public view returns (uint256) {
      return cost;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _setBaseURI(baseURI);
    }

    function mint(uint256 _mintAmount) public payable {
        uint256 supply = totalSupply();
        require(!paused, 'minting is currently paused.');
        require(_mintAmount > 0, 'Enter the number of token to mint.');
        require(_mintAmount <= maxMintAmount, 'You cannot mint upto that amount of token at once.');
        require(supply + _mintAmount <= _cap, 'insuffient token in reserved for this transaction.');
        require(
            _cap >= _tokenIdCounter.current(),
            "There are no more tokens to mint"
        );

        if (msg.sender != owner()) {
          require(msg.value >= cost * _mintAmount, 'Insuffient amount to buy token');
        }

        for (uint256 i = 1; i <= _mintAmount; i++) {
          _tokenIdCounter.increment();
          _safeMint(msg.sender, _tokenIdCounter.current());
        }
    }

    function pause(bool _state) public onlyOwner {
      paused = _state;
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
      require(
        _exists(tokenId),
        "ERC721Metadata: URI query for nonexistent token"
      );
      
      if(revealed == false) {
          return notRevealedUri;
      }

      string memory currentBaseURI = baseURI();
      return bytes(currentBaseURI).length > 0
          ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), '.json'))
          : "";
    }

    function reveal() public onlyOwner() {
      revealed = true;
    }

    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner() {
      maxMintAmount = _newmaxMintAmount;
    }

    function setCost(uint256 _newCost) public onlyOwner() {
      cost = _newCost;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
      notRevealedUri = _notRevealedURI;
    }

    function withdraw() public payable onlyOwner {
      (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
      require(success);
    }
}