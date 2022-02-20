// SPDX-License-Identifier: MIT

/*

         ,-.-.      _,.---._      .-._                             ,----.                     _,---.
,-..-.-./  \==\   ,-.' , -  `.   /==/ \  .-._    _,..---._      ,-.--` , \   .-.,.---.     .-`.' ,  \  .--.-. .-.-.    _.-.
|, \=/\=|- |==|  /==/_,  ,  - \  |==|, \/ /, / /==/,   -  \    |==|-  _.-`  /==/  `   \   /==/_  _.-' /==/ -|/=/  |  .-,.'|
|- |/ |/ , /==/ |==|   .=.     | |==|-  \|  |  |==|   _   _\   |==|   `.-. |==|-, .=., | /==/-  '..-. |==| ,||=| -| |==|, |
 \, ,     _|==| |==|_ : ;=:  - | |==| ,  | -|  |==|  .=.   |  /==/_ ,    / |==|   '='  / |==|_ ,    / |==|- | =/  | |==|- |
 | -  -  , |==| |==| , '='     | |==| -   _ |  |==|,|   | -|  |==|    .-'  |==|- ,   .'  |==|   .--'  |==|,  \/ - | |==|, |
  \  ,  - /==/   \==\ -    ,_ /  |==|  /\ , |  |==|  '='   /  |==|_  ,`-._ |==|_  . ,'.  |==|-  |     |==|-   ,   / |==|- `-._
  |-  /\ /==/     '.='. -   .'   /==/, | |- |  |==|-,   _`/   /==/ ,     / /==/  /\ ,  ) /==/   \     /==/ , _  .'  /==/ - , ,/
  `--`  `--`        `--`--''     `--`./  `--`  `-.`.____.'    `--`-----``  `--`-`--`--'  `--`---'     `--`..---'    `--`-----'

         ,-.-.      _,.---._              ___         ,----.   .-._          .--.-.     ,-,--.
,-..-.-./  \==\   ,-.' , -  `.     .-._ .'=.'\     ,-.--` , \ /==/ \  .-._  /==/  /   ,-.'-  _\
|, \=/\=|- |==|  /==/_,  ,  - \   /==/ \|==|  |   |==|-  _.-` |==|, \/ /, / \==\ -\  /==/_ ,_.'
|- |/ |/ , /==/ |==|   .=.     |  |==|,|  / - |   |==|   `.-. |==|-  \|  |   \==\- \ \==\  \
 \, ,     _|==| |==|_ : ;=:  - |  |==|  \/  , |  /==/_ ,    / |==| ,  | -|    `--`-'  \==\ -\
 | -  -  , |==| |==| , '='     |  |==|- ,   _ |  |==|    .-'  |==| -   _ |            _\==\ ,\
  \  ,  - /==/   \==\ -    ,_ /   |==| _ /\   |  |==|_  ,`-._ |==|  /\ , |           /==/\/ _ |
  |-  /\ /==/     '.='. -   .'    /==/  / / , /  /==/ ,     / /==/, | |- |           \==\ - , /
  `--`  `--`        `--`--''      `--`./  `--`   `--`-----``  `--`./  `--`            `--`---'

         ,-.-.      _,.---._
,-..-.-./  \==\   ,-.' , -  `.     .-.,.---.      _.-.       _,..---._
|, \=/\=|- |==|  /==/_,  ,  - \   /==/  `   \   .-,.'|     /==/,   -  \
|- |/ |/ , /==/ |==|   .=.     | |==|-, .=., | |==|, |     |==|   _   _\
 \, ,     _|==| |==|_ : ;=:  - | |==|   '='  / |==|- |     |==|  .=.   |
 | -  -  , |==| |==| , '='     | |==|- ,   .'  |==|, |     |==|,|   | -|
  \  ,  - /==/   \==\ -    ,_ /  |==|_  . ,'.  |==|- `-._  |==|  '='   /
  |-  /\ /==/     '.='. -   .'   /==/  /\ ,  ) /==/ - , ,/ |==|-,   _`/
  `--`  `--`        `--`--''     `--`-`--`--'  `--`-----'  `-.`.____.'

*/

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";


contract WWW is ERC721, Ownable {
  using Strings for uint256;
  using Counters for Counters.Counter;

  Counters.Counter private supply;

  string public uriPrefix = "";
  string public uriSuffix = ".json";

  uint256 public cost = 0.09 ether;
  uint256 public maxSupplyPresale = 5;
  uint256 public maxSupplyPublic = 10;
  uint256 public maxSupplyOwner = 15;
  uint256 public maxMintAmountPerTx = 5;
  uint256 public nftPerAddressLimit = 2;

  bytes32 public merkleRoot = 0x45d373b11ea62e0d83b64e4253d6c8c5d34b2d019cf45c06d6f18f59124a1159;

  bool public paused = true;
  bool public onlyWhitelisted = true;

  mapping(address => uint256) public addressMintedBalance;

  constructor() ERC721("Tests W W W", "TWW") {}

  modifier mintCompliance(uint256 _mintAmount) {
    require(_mintAmount > 0 && _mintAmount <= maxMintAmountPerTx, "Invalid mint amount!");
    if (msg.sender != owner()) {
      require(supply.current() + _mintAmount <= maxSupplyPublic, "Max supply exceeded!");
    }
    else {
      require(supply.current() + _mintAmount <= maxSupplyOwner, "Max supply owner exceeded!");
    }
    _;
  }

  function preSalesMint(uint256 _mintAmount, bytes32[] calldata _merkleProof) external payable mintCompliance(_mintAmount) {
    require(!paused, "The contract is paused!");
    require(onlyWhitelisted == true, "Presale has ended!");

    require(supply.current() + _mintAmount <= maxSupplyPresale, "Exceed pre-sales max limit");
    require(addressMintedBalance[msg.sender] + _mintAmount <= nftPerAddressLimit, "NFT limit reached!");

    require(msg.value >= _mintAmount * cost, "Insufficient ETH");
    require(tx.origin == msg.sender, "Contracts not allowed");

    bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
    require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), "User is not whitelisted!");

    _mintLoop(msg.sender, _mintAmount);
  }

  function publicSalesMint(uint256 _mintAmount) external payable mintCompliance(_mintAmount) {
    require(!paused, "The contract is paused!");
    require(onlyWhitelisted == false, "Presale is still minting!");

    require(msg.value >= _mintAmount * cost, "Insufficient ETH");
    require(tx.origin == msg.sender, "Contracts not allowed");

    _mintLoop(msg.sender, _mintAmount);
  }

  function mintForAddress(uint256 _mintAmount, address _receiver) public mintCompliance(_mintAmount) onlyOwner {
    _mintLoop(_receiver, _mintAmount);
  }

  function walletOfOwner(address _owner)
    public
    view
    returns (uint256[] memory)
  {
    uint256 ownerTokenCount = balanceOf(_owner);
    uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
    uint256 currentTokenId = 1;
    uint256 ownedTokenIndex = 0;

    while (ownedTokenIndex < ownerTokenCount && currentTokenId <= maxSupplyOwner) {
      address currentTokenOwner = ownerOf(currentTokenId);

      if (currentTokenOwner == _owner) {
        ownedTokenIds[ownedTokenIndex] = currentTokenId;

        ownedTokenIndex++;
      }

      currentTokenId++;
    }

    return ownedTokenIds;
  }

  function totalSupply() public view returns (uint256) {
    return supply.current();
  }

  function tokenURI(uint256 _tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(
      _exists(_tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, _tokenId.toString(), uriSuffix))
        : "";
  }

  function setCost(uint256 _cost) public onlyOwner {
    cost = _cost;
  }

  function setMaxMintAmountPerTx(uint256 _maxMintAmountPerTx) public onlyOwner {
    maxMintAmountPerTx = _maxMintAmountPerTx;
  }

  function setUriPrefix(string memory _uriPrefix) public onlyOwner {
    uriPrefix = _uriPrefix;
  }

  function setUriSuffix(string memory _uriSuffix) public onlyOwner {
    uriSuffix = _uriSuffix;
  }

  function setPaused(bool _state) public onlyOwner {
    paused = _state;
  }

  function setNftPerAddressLimit(uint256 _limit) public onlyOwner {
    nftPerAddressLimit = _limit;
  }

  function setOnlyWhitelisted(bool _state) public onlyOwner {
    onlyWhitelisted = _state;
  }

  function setMerkleRoot(bytes32 _merkle) public onlyOwner {
    merkleRoot = _merkle;
  }

  function withdraw() public onlyOwner {
    (bool os, ) = payable(owner()).call{value: address(this).balance}("");
    require(os);
  }

  function _mintLoop(address _receiver, uint256 _mintAmount) internal {
    for (uint256 i = 0; i < _mintAmount; i++) {
      addressMintedBalance[msg.sender]++;
      supply.increment();
      _safeMint(_receiver, supply.current());
    }
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return uriPrefix;
  }
}