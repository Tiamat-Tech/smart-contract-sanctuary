// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Membership is ERC721, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter public _totalSupply;
    string baseURI;
    string public baseExtension = ".json";
    uint256 public constant Max_Supply = 5000;
    uint256 public constant Max_Mint = 10;
    uint256 public Price_Token = 0.04 ether;
    bool public saleIsActive = false;

    constructor(
        string memory _initBaseURI
    )   ERC721("Curated Art", "CA") {
        setBaseURI(_initBaseURI);
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
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
        : "";
    }

    function setBaseURI(string memory baseURI_) public onlyOwner() {
        baseURI = baseURI_;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setSaleState(bool newState) public onlyOwner {
        saleIsActive = newState;
    }
    
    function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
        baseExtension = _newBaseExtension;
  }
    function setCost(uint256 _newCost) public onlyOwner() {
        Price_Token = _newCost;
  }

    function mint(uint256 _mintAmount) public payable {
        uint256 supply = _totalSupply.current() + 1;
        require(saleIsActive);
        require(_mintAmount > 0);
        require(_mintAmount <= 10);
        require(supply + _mintAmount <= Max_Supply);

        if (msg.sender != owner()) {
            require(msg.value >= Price_Token * _mintAmount);
            _totalSupply.increment();
    }

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _totalSupply.increment();
            _safeMint(msg.sender, supply + i);
    }
  }

  function tokensMinted() public view returns (uint256) {
    return _totalSupply.current();
}


    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}