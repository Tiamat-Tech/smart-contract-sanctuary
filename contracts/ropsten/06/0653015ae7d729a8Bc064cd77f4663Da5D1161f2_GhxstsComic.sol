// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "erc721a/contracts/ERC721A.sol";
import "base64-sol/base64.sol";

//////////////////////////////////////////////////////////////////////////////////////////
//                                                                                      //
//                                                                                      //
//   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@   //
//  @@@@          @@@     @@@@     @@@    @@@@@                                    @    //
//  @@       //   @@@     @@@@     @@    @@@@          @@@@   @@@    @@/      @@@* @    //
//  @     @@@@@@@@@@@     @@@@     @@     @@@    .     @@@@@@@@@@    @@@@     @@@@@@    //
//  @    /@@@@@@@@@@@     @@@@     @@@/   /     @@@      @@@@@@@@    @@@@@      @@@@    //
//       @@@@@      @              @@@@       @@@@@@@      @@@@@@    @@@@@@*      @@    //
//       @@@@@@    @@     @@@@     @@@@      @@@@@@@@@@     [email protected]@@@    @@@@@@@@@     @    //
//  @     @@@@@    @@     @@@@     @@@        @@@@@@@@@@&    @@@@    @@@@@@@@@@         //
//  @      @@@@    @@     @@@@          @     @@@@@@@@@@@     @@@    @@@@@@@@@@@        //
//  @@(      /     @@     @@@@        @@@     @@@@% [email protected]@@     @@@@    @@@@  #@@@         //
//  @@@@@         @@@     @@@@       @@@@@    (@@@%        %@@@@     @@@@         @@    //
//                                                                                      //
//                                                                                      //
//////////////////////////////////////////////////////////////////////////////////////////

/* Created with love for the Pxin Gxng, by Rxmmy */

contract GhxstsComic is Ownable, ERC721A, ReentrancyGuard {
  // Datapacking all chapter data.
  struct Chapter {
    uint256 id;
    string name;
    string image;
    string description;
    bytes32 merkleRoot; // Merkle root for each chapter.
    bool active;
    bool frozen; // These chapters can no longer be minted or modified in any way.
    bool isSaleOpen; // Is the private sale open for a chapter.
    bool isPublicSaleOpen; // Is a public sale open for a chapter.
    uint256 price; // Max price: 10 ether or 10000000000000000000 wei
    uint256 discountPrice; // Max price: 10 ether or 10000000000000000000 wei
    uint256 supply; // Current supply for each chapter.
    uint256 maxSupply; // Max supply for each chapter.
    uint256 firstTokenId; // Starting tokenId for this chapter.
  }

  // Chapter data by ID.
  mapping(uint256 => uint256) public _chapterDetails;
  mapping(uint256 => string) public chapterName;
  mapping(uint256 => string) public chapterImage;
  mapping(uint256 => string) public chapterDescription;
  mapping(uint256 => bytes32) public chapterMerkle;

  // Note: These quantities reset with each chapter.
  // Quantity of public mints claimed by wallet.
  mapping(address => uint256) public minted;
  // Addresses that have claimed their allowList mints.
  mapping(address => uint256) public allowListMinted;
  // Addresses that have claimed their discounted mints.
  mapping(address => uint256) public discountMinted;

  // Max mint per wallet.
  uint256 public MAX_MINT;
  // Maximum supply for the entire comic series.
  uint256 public MAX_COMIC_SUPPLY;
  uint256 public latestChapter;

  // Record of addresses for clearing mappings later.
  address[] addresses;

  string public ghxstsWebsite = "https://ghxstscomic.com";

  constructor() ERC721A("Ghxsts Comic", "GHXSTCMC", 3) {
    MAX_MINT = 3;
  }

  modifier callerIsUser() {
    require(tx.origin == msg.sender, "The caller is another contract");
    _;
  }
  modifier chapterExists(uint256 _id) {
    Chapter memory chapter = getChapter(_id);
    require(chapter.active, "Chapter does not exist.");
    _;
  }

  // Create datapacked values in the Chapter struct.
  function setChapter(Chapter memory chapter) internal {
    uint256 supply = chapter.supply;
    uint256 maxSupply = chapter.maxSupply;
    uint256 price = chapter.price;
    uint256 discountPrice = chapter.discountPrice;
    uint256 firstTokenId = chapter.firstTokenId;

    require(supply < 65535, "MaxSupply exceeds uint16.");
    require(maxSupply < 65535, "MaxSupply exceeds uint16.");
    require(price < 2**64, "Price exceeds uint64.");
    require(discountPrice < 2**64, "DiscountPrice exceeds uint64.");
    require(firstTokenId < 2**64, "FirstToken exceeds uint64.");

    uint256 details = chapter.active ? uint256(1) : uint256(0);
    details |= (chapter.frozen ? uint256(1) : uint256(0)) << 8;
    details |= (chapter.isSaleOpen ? uint256(1) : uint256(0)) << 16;
    details |= (chapter.isPublicSaleOpen ? uint256(1) : uint256(0)) << 24;
    details |= supply << 32;
    details |= maxSupply << 48;
    details |= price << 64;
    details |= discountPrice << 128;
    details |= firstTokenId << 192;

    // Save the chapter data
    _chapterDetails[chapter.id] = details;
  }

  // Retrieve datapacked values and build the Chapter struct.
  function getChapter(uint256 _id) public view returns (Chapter memory _chapter) {
    uint256 chapterDetails = _chapterDetails[_id];
    _chapter.id = _id;
    _chapter.active = uint8(uint256(chapterDetails)) == 1;
    _chapter.frozen = uint8(uint256(chapterDetails >> 8)) == 1;
    _chapter.isSaleOpen = uint8(uint256(chapterDetails >> 16)) == 1;
    _chapter.isPublicSaleOpen = uint8(uint256(chapterDetails >> 24)) == 1;
    _chapter.supply = uint256(uint16(chapterDetails >> 32));
    _chapter.maxSupply = uint256(uint16(chapterDetails >> 48));
    _chapter.price = uint256(uint64(chapterDetails >> 64));
    _chapter.discountPrice = uint256(uint64(chapterDetails >> 128));
    _chapter.firstTokenId = uint256(uint64(chapterDetails >> 192));
    _chapter.name = chapterName[_id];
    _chapter.image = chapterImage[_id];
    _chapter.description = chapterDescription[_id];
    _chapter.merkleRoot = chapterMerkle[_id];
    return _chapter;
  }

  function createChapter(
    uint256 _id,
    string calldata name,
    string calldata description,
    string calldata image,
    uint256 maxSupply,
    uint256 price,
    uint256 discountPrice
  ) external onlyOwner {
    Chapter memory chapter = getChapter(_id);
    require(!chapter.active, "Chapter already exists.");
    if (_id > 1) {
      Chapter memory prevChapter = getChapter(_id - 1);
      require(prevChapter.frozen, "Previous chapter still open.");
    }

    Chapter memory newChapter;
    newChapter.id = _id;
    newChapter.name = name;
    newChapter.image = image;
    newChapter.description = description;
    newChapter.merkleRoot = "";
    newChapter.active = true;
    newChapter.frozen = false;
    newChapter.isSaleOpen = false;
    newChapter.isPublicSaleOpen = false;
    newChapter.price = price;
    newChapter.discountPrice = discountPrice;
    newChapter.supply = 0;
    newChapter.maxSupply = maxSupply;
    newChapter.firstTokenId = totalSupply();

    setChapter(newChapter);

    chapterName[_id] = name;
    chapterDescription[_id] = description;
    chapterImage[_id] = image;

    latestChapter = _id;
    MAX_COMIC_SUPPLY += maxSupply;
  }

  // Update the supply of a chapter.
  function updateSupply(uint256 _id, uint256 supply) internal {
    // Check supply size
    require(supply < 65535, "Supply exceeds uint16.");
    Chapter memory chapter = getChapter(_id);
    chapter.supply = chapter.supply + supply;
    setChapter(chapter);
  }

  /**
   * @notice Set the max supply for a chapter.
   */
  function updateMaxSupply(uint256 _id, uint256 maxSupply) external chapterExists(_id) onlyOwner {
    require(maxSupply < 65535, "maxSupply exceeds uint16.");
    Chapter memory chapter = getChapter(_id);
    require(chapter.supply == 0, "Cannot change maxSupply after minting begins.");
    uint256 prev = MAX_COMIC_SUPPLY - chapter.maxSupply;

    chapter.maxSupply = maxSupply;
    setChapter(chapter);

    // Update the maximum supply of all tokens.
    MAX_COMIC_SUPPLY = prev + maxSupply;
  }

  /**
   * @notice Set the price for a chapter.
   */
  function updatePrice(uint256 _id, uint256 price) external chapterExists(_id) onlyOwner {
    require(price < 2**64, "Price exceeds uint64.");
    Chapter memory chapter = getChapter(_id);
    chapter.price = price;
    setChapter(chapter);
  }

  /**
   * @notice Set the discount price for a chapter.
   */
  function updateDiscountPrice(uint256 _id, uint256 discountPrice) external chapterExists(_id) onlyOwner {
    require(discountPrice < 2**64, "Price exceeds uint64.");
    Chapter memory chapter = getChapter(_id);
    chapter.discountPrice = discountPrice;
    setChapter(chapter);
  }

  /**
   * @notice Toggle the allowList sale on / off.
   */
  function togglePrivateSale(uint256 _id) external chapterExists(_id) onlyOwner {
    Chapter memory chapter = getChapter(_id);
    require(!chapter.frozen, "Chapter frozen.");
    chapter.isSaleOpen = chapter.isSaleOpen ? false : true;
    setChapter(chapter);
  }

  /**
   * @notice Toggle the public sale on / off.
   */
  function togglePublicSale(uint256 _id) external chapterExists(_id) onlyOwner returns (bool update) {
    Chapter memory chapter = getChapter(_id);
    require(!chapter.frozen, "Chapter frozen.");
    require(chapter.maxSupply > 0, "Max supply not set");
    require(chapter.price > 0, "Price not set");
    chapter.isPublicSaleOpen = true;
    setChapter(chapter);
    return update;
  }

  /**
   * @notice Freeze a chapter forever. Irreversible.
   */
  function freezeChapterPermanently(uint256 _id) external chapterExists(_id) onlyOwner {
    Chapter memory chapter = getChapter(_id);
    chapter.frozen = true; // Salute.gif
    setChapter(chapter);

    // Clear out the stored addresses.
    for (uint256 i = 0; i < addresses.length; i++) {
      minted[addresses[i]] = 0;
      allowListMinted[addresses[i]] = 0;
      discountMinted[addresses[i]] = 0;
    }
  }

  /**
   * @notice Set the merkle root for a chapter.
   */
  function updateMerkleRoot(uint256 _id, bytes32 merkleRoot) external chapterExists(_id) onlyOwner {
    chapterMerkle[_id] = merkleRoot;
  }

  /**
   * @notice Mint for owner.
   */
  function ownerMint(uint256 quantity, uint256 chapterId) external chapterExists(chapterId) onlyOwner {
    Chapter memory chapter = getChapter(chapterId);
    require(!chapter.frozen, "Chapter frozen.");
    require(totalSupply() + quantity <= MAX_COMIC_SUPPLY, "Reached max comic supply.");
    require(chapter.supply + quantity <= chapter.maxSupply, "Exceeds chapter maximum supply.");

    uint256 numChunks = quantity / MAX_MINT;
    for (uint256 i = 0; i < numChunks; i++) {
      // Mint it.
      _safeMint(msg.sender, MAX_MINT);
    }

    uint256 remainder = quantity % MAX_MINT;
    if (remainder > 0) {
      // Mint the rest.
      _safeMint(msg.sender, remainder);
    }
    // Update the supply of this chapter.
    updateSupply(chapterId, quantity);
  }

  /**
   * @notice Mint tokens.
   */
  function mint(uint256 quantity, uint256 chapterId) external payable chapterExists(chapterId) callerIsUser {
    Chapter memory chapter = getChapter(chapterId);
    require(!chapter.frozen, "Chapter frozen.");
    require(chapter.isPublicSaleOpen, "Public sale not open");
    require(msg.value == chapter.price * quantity, "Payment incorrect");
    require(totalSupply() + quantity <= MAX_COMIC_SUPPLY, "Reached max supply.");
    require(chapter.supply + quantity <= chapter.maxSupply, "Max purchase supply exceeded");
    require(minted[msg.sender] + quantity <= MAX_MINT, "Quantity exceeded");

    minted[msg.sender] = minted[msg.sender] + quantity;

    updateSupply(chapterId, quantity);

    _safeMint(msg.sender, quantity);
  }

  /**
   * @notice Mint tokens.
   */
  function allowListMint(
    uint256 chapterId,
    uint256 amount,
    uint256 discountAmount,
    uint256 ticket,
    uint256 maxQty,
    uint256 maxDiscountQty,
    bytes32[] calldata merkleProof
  ) external payable chapterExists(chapterId) callerIsUser {
    Chapter memory chapter = getChapter(chapterId);
    require(chapter.isSaleOpen, "Sale not open");
    require(chapter.supply + amount <= chapter.maxSupply, "Max purchase supply exceeded");
    require(allowListMinted[msg.sender] + amount <= maxQty, "Amount exceeded.");
    require(discountMinted[msg.sender] + discountAmount <= maxDiscountQty, "Discount amount exceeded.");
    require(msg.value == (chapter.price * amount) + (chapter.discountPrice * discountAmount), "Payment incorrect");
    bytes32 leaf = keccak256(abi.encodePacked(msg.sender, ticket, maxQty, maxDiscountQty));
    require(MerkleProof.verify(merkleProof, chapter.merkleRoot, leaf), "Invalid proof.");

    allowListMinted[msg.sender] = allowListMinted[msg.sender] + amount;

    // Update the supply of this chapter.
    updateSupply(chapterId, amount + discountAmount);

    _safeMint(msg.sender, amount + discountAmount);
  }

  // ** - ADMIN - ** //
  function withdrawEther(address payable _to, uint256 _amount) external onlyOwner {
    _to.transfer(_amount);
  }

  /**
   * @notice Set the maximum number of mints per wallet.
   */
  function setMAX_MINT(uint256 max) external onlyOwner {
    MAX_MINT = max;
  }

  /**
   * @notice Find which chapter this token belongs to.
   */
  function findChapter(uint256 tokenId) public view returns (Chapter memory chapter) {
    for (uint256 i = 1; i <= latestChapter; i++) {
      chapter = getChapter(i);
      if (chapter.firstTokenId <= tokenId && chapter.firstTokenId + chapter.maxSupply > tokenId) {
        return chapter;
      }
    }
  }

  // ** - MISC - ** //
  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    require(_exists(tokenId), "URI query for nonexistent token");
    Chapter memory chapter = findChapter(tokenId);
    uint256 chapterStart = chapter.firstTokenId;
    uint256 edition = tokenId - chapterStart;
    string memory editionNumber = Strings.toString(edition);

    // Prepend any zeroes for edition numbers. Purely aesthetic.
    if (edition == 0) {
      editionNumber = "0";
    } else if (edition < 10) {
      editionNumber = string(abi.encodePacked("00", editionNumber));
    } else if (edition < 100) {
      editionNumber = string(abi.encodePacked("0", editionNumber));
    }

    string memory json = Base64.encode(
      bytes(
        string(
          abi.encodePacked(
            '{"name": "',
            chapter.name,
            " - ",
            editionNumber,
            '", "description": "',
            chapter.description,
            '", "image": "',
            chapter.image,
            '", "external_url": "',
            ghxstsWebsite,
            '", "attributes": [{"trait_type": "Chapter","value": "Ghxsts ',
            chapter.name,
            '"},{"trait_type": "Edition","value": "#',
            editionNumber,
            '"}]}'
          )
        )
      )
    );
    return string(abi.encodePacked("data:application/json;base64,", json));
  }
}