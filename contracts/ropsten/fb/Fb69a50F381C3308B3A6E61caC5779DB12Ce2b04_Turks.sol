// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Turks is ERC721, ERC721Enumerable, Ownable {
  using Strings for uint256;

  bool public _isSaleActive = false;
  uint256 constant public cost = 0.05 ether;
  uint256 constant public maxSupply = 5;
  uint256 constant public maxMintAmount = 1;

  mapping(uint256 => uint256) private _tokenIdToTurkId;
  mapping(uint256 => uint256) private _indices;
  uint256 private _startingIndex = 0;

  event SaleStarted();
  event SaleStopped();
  event TokenMinted(uint256 supply);

  constructor() ERC721("Turks", "TRK") {}

  function startSale() public onlyOwner {
    _isSaleActive = true;
    emit SaleStarted();
  }

  function pauseSale() public onlyOwner {
    _isSaleActive = false;
    emit SaleStopped();
  }

  function _baseURI() internal pure override returns (string memory) {
    return "ipfs://QmS6icBx96gdB2CDxmpaRMzvdbBcq3K7jSixX5WEPJRDWk/";
  }

  function withdraw() public onlyOwner {
    uint256 balance = address(this).balance;
    payable(msg.sender).transfer(balance);
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
    uint256 turkId = _tokenIdToTurkId[tokenId];
    return string(abi.encodePacked(_baseURI(), turkId.toString(), ".json"));    
  }

  function mint(address _to, uint256 _mintAmount) public payable {
    require(_isSaleActive, 'Sale must be active to mint Turks');

    internalMint(_to, _mintAmount);
  }

  function internalMint(address _to, uint256 _mintAmount) internal {
    // Preconditions
    uint256 supply = totalSupply();
    require(_mintAmount > 0);
    require(_mintAmount <= maxMintAmount);
    require(supply + _mintAmount <= maxSupply);
    if (msg.sender != owner()) {
        require(msg.value >= cost * _mintAmount);
    }
    
    for (uint256 i = 1; i <= _mintAmount; i++) {
      uint256 tokenId = supply + i;

      // mint first
      _safeMint(_to, tokenId);

      // Notify about the minted tokenId
      emit TokenMinted(totalSupply());

      // assign the random turkId to tokenId
      assignTurkId(tokenId);
    }
  }

  function airdrop(address _to) public onlyOwner {
    internalMint(_to, 1);
  }

  function airdropToMany(address[] memory recipients) public onlyOwner {
    for (uint256 i = 0; i < recipients.length; i++) {
      airdrop(recipients[i]);
    }
  }

  function assignTurkId(uint256 tokenId) internal {
    // get the random index
    uint256 availableTokenAmount = maxSupply - tokenId + 1;
    uint256 index = _startingIndex + random() % availableTokenAmount;
    
    // if already selected before, use the replaced value 
    uint256 turkId = index + 1;
    if (_indices[index] != 0) {
        turkId = _indices[index];
    }
    _indices[index] = _startingIndex + 1;
    if (_indices[_startingIndex] != 0) {
        _indices[index] = _indices[_startingIndex];
    }
    _startingIndex++;

    // set the URI id
    _tokenIdToTurkId[tokenId] = turkId;
  }

  function random() internal view returns (uint) {
    return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}