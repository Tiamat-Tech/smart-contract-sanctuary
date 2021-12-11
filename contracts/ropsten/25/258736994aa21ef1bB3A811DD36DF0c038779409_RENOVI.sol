// RENOVI.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
// import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// import "./Mintable.sol";
import "@imtbl/imx-contracts/contracts/Mintable.sol";

// contract RENOVI is ERC721EnumerableUpgradeable {
contract RENOVI is ERC721Enumerable, Mintable {
  using SafeMath for uint256;

  string private baseUri = "http://localhost:3000/api/token?tokenId=";

  enum SaleStatus { NotSale, Sale }
  
  struct UserInfo {
    string avatar;
    string username;
    string email;
    string description;
  }

  mapping (address => UserInfo) public users;

  mapping (uint256 => SaleStatus) private _tokenStatus;
  mapping (uint256 => uint256) private _tokenPrice;
  mapping (uint256 => address) private _tokenCreator;

  struct TokenInfoDetailed {
    uint256 tokenId;
    address creator;
    UserInfo creatorInfo;
    address owner;
    UserInfo ownerInfo;
    SaleStatus status;
    uint256 price;
  }

  struct TxMeta {
    address seller;
    address buyer;
    uint256 value;
    uint256 time;
    uint256 tokenId;
  }

  TxMeta[] public transactions;

  // function initialize() initializer public {
  //   __ERC721_init("RENOVI", "RNVI");
  //   // Mintable(_imx);
  // }

  // constructor(
  //   address _owner,
  //   address _imx
  // ) ERC721("RENOVI", "RNVI") Mintable(_owner, _imx) {}

  // mainnet: 0x5FDCCA53617f4d2b9134B29090C87D01058e27e9
  constructor() ERC721("RENOVI", "RNVI") Mintable(msg.sender, 0x4527BE8f31E2ebFbEF4fCADDb5a17447B27d2aef) {}

  function mint(
    uint256 price,
    SaleStatus status
  ) public returns (uint256) {
    uint256 tokenId = totalSupply() + 1;
    _safeMint(msg.sender, tokenId);
    _tokenStatus[tokenId] = status;
    _tokenCreator[tokenId] = msg.sender;
    _tokenPrice[tokenId] = price;
    return tokenId;
  }

  function _mintFor(
    address user,
    uint256 id,
    bytes memory
  ) internal override {
    _safeMint(user, id);
  }

  function getToken(uint256 tokenId) public view returns(TokenInfoDetailed memory ) {
    require(_exists(tokenId));
    address owner = ownerOf(tokenId);
    address creator = _tokenCreator[tokenId];
    return TokenInfoDetailed(tokenId, creator, users[creator], owner, users[owner], _tokenStatus[tokenId], _tokenPrice[tokenId]);
  }

  function buy(uint256 tokenId) external payable {
    require(_exists(tokenId));
    require(msg.sender != address(0) && msg.sender != ownerOf(tokenId), "Wrong address.");
    require(_tokenStatus[tokenId] == SaleStatus.Sale, "Not for sale.");
    require(_tokenPrice[tokenId] <= msg.value, "Insufficent price");
    address seller = ownerOf(tokenId);
    payable(seller).transfer(msg.value);
    setApprovalForAll(seller, true);
    _transfer(seller, msg.sender, tokenId);
    _tokenStatus[tokenId] = SaleStatus.NotSale;
    transactions.push(TxMeta(seller, msg.sender, msg.value, block.timestamp, tokenId));
  }

  function updateStatusAndPrice(uint256 tokenId, SaleStatus status, uint256 price) external {
    require(_exists(tokenId));
    require(msg.sender == ownerOf(tokenId), 'Not owner');
    _tokenPrice[tokenId] = price;
    _tokenStatus[tokenId] = status;
  }

  function getAllOfOwner(address addr) public view virtual returns(TokenInfoDetailed[] memory) {
    uint tokenCount = balanceOf(addr);
    TokenInfoDetailed[] memory _ownerTokens = new TokenInfoDetailed[](tokenCount);
    for(uint i = 0; i < tokenCount; i++){
      _ownerTokens[i] = getToken(tokenOfOwnerByIndex(addr, i));
    }
    return _ownerTokens;
  }

  function getAllOnSale() public view virtual returns(TokenInfoDetailed[] memory) {
    TokenInfoDetailed[] memory tokensOnSale = new TokenInfoDetailed[](totalSupply());
    uint256 counter = 0;
    for(uint i = 1; i <= totalSupply(); i++) {
      if (_tokenStatus[i] == SaleStatus.Sale) {
        tokensOnSale[counter] = getToken(i);
        counter++;
      }
    }
    return tokensOnSale;
  }

  function getUser(address addr) public view returns(UserInfo memory) {
    return users[addr];
  }

  function setUser(
    string memory _avatar,
    string memory _username,
    string memory _email,
    string memory _description
  ) public returns (UserInfo memory) {
    users[msg.sender] = UserInfo(_avatar, _username, _email, _description);
    return users[msg.sender];
  }

  function getTransactions() public view returns(TxMeta[] memory) {
    return transactions;
  }

  function _baseURI() internal view override returns (string memory) {
    return baseUri;
  }

  function setBaseURI(string memory newBaseURI) external onlyOwner {
    baseUri = newBaseURI;
  }
}