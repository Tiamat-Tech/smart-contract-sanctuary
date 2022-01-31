// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// import "erc721a/contracts/ERC721A.sol";

contract ArtacleNFT is ERC721Enumerable, Ownable {
// contract ArtacleNFT is ERC721A, Ownable {
  using SafeMath for uint256;

  // See https://medium.com/coinmonks/the-elegance-of-the-nft-provenance-hash-solution-823b39f99473
  // This must be SHA256(concat([SHA256(image) for image in original_image_sequence])).
  // The idea is - nobody can break the original sequence without breaking the hash,
  // thus it prevents insiders or contract owners from maliciously re-ordering rare items.
  string public ART_PROVENANCE;
  // The starting index is used to provide additional randomization within the original images sequence:
  uint256 public startingIndexSeedBlock;
  uint256 public startingIndex;

  string private artsBaseURI;

  uint256 public tokenPrice;
  uint256 public maxTokensPerAddress; // the same on sale and pre-sale
  uint256 public tokensToGiveAwayOnBatchMint;
  uint256 public presaleTokensAmt; // pre-sale
  uint256 public totalTokensAmt; // public sale + pre-sale
  uint256 public totalMintedOnPresale;

  // State:
  enum SaleState{NOT_STARTED, PRESALE, PUBLIC_SALE, CLOSED}
  SaleState private saleState;
  bool public isRevealed;

  // Whitelisting for presale:
  mapping(address => uint256) private presaleWhitelist;
  mapping(address => uint256) private publicSaleLimits;

  constructor (string memory name, string memory code, uint256 price,
               uint256 presaleAmt, uint256 totalAmt, string memory provenanceHash) ERC721 (name, code) {
  // constructor (string memory name, string memory code, uint256 price,
  //              uint256 presaleAmt, uint256 totalAmt, string memory provenanceHash) ERC721A (name, code, 4) {
    require(totalAmt > 0, "Incorrect num of tokens");
    require(totalAmt > presaleAmt, "Pre-sale > total");
    require(bytes(provenanceHash).length > 0, "Invalid provenance"); // TODO: check that it contains only hex digits

    tokenPrice = price;
    startingIndexSeedBlock = 0;
    startingIndex = 0;

    maxTokensPerAddress = 4;
    tokensToGiveAwayOnBatchMint = 0;

    presaleTokensAmt = presaleAmt;
    totalTokensAmt = totalAmt;
    ART_PROVENANCE = provenanceHash;
    saleState = SaleState.NOT_STARTED;
    isRevealed = false;
  }

  function setTokenPrice(uint256 newPrice) external onlyOwner {
    if (newPrice != tokenPrice) {
      tokenPrice = newPrice;
    }
  }

  function adjustTokensAmount(uint256 presaleAmt, uint256 totalAmt) external onlyOwner {
    require(totalAmt > 0, "Incorrect num of tokens");
    require(totalAmt > presaleAmt, "Pre-sale > total");

    presaleTokensAmt = presaleAmt;
    totalTokensAmt = totalAmt;
  }

  function setMintingLimits(uint256 maxTokens, uint256 giveFreePerBatch) external onlyOwner {
    require(giveFreePerBatch < maxTokens, "Invalid giveaway");

    maxTokensPerAddress = maxTokens;
    tokensToGiveAwayOnBatchMint = giveFreePerBatch;
  }

  function setProvenanceHash(string memory provenanceHash) external onlyOwner {
    require(bytes(provenanceHash).length > 0, "Invalid provenance"); // TODO: check that it contains only hex digits
    ART_PROVENANCE = provenanceHash;
  }

  function setStartingIndex() internal onlyOwner {
    // EVM only stores hashes for the last 256 blocks, so we have no choice but reset the index
    // if the seed block is older.
    uint256 originalSeed = startingIndexSeedBlock;
    if (startingIndexSeedBlock == 0 || block.number.sub(startingIndexSeedBlock) > 255) {
      startingIndexSeedBlock = block.number - 1;
      if (originalSeed == 0) {
        originalSeed = startingIndexSeedBlock;
      }
    }

    bytes32 hash = keccak256(abi.encodePacked(blockhash(startingIndexSeedBlock), originalSeed, msg.sender));
    startingIndex = uint256(hash) % totalTokensAmt;
   
    // Prevent default sequence
    if (startingIndex == 0) {
      uint256 total = totalSupply();
      startingIndex = startingIndex.add(Math.min(total % 32, total)) % totalTokensAmt;
      if (startingIndex == 0) {
        startingIndex = 1;
      }
    }
  }

  function setBaseURI(string memory uri) external onlyOwner {
    artsBaseURI = uri;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    // if (!isRevealed) {
    //     return "";
    // }
    return artsBaseURI;
  }

  // TODO: reservation looks like a cheating. Should it effectively decrease the available PRESALE amount?
  function reserveTokens(uint256 numTokens) external onlyOwner {
    require(saleState != SaleState.CLOSED, "Invalid state");

    uint256 currentTokensAmt = totalSupply();
    require(currentTokensAmt + numTokens <= totalTokensAmt, "Not enough tokens");
    
    //  _safeMint(msg.sender, numTokens);
    for (uint256 i = 0; i < numTokens; i++) {
      _safeMint(msg.sender, currentTokensAmt + i);
    }
  }

  function startPresale(address[] calldata addresses) external onlyOwner {
    require(bytes(artsBaseURI).length > 0, "Base URI must be valid");
    require(presaleTokensAmt > 0, "No presale amount provided");
    require(saleState == SaleState.NOT_STARTED, "Invalid state");
    require(addresses.length > 0 && addresses.length <= presaleTokensAmt, "Invalid whitelist size");

    for (uint256 i = 0; i < addresses.length; i++) {
        presaleWhitelist[addresses[i]] = maxTokensPerAddress;
    }

    saleState = SaleState.PRESALE;
    totalMintedOnPresale = 0;
  }

  function startPublicSale() external onlyOwner {
    require(bytes(artsBaseURI).length > 0, "Base URI must be valid");
    require(saleState == SaleState.PRESALE || saleState == SaleState.NOT_STARTED, "Invalid state");

    // delete _presaleWhitelist; // Get the gas refund?
    saleState = SaleState.PUBLIC_SALE;
  }

  function closeSales() external onlyOwner {
    require(saleState == SaleState.PRESALE || saleState == SaleState.PUBLIC_SALE, "Invalid state");
    saleState = SaleState.CLOSED;
    setStartingIndex();
  }

  function setSaleStateEmergency(SaleState forcedState) external onlyOwner {
    saleState = forcedState;
    startingIndex = 0;
    if (saleState == SaleState.CLOSED) {
      setStartingIndex();
    }
  }

  function setRevealedState(bool state) external onlyOwner {
    isRevealed = state;
  }

  function mint(uint256 numTokens) external payable {
    require(numTokens > 0, "Minting 0 tokens");
    require(saleState == SaleState.PRESALE || saleState == SaleState.PUBLIC_SALE, "Invalid state");
    // require(msg.sender != address(this), "Transferring to this");
    require(numTokens <= maxTokensPerAddress, "Too many tokens");

    uint256 currentTokensAmt = totalSupply();
    require(currentTokensAmt + numTokens <= totalTokensAmt, "Not enough tokens");

    uint256 tokensToPayFor = Math.min(numTokens, maxTokensPerAddress - tokensToGiveAwayOnBatchMint);
    require(msg.sender == owner() || tokensToPayFor * tokenPrice <= msg.value, "Not enough Ether");

    if (saleState == SaleState.PRESALE) {
      require(numTokens <= presaleWhitelist[msg.sender], "Too many tokens for address");
      require(totalMintedOnPresale + numTokens <= presaleTokensAmt, "Not enough tokens for presale");
      presaleWhitelist[msg.sender] -= numTokens; // Must be done before minting to block the re-entrancy attack
      totalMintedOnPresale += numTokens;
    }
    else {
      require(publicSaleLimits[msg.sender] + numTokens <= maxTokensPerAddress, "Too many tokens for address");
      publicSaleLimits[msg.sender] += numTokens;
    }

    // _safeMint(msg.sender, numTokens);
    for (uint256 i = 0; i < numTokens; i++) {
      _safeMint(msg.sender, currentTokensAmt + i);
    }

    // Remember the seed block number to generate the start index later. Two possible scenarios:
    // 1. The seed block index will be reset upon the very last token sale if we ever sell out
    // 2. The seed block is initially set upon the very first public sale and will be used if we never sell out
    if ((startingIndexSeedBlock == 0 && saleState == SaleState.PUBLIC_SALE) || (currentTokensAmt + numTokens == totalTokensAmt)) {
      startingIndexSeedBlock =  block.number - 1;
    }

  }

  function withdraw() public onlyOwner {
    uint256 balance = address(this).balance;
    payable(msg.sender).transfer(balance);
  }

}