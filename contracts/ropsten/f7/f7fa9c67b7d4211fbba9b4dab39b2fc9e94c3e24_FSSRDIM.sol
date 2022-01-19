// SPDX-License-Identifier: MIT

// recs: 1:1 claim with require(ownerOf)) check, release to owner, 

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IFissure {
    function ownerOf(uint256 tokenId) external view returns (address owner);
}


contract FSSRDIM is
    ERC721,
    ERC721Enumerable,
    Ownable
{
    using SafeMath for uint256;
    using SafeMath for uint16;

    uint16 public MAX_SUPPLY = 256;
    uint256 _mintPrice = 0.00 ether;
    string _baseURIValue;
    bool public releaseIsActive = false;
    bool public claimIsActive = false;
    address FissuresAddr;

    constructor() ERC721("FissuresDims", "FSSRDIM") {
    
    }

    function setFissuresAddr(address _fissuresContract) public onlyOwner {
       FissuresAddr = _fissuresContract;
    }

    function getOwnerOfFissure(uint256 tokenId) public view returns (address) {
        return IFissure(FissuresAddr).ownerOf(tokenId);
    }

    function amIOwner(uint256 tokenId) public view returns (bool) {
        address tokenOwner = getOwnerOfFissure(tokenId);
        if(tokenOwner == msg.sender){
          return true;
        }
        return false;
    }

    function whodaOrigin(uint256 tokenId) public view returns (address) {
        getOwnerOfFissure(tokenId);
        return msg.sender;
    }

    function myAddress() public view returns (address) {
        return msg.sender;
    }

    function isNotMintedYet(uint256 tokenId) public view returns (bool) {
    return !_exists(tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseURIValue;
    }

    function baseURI() public view returns (string memory) {
        return _baseURI();
    }

    function setBaseURI(string memory newBase) public onlyOwner {
        _baseURIValue = newBase;
    }


    function flipReleaseState() public onlyOwner {
        releaseIsActive = !releaseIsActive;
    }
    
    function flipClaimSaleState() public onlyOwner {
        claimIsActive = !claimIsActive;
    }


    function baseMintPrice() public view returns (uint256) {
        return _mintPrice;
    }

    function setBaseMintPrice(uint256 price) public onlyOwner {
        _mintPrice = price;
    }

    function mintPrice(uint256 numberOfTokens) public view returns (uint256) {
        return _mintPrice.mul(numberOfTokens);
    }

    
    function isCanIMintOne(uint256 tokenId) public view returns (bool) {
        return (isNotMintedYet(tokenId) && amIOwner(tokenId));
    }

    function mintOne(uint256 tokenId) external {
    //   require(isIdOk(tokenId), "INVALID_ID");
      require(claimIsActive, "NO_START");
      require(amIOwner(tokenId), "NO_OWN");
       _safeMint(msg.sender, tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

 




  // CHECK AND MINT MANY

  // function getMintableIds(address _owner) public view returns (uint256[] memory){
  //   SadGirlsBarClient sgb = SadGirlsBarClient(_sgbAddress);

  //   // get all owned fissures tokens
  //   uint256[] memory sgbTokensArray = sgb.tokensOfOwner(_owner);
  //   require(sgbTokensArray.length > 0, "NO_SGB");

  //   // array for result
  //   uint256[] memory subtotalIds = new uint256[](_maxBatchSize);

  //   // array limit
  //   uint256 currentIdx;

  //   // iterate over owned girls
  //   for (uint256 i=0; i<sgbTokensArray.length; i++) {
  //     // check skeleton not minted yet
  //     if (!_exists(sgbTokensArray[i])) {
  //       // if not minted - add id in array
  //       subtotalIds[currentIdx] = sgbTokensArray[i];
  //       currentIdx++;
  //       // and check array boundaries
  //       if (currentIdx>= _maxBatchSize) {
  //         break;
  //       }
  //     }
  //   }

  //   uint256[] memory mintableIds = new uint256[](currentIdx);
  //   for (uint256 i=0; i<currentIdx; i++) {
  //     mintableIds[i] = subtotalIds[i];
  //   }

  //   return mintableIds;
  // }

  // function mintMany(uint256 _amount) external {
  //   require(isStarted, "NO_START");
  //   uint256[] memory mintableIds = getMintableIds(msg.sender);
  //   require(mintableIds.length > 0, "NO_MINT");
  //   require(_amount<=_maxBatchSize, "TOO_MUCH");
  //   require(_amount<=mintableIds.length, "TOO_MUCH");
  //   require(_amount>0, "ZERO_AMOUNT");
  //   for (uint256 i=0; i<_amount; i++) {
  //     _safeMint(msg.sender, mintableIds[i]);
  //   }

  // }