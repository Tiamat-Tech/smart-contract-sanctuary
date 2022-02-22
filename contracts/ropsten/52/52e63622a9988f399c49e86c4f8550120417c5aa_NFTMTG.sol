// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract NFTMTG is ERC721, Ownable {
  using Strings for uint256;
  using ECDSA for bytes32;
  string public baseURI;
  string public defaultURI;
  string public mycontractURI;
  bool public finalizeBaseUri = false;
  uint8 public stage = 0;
  event stageChanged(uint8 stage);
  address private _signer;
  uint256 public presalePrice = 0.2 ether;
  uint256 public presaleSupply;
  uint256 public presaleMintMax = 1;
  mapping(address => uint8) public presaleMintCount;
  //pre-sale-clearance (stage=2)
  uint256 public clearanceMintMax = 2; //one more than presaleMintMax
  //public sale (stage=3)
  uint256 public salePrice = 0.2 ether;
  uint256 public saleMintMax = 3;
  uint256 public totalSaleSupply;
  mapping(address => uint8) public saleMintCount;
  //others
  bool public paused = false;
  uint256 public currentSupply;
  //sale holders
  address[6] public fundRecipients = [
    0xA1ae8f9ed498c7EF353DD275b6F581fC76E72b8B,
    0x491252D2D7FbF62fE8360F80eAFccdF6edfa9090,
    0x20c606439a3ee9988453C192f825893FF5CB40A1,
    0xafBD28f83c21674796Cb6eDE9aBed53de4aFbcC4,
    0xEf0ec25bF8931EcA46D2fF785d1A7f3d7Db6F7ab,
    0x98Eb7D8e1bfFd0B9368726fdf4555C45fDBB2Bd6
  ];
  uint256[] public receivePercentagePt = [2375, 750, 3250, 750, 2375, 500];   //distribution in basis points
  //royalty
  address public royaltyAddr;
  uint256 public royaltyBasis;
  constructor() ERC721("More than gamers", "MTG") {
    setBaseURI("");
    defaultURI = "";
    presaleSupply = 0;
    totalSaleSupply = 10000;
    _signer = 0x0069b64aC1DDe676D74d7a3B221fB1d20a05F640;
  }
  // internal
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }
  function supportsInterface(bytes4 interfaceId) public view override(ERC721) returns (bool) {
      return interfaceId == type(IERC721).interfaceId || 
      interfaceId == 0xe8a3d485 /* contractURI() */ ||
      interfaceId == 0x2a55205a /* ERC-2981 royaltyInfo() */ ||
      super.supportsInterface(interfaceId);
  }
  // public
  function mint_whitelist(uint8 _mintAmount, bytes memory signature) public payable {
    uint256 supply = totalSupply();
    require(!paused);
    require(stage > 0, "Sale not started");
    require(isWhitelisted(msg.sender, signature), "Must be whitelisted");
    require(stage == 1 || stage == 2, "invalid stage");
    require(_mintAmount > 0, "Must mint at least 1");
    require(supply + _mintAmount <= presaleSupply, "Mint exceed presale supply");
    require(msg.value >= presalePrice * _mintAmount, "Insufficient amount sent");
    require(_mintAmount + presaleMintCount[msg.sender] <= (stage == 1 ? presaleMintMax : clearanceMintMax), "Cannot mint more than 2");
    presaleMintCount[msg.sender] += _mintAmount;
    currentSupply += _mintAmount;
    for (uint256 i = 1; i <= _mintAmount; i++) {
      _safeMint(msg.sender, supply + i);
    }
  }
  function mint_public(uint8 _mintAmount) public payable {
    uint256 supply = totalSupply();
    currentSupply += _mintAmount;
    for (uint256 i = 1; i <= _mintAmount; i++) {
      _safeMint(msg.sender, supply + i);
    }
  }
  function isWhitelisted(address _addr, bytes memory signature) public view returns(bool){
      return _signer == ECDSA.recover(keccak256(abi.encodePacked("WL", _addr)), signature);
  }
  function totalSupply() public view returns (uint) {
        return currentSupply;
    }
    function tokensOfOwner(address _owner, uint startId, uint endId) external view returns(uint256[] memory ) {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 index = 0;
            for (uint256 tokenId = startId; tokenId < endId; tokenId++) {
                if (index == tokenCount) break;
                if (ownerOf(tokenId) == _owner) {
                    result[index] = tokenId;
                    index++;
                }
            }
            return result;
        }
    }
  function tokenURI(uint256 tokenId) public view virtual override returns (string memory)
  {
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString()))
        : defaultURI;
  }
  function contractURI() public view returns (string memory) {
      return string(abi.encodePacked(mycontractURI));
  }
  //only owner functions ---
  function nextStage() public onlyOwner() {
    require(stage < 3, "Stage cannot be more than 3");
    stage++;
    emit stageChanged(stage);
  }
  function setwhitelistSigner(address _whitelistSigner) public onlyOwner {
    _signer = _whitelistSigner;
  }
  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    require(!finalizeBaseUri);
    baseURI = _newBaseURI;
  }
  function finalizeBaseURI() public onlyOwner {
    finalizeBaseUri = true;
  }
  function setContractURI(string memory _contractURI) public onlyOwner {
    mycontractURI = _contractURI;
  }
  function setRoyalty(address _royaltyAddr, uint256 _royaltyBasis) public onlyOwner {
    royaltyAddr = _royaltyAddr;
    royaltyBasis = _royaltyBasis;
  }
  function pause(bool _state) public onlyOwner {
    paused = _state;
  }
  function reserveMint(uint256 _mintAmount, address _to) public onlyOwner {
    uint256 supply = totalSupply();
    require(supply + _mintAmount <= totalSaleSupply, "Mint exceed total supply");
    currentSupply += _mintAmount;
    for (uint256 i = 1; i <= _mintAmount; i++) {
      _safeMint(_to, supply + i);
    }
  }
  //fund withdraw functions ---
  function withdrawFund() public onlyOwner {
    uint256 currentBal = address(this).balance;
    require(currentBal > 0);
    for (uint256 i = 0; i < fundRecipients.length-1; i++) {
      _withdraw(fundRecipients[i], currentBal * receivePercentagePt[i] / 10000);
    }
    //final address receives remainder to prevent ether dust
    _withdraw(fundRecipients[fundRecipients.length-1], address(this).balance);
  }
  function _withdraw(address _addr, uint256 _amt) private {
    (bool success,) = _addr.call{value: _amt}("");
    require(success, "Transfer failed");
  }
}