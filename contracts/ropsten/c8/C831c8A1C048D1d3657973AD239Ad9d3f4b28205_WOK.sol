// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WOK is ERC721Enumerable, Ownable {
  using Strings for uint256;

  string public baseURI;
  string public baseExtension = ".json";
  uint256 public cost = 0.05 ether;
  uint256 public maxSupply = 8888;
  uint256 public maxMintAmount = 10;
  bool public publicsaleonly = false;
  string public notRevealedUrl;
  bool public revealed = false;
  
  //pre sale only
  bool public presaleonly = false; 
  mapping(address => uint8) private _whitelisted;
  
 constructor(
  ) ERC721("WOK", "WOK") {
}


  // internal
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  // public
  function premint(uint256 _mintAmount) public payable {
	uint256 supply = totalSupply();
	require(presaleonly, "Presale is not live.");
	require(_mintAmount > 0, "Minimum to mint is 1.");
	require(_mintAmount <= maxMintAmount,"Not allow over maximum mint to purchased.");
	require(supply + _mintAmount <= maxSupply, "Sold out!");
	require(msg.value >= cost * _mintAmount, "Wrong ether value.");

	uint senderBalance = balanceOf(msg.sender);
    require(_mintAmount <= _whitelisted[msg.sender] - senderBalance, "Exceeded max available to purchase");
	
	for (uint256 i = 1; i <= _mintAmount; i++) {
	  _safeMint(msg.sender, supply + i);
	}
  }
  
  function mint(uint256 _mintAmount) public payable {
    uint256 supply = totalSupply();
    require(publicsaleonly, "Public sale is not live.");
    require(_mintAmount > 0, "Minimum to mint is 1.");
    require(_mintAmount <= maxMintAmount,"Not allow over maximum mint to purchased.");
    require(supply + _mintAmount <= maxSupply, "Sold out!");
	
	//validate mint amount
    require(msg.value >= cost * _mintAmount, "Wrong mint price.");
	
    for (uint256 i = 1; i <= _mintAmount; i++) {
      _safeMint(msg.sender, supply + i);
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

    if (!revealed) {
      return notRevealedUrl;
    } else {
    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
        : "";
	}
  }

  //only owner
  function setCost(uint256 _newCost) public onlyOwner {
    cost = _newCost;
  }

  function setmaxPerMint(uint256 _newmaxPerMint) public onlyOwner {
    maxMintAmount = _newmaxPerMint;
  }

  function setMaxSupply(uint256 _newmaxSupply) public onlyOwner {
    maxSupply = _newmaxSupply;
  }
  
  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;
  }

  function setNotRevealedUrl(string memory _setNotRevealedUrl) public onlyOwner {
    notRevealedUrl = _setNotRevealedUrl;
  }
  
  function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
    baseExtension = _newBaseExtension;
  }

  function PreSaleEnabled(bool _state) public onlyOwner {
    presaleonly = _state;
  }

  function PublicSaleEnabled(bool _state) public onlyOwner {
    publicsaleonly = _state;
  }

  function RevealEnabled(bool _state) public onlyOwner {
    revealed = _state;
  }
  
  function setWhitelistedList(address[] calldata useraddress, uint8 numAllowedToMint) public onlyOwner {
		for (uint256 i = 0; i < useraddress.length; i++) {
			_whitelisted[useraddress[i]] = numAllowedToMint;
		}
  }

  function Reserved(uint256 _mintAmount) public onlyOwner {
	uint256 supply = totalSupply();
	require(supply + _mintAmount <= maxSupply, "Sold out!");
	
	//claim 50 at a time.
	require(_mintAmount <= 50, "Too many requested");
	
    for (uint256 i = 1; i <= _mintAmount; i++) {
      _safeMint(msg.sender, supply + i);
    }
	
  }
  //checking
  function withdraw() public payable onlyOwner {
    (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
    require(success);
  }
}