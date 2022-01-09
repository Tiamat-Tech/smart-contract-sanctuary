pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Puzzle.sol";

contract ShuffleWar is ERC721, Puzzle, Ownable {

  using Strings for uint256;

  string baseURI;
  bool isBaseURIset = false;

  uint256 mintPrice = 20000000000000000;
  uint256 editPrice = 0;

  uint16 constant MAX_TOKEN_ID = 9999;

  uint256 public earlyAccessWindowOpens = 1641830400;
  uint256 public gameStartWindowOpens  = 1641830400;

  uint16 freeMintCount = 1000;

  bool paused = false;

  uint16 public apeTotal;
  uint16 public punkTotal;

  struct TokenInfo {
      bool isSold;
      address owner;
      uint8 tokenType;
  }

  mapping (uint16 => TokenInfo) public tokenInfo;
  mapping (uint16 => uint256[]) public tokenToMoves;

  mapping (uint16 => bool) public editAllowed;

  event NftMinted(address sender, uint16 tokenId);

  constructor() ERC721("punksVSapes", "PvsA") {}


  function _baseURI() override internal view virtual returns (string memory) {
      return baseURI;
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
      require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
      string memory _base = _baseURI();
      return bytes(_base).length > 0 ? string(abi.encodePacked(_base, uint(tokenInfo[uint16(tokenId)].tokenType).toString(), "/", tokenId.toString())) : "";
  }

  function totalSupply() external view returns (uint16) {
    return getTotalMintedCount();
  }

  function getCurrentMintPrice() public view returns (uint) {
        if (getTotalMintedCount() <= freeMintCount) {
          return 0;
        } else {
          return mintPrice;
        }
  }

 function getTotalMintedCount() public view returns (uint16) {
    return apeTotal + punkTotal;
 }

 function getTotalMintedCountForType(uint8 _type) public view returns (uint16) {
    if (_type == 0) {
        return apeTotal;
    } else if (_type == 1) {
        return punkTotal;
    } else return 0;
 }

  function getOwnerInfoForToken(uint16 tokenId) public view returns (uint8, address) {
    TokenInfo memory info = tokenInfo[tokenId];
    return (info.tokenType, info.owner);
  }

   function isAvailableForSale(uint16 tokenId) public view returns (bool) {
    TokenInfo memory info = tokenInfo[tokenId];
    return !info.isSold;
  }

  function getOwnerInfoForTokens(uint16[] memory tokenIds) public view returns (uint8[] memory) {
      uint totalCount = tokenIds.length;
      uint8[] memory ownerInfo = new uint8[](totalCount);

      for (uint16 i=0; i < totalCount; i++) {
        TokenInfo memory info = tokenInfo[tokenIds[i]];

         bool available = !info.isSold;
         uint8 tokenType = info.tokenType;
        
        if (available) {
            ownerInfo[i] = 1;
        } else {
            if (tokenType == 0) {
              ownerInfo[i] = 2;
            } else {
              ownerInfo[i] = 3;
            }
        }
      }
      return ownerInfo;
  }

   function getMovesForToken(uint16 tokenId) public view returns (uint256[] memory) {
    return tokenToMoves[tokenId];
   }

  //tokenType - 0 (ape), 1 (punk)
  // only 1 type can be minted for a tokenId
  // eg. if someone mints 80 for ape, then 80 can't be minted for punk

  // moves is array of numbers containing the moves done be the user
  // moves are applied on the original shuffled order sequentially and the final 
  // order is verified to be correct before minting
  function verifyAndMintItem(uint16 tokenId, 
        uint8 tokenType, 
        bytes memory moves, 
        uint256[] memory _movesData, 
        uint16 shuffleIterationCount)
      public
      payable
  {

      require(!paused, "Minting paused");

      require(block.timestamp >= earlyAccessWindowOpens, "Game not started");

      require(block.timestamp >= gameStartWindowOpens || getTotalMintedCount() <= freeMintCount, "EA limit reached");

      require(!(tokenInfo[tokenId].isSold), "Already minted");

      require(tokenId > 0 && tokenId <= MAX_TOKEN_ID, "Invalid tokenId");

      require(tokenType == 0 || tokenType == 1, "Invalid tokenType");

      require(msg.value == getCurrentMintPrice(), "Incorrect payment");

      require (verifyMoves(tokenId, moves, shuffleIterationCount), "Puzzle not solved, unable to verify moves");

      tokenInfo[tokenId] = TokenInfo(true, msg.sender, tokenType);

     if (tokenType == 0) {
        apeTotal++;
     } else if (tokenType == 1) {
        punkTotal++;
     }
     
      tokenToMoves[tokenId] = _movesData;

      _safeMint(msg.sender, tokenId);

      emit NftMinted(msg.sender, tokenId);
  }

  function setBaseURI(string memory _newBaseURI) external onlyOwner {
    require(!isBaseURIset, "Base URI can't be modified");
    baseURI = _newBaseURI;
    isBaseURIset = true;
  }

  function setMintPrice(uint256 newMintPrice) external onlyOwner {
    mintPrice = newMintPrice;
  }

  function setEditPrice(uint256 newEditPrice) external onlyOwner {
    editPrice = newEditPrice;
  }

  function setFreeMintCount(uint16 count) external onlyOwner {
    freeMintCount = count;
  }

  function pause(bool _state) external onlyOwner {
    paused = _state;
  }

  function editStartWindows(
        uint256 _earlyAccessWindowOpens,
        uint256 _gameStartWindowOpens
    ) external onlyOwner {
        require(
            _gameStartWindowOpens > _earlyAccessWindowOpens,
            "window combination not allowed"
        );
        gameStartWindowOpens = _gameStartWindowOpens;
        earlyAccessWindowOpens = _earlyAccessWindowOpens;
  }

  function editMoves(uint16 tokenId, uint256[] memory _movesData) public payable {
    require(!paused, "paused");
    require(_exists(tokenId), "EditMoves: TokenId doesn't exist");
    require(editAllowed[tokenId], "EditMoves: Not allowed to edit moves");
    require(msg.sender == tokenInfo[tokenId].owner, "EditMoves: Not authorised to set moves");
    require(msg.value == editPrice, "Incorrect payment");

    tokenToMoves[tokenId] = _movesData;
  }

  function editTokenType(uint16 tokenId, uint8 tokenType) public payable {
    require(!paused, "paused");
    require(_exists(tokenId), "EditTokenType: TokenId doesn't exist");
    require(editAllowed[tokenId], "EditTokenType: Not allowed to edit moves");
    require(msg.sender == tokenInfo[tokenId].owner, "EditTokenType: Not authorised to edit token type");
    require(tokenType == 0 || tokenType == 1, "Invalid tokenType");
    require(msg.value == editPrice, "Incorrect payment");

    tokenInfo[tokenId].tokenType = tokenType;
  }

  function releaseFunds() public payable onlyOwner {
    (bool success, ) = payable(0xADf59496737605c9649b194A4610275Dd1c534c0).call{value: address(this).balance}("");
    require(success);
  }
}