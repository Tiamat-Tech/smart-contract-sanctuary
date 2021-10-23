// SPDX-License-Identifier: GPL-3.0

// Created by HashLips
// The Nerdy Coder Clones

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CryptoHermits is ERC721Enumerable, Ownable {
  using Strings for uint256;

  // baseURI for example: https://cryptohermitsnft.com/
  string public baseURI;
  // cost for each nft
  uint256 public cost = 0.05 ether;
  // max supply of NFT tokens
  uint256 public maxSupply = 100;
  // max amount a wallet can mint
  uint256 public maxMintAmount = 2;
  // paused boolean for pausing the smart contract
  bool public paused = false;
  // struct for whitelisted user
  struct User {
    bool isWhitelisted;
    uint256 airdropTokens;
  }
  // mapping to whitelist wallet addresses for airdrops
  mapping(address => User) public whitelisted;
  // int for free airdrops
  uint256 public maxAirdropAmount = 1;

  event printNewTokenId(uint256 _newTokenId);

  // pass in name of NFT, symbol of NFT and baseURI
  // super constructor on ERC721 and pass name and symbol
  constructor(string memory _name, string memory _symbol, string memory _initBaseURI) ERC721(_name, _symbol) {
    // set baseURI upon initializing smart contract
    setBaseURI(_initBaseURI);
    // mint 20 nfts to contract address owner to distribute later
    // mint(msg.sender, 20);
  }

  // internal functions
  // reads baseURI and returns our baseURI
  function _baseURI() internal view virtual onlyOwner override returns (string memory) {
    return baseURI;
  }

  // public functions
  // function to mint NFT
  function mint(address _to, uint256 _mintAmount) public payable {
    uint256 supply = getSupply();
    // contract cannot be paused
    require(!paused, "Contract cannot be paused, please unpause to mint NFT.");
    // mint amount greater then 0
    require(_mintAmount > 0, "Mint amount has to be greater then 0.");
    // mint amount less then or equal to maxMintAmount
    require(_mintAmount <= maxMintAmount, "Mint has to be less or equal to then the maxMintAmount of 2.");
    // current supply + mintAmount has to be less then maxSupply
    require(supply + _mintAmount <= maxSupply, "The current supply + the mintAmount has to be less then the maxSupply.");

    // if the msg.sender is not the owner
    if (msg.sender != owner()) {
      // if the address is whitelisted
      if(whitelisted[msg.sender].isWhitelisted == true) {
        // only allow them to mint 1 free token
        require(_mintAmount < 2, "You can only mint 1 free NFT if your wallet address is whitelisted.");
        require(whitelisted[msg.sender].airdropTokens < maxAirdropAmount, "You have already minted your free NFT.");
        
        whitelisted[msg.sender].airdropTokens += 1;
      }

      // if address is not whitelisted, then they have to pay at least 0.05 eth * mintAmount
      if(whitelisted[msg.sender].isWhitelisted != true) {
        require(msg.value == cost * _mintAmount);
      }
    }

    // supply starts at 0 and goes up by 1 each time
    // i starts at 1 for each minting round
    // for example, if the first buyer only bought 1, it would be supply(0) + i(1) = 1 --> 1 for the token tokenId
    // next round, the buyer buys 2, it would be supply(1) + i(1) && supply(1) + i(2) --> 2 and 3 for the tokenIds
    for (uint256 i = 1; i <= _mintAmount; i++) {
      uint256 newTokenId = supply + i;
      _safeMint(_to, newTokenId);
      emit printNewTokenId(newTokenId);
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
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI, tokenId.toString())) : "";
  }

  function getSupply() public view returns (uint256) {
    // starts at 0 and goes up by 1 each time
    return totalSupply();
  }

  // only owner functions
  function updateMaxAirdropAmount(uint _newMaxAirdropAmount) public onlyOwner {
      maxAirdropAmount = _newMaxAirdropAmount;
  }
  
  function setCost(uint256 _newCost) public onlyOwner {
    cost = _newCost;
  }

  function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
    maxMintAmount = _newmaxMintAmount;
  }

  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;
  }

  function pause(bool _state) public onlyOwner {
    paused = _state;
  }
 
  function whitelistUser(address _user) public onlyOwner {
    whitelisted[_user].isWhitelisted = true;
  }
 
  function removeWhitelistUser(address _user) public onlyOwner {
    whitelisted[_user].isWhitelisted = false;
  }

  function withdraw() public payable onlyOwner {
    require(payable(msg.sender).send(address(this).balance));
  }
}