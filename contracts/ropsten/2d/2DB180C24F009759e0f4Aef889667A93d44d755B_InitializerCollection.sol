// SPDX-License-Identifier: MIT
//..........................................................................................................
//.BBBBBBBBBBBBBBBB......LLLLLL..................AAAAAAAA........NNNNNN.......NNNNNN...KKKKK.......KKKKKKK..
//.BBBBBBBBBBBBBBBBBB....LLLLLL..................AAAAAAAA........NNNNNNN......NNNNNN...KKKKK......KKKKKKKK..
//.BBBBBBBBBBBBBBBBBB....LLLLLL.................AAAAAAAAA........NNNNNNNN.....NNNNNN...KKKKK.....KKKKKKKK...
//.BBBBBBBBBBBBBBBBBBB...LLLLLL.................AAAAAAAAAA.......NNNNNNNN.....NNNNNN...KKKKK....KKKKKKKK....
//.BBBBBB.....BBBBBBBB...LLLLLL.................AAAAAAAAAA.......NNNNNNNNN....NNNNNN...KKKKK...KKKKKKKK.....
//.BBBBBB.......BBBBBB...LLLLLL................AAAAAAAAAAA.......NNNNNNNNN....NNNNNN...KKKKK..KKKKKKKK......
//.BBBBBB.......BBBBBB...LLLLLL................AAAAAAAAAAAA......NNNNNNNNNN...NNNNNN...KKKKK..KKKKKKK.......
//.BBBBBB.......BBBBBB...LLLLLL...............AAAAAA.AAAAAA......NNNNNNNNNNN..NNNNNN...KKKKK.KKKKKKK........
//.BBBBBB.....BBBBBBBB...LLLLLL...............AAAAAA.AAAAAA......NNNNNNNNNNN..NNNNNN...KKKKKKKKKKKK.........
//.BBBBBBBBBBBBBBBBBB....LLLLLL...............AAAAAA..AAAAAA.....NNNNNNNNNNNN.NNNNNN...KKKKKKKKKKKKK........
//.BBBBBBBBBBBBBBBBB.....LLLLLL..............AAAAAA...AAAAAA.....NNNNNNNNNNNN.NNNNNN...KKKKKKKKKKKKKK.......
//.BBBBBBBBBBBBBBBBBB....LLLLLL..............AAAAAA...AAAAAAA....NNNNNNNNNNNNNNNNNNN...KKKKKKKKKKKKKK.......
//.BBBBBBBBBBBBBBBBBBB...LLLLLL..............AAAAAA....AAAAAA....NNNNNN.NNNNNNNNNNNN...KKKKKKKKKKKKKKK......
//.BBBBBB.....BBBBBBBBB..LLLLLL.............AAAAAAAAAAAAAAAAA....NNNNNN..NNNNNNNNNNN...KKKKKKK.KKKKKKKK.....
//.BBBBBB........BBBBBB..LLLLLL.............AAAAAAAAAAAAAAAAAA...NNNNNN..NNNNNNNNNNN...KKKKKK...KKKKKKK.....
//.BBBBBB........BBBBBB..LLLLLL.............AAAAAAAAAAAAAAAAAA...NNNNNN...NNNNNNNNNN...KKKKK.....KKKKKKK....
//.BBBBBB........BBBBBB..LLLLLL............AAAAAAAAAAAAAAAAAAA...NNNNNN...NNNNNNNNNN...KKKKK.....KKKKKKK....
//.BBBBBB......BBBBBBBB..LLLLLL............AAAAAA.......AAAAAAA..NNNNNN....NNNNNNNNN...KKKKK......KKKKKKK...
//.BBBBBBBBBBBBBBBBBBBB..LLLLLLLLLLLLLLLLLLAAAAA.........AAAAAA..NNNNNN.....NNNNNNNN...KKKKK......KKKKKKKK..
//.BBBBBBBBBBBBBBBBBBB...LLLLLLLLLLLLLLLLLLAAAAA.........AAAAAA..NNNNNN.....NNNNNNNN...KKKKK.......KKKKKKK..
//.BBBBBBBBBBBBBBBBBB....LLLLLLLLLLLLLLLLLLAAAAA.........AAAAAAA.NNNNNN......NNNNNNN...KKKKK........KKKKKK..
//.BBBBBBBBBBBBBBBBB.....LLLLLLLLLLLLLLLLLLAAAA...........AAAAAA.NNNNNN......NNNNNNN...KKKKK........KKKKKK..
//..........................................................................................................

pragma solidity ^0.8.6;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract InitializerCollection is ERC721,Ownable {

  string public PROVENANCE = ""; // Stores a hash identifying the order of the artwork

  uint16 private nextTokenId = 0; // incremented upon the creation of each token

  uint16 private publicSupplyAvailable = 868; // 868 available to general public
  uint16 private reserveSupplyAvailable = 101; // 101 reserved in treasury
  bool public saleIsActive = true; // Can tokens be purchased?
  bool public openToPublic = false; // Are sales open to the public, or only those whitelisted?
  uint256 public price = 55000000000000000; //0.055 ETH

  // The baseURI token IDs are concatenated to when accessing metadata
  string private baseURIextended = "";

  // The root hash of the Merkle Tree used for our whitelist
  bytes32 public merkleRoot = 0x279d29dbcc10cace2d14437c293e560a292489ead2b7271bf2694e984488095c;

  // Mapping variable to mark whitelist addresses as having claimed
  // Nested mapping allows for tracking mints in multiple whitelist phases
  // ie. whitelistClaimed[walletAddress][whitelistPhase] = true
  uint8 public whitelistPhase = 0;
  mapping(address => mapping(uint8 => bool)) public whitelistClaimed;

  constructor() ERC721("InitializerCollection", "INIT") {}

  // Minting functions
  function mintToken(address to) internal {
    _safeMint(to, nextTokenId);
    nextTokenId = nextTokenId+1;
  }

  function reserveMint(address to)
    public
    onlyOwner
    onlyDuringActiveSale
    onlyWhileReserveSupplyAvailable
  {
    mintToken(to);
    reserveSupplyAvailable = reserveSupplyAvailable-1;
  }

  function whitelistMint(bytes32[] calldata _merkleProof)
    public
    payable
    onlyDuringActiveSale
    onlyWhilePublicSupplyAvailable
  {
    // Ensure the wallet hasn't already claimed
    require(!whitelistClaimed[msg.sender][whitelistPhase], "Already claimed");

    // Verify the provided proof
    bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
    require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), "Invalid proof");

    // Mark address as claimed
    whitelistClaimed[msg.sender][whitelistPhase] = true;

    // Mint token
    mintToken(msg.sender);
    publicSupplyAvailable = publicSupplyAvailable-1;
  }

  function publicMint()
    public
    payable
    onlyDuringActiveSale
    onlyDuringPublicSale
    onlyWhilePublicSupplyAvailable
    priced
  {
    mintToken(msg.sender);
    publicSupplyAvailable = publicSupplyAvailable-1;
  }

  // Getter functions
  function totalSupply() public view returns (uint256) {
    return nextTokenId;
  }

  // Owner functions
  function withdraw() public onlyOwner {
    uint balance = address(this).balance;
    payable(msg.sender).transfer(balance);
  }

  function setProvenance(string calldata provenance) public onlyOwner {
    PROVENANCE = provenance;
  }

  function setSaleState(bool saleState) public onlyOwner {
    saleIsActive = saleState;
  }

  function setPrice(uint256 _price) public onlyOwner {
    price = _price;
  }

  function setOpenToPublic(bool isOpen) public onlyOwner {
    openToPublic = isOpen;
  }

  function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
    merkleRoot = _merkleRoot;
  }

  function setWhitelistPhase(uint8 _whitelistPhase) public onlyOwner {
    whitelistPhase = _whitelistPhase;
  }

  // URI functions
  function setBaseURI(string calldata baseURI) external onlyOwner {
      baseURIextended = baseURI;
  }

  function _baseURI() internal view virtual override returns (string memory) {
      return baseURIextended;
  }

  // Modifiers
  modifier onlyDuringActiveSale() {
    require(saleIsActive, "Sale is not active");
      _;
  }

  modifier onlyWhileReserveSupplyAvailable() {
    require(reserveSupplyAvailable > 0, "Reserve empty");
      _;
  }

  modifier onlyWhilePublicSupplyAvailable() {
    require(publicSupplyAvailable > 0, "Public supply empty");
      _;
  }

  modifier onlyDuringPublicSale() {
    require(openToPublic, "Public sale closed");
      _;
  }

  modifier priced() {
    require(msg.value >= price, "Invalid payment amount");
      _;
  }
}