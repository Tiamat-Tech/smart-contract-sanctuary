// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/* Xinusu Written */
contract SaberMountain is ERC721Enumerable, Ownable {

    /* Unrevealed */
    /* CHANGE CONTRACT METADATA AT BOTTOM OF PAGE */
      string public _unrevealedURI = 'https://ipfs.infura.io/ipfs/QmbsmvwGVkRX7LMpVHHA7rb5zdzTf1qiAEYMPtxza5YcUA';

    // Mappings
      // Maps user address to their remaining mints if they have minted some but not all of their allocation
      mapping(address => uint) public claimedPublic;
      mapping(address => uint) public claimedWhitelist;
      mapping(address => uint) public sentByOwner;

    /* Pricing */
      uint public whitelistMintPrice = 0.088 ether;
      uint public mintPrice = 0.11 ether;

    /* Max's */
      uint public maxItems = 15;
      uint public itemsRemaining = maxItems;

      uint public maxItemsPerPublicUser = 6;
      uint public maxItemsPerWLUser = 4;

    /* Team Mint Total */
      uint public teamMintMax = 5;
      uint public teamMintsRemaining = teamMintMax;
      uint public ownerMintCount = 0;

      uint public publicItemsRemaining = maxItems - teamMintMax;
      uint public maxPublicItems = publicItemsRemaining;

    /* Bools */
      bool public isPublicLive = false;
      bool public isWhitelistLive = false;

      bool public closedWhitelistSale = false;
      bool public closedPublicSale = false;
      bool public closedAllSales = false;

      /* Revealed */
      bool public revealed = false;

    /* Addtional */
      address public recipient;
      string public _baseTokenURI;

    /* Private */
    /* locked */
      bool private withdrawlLock = false;
    /* Merkle Root */
      bytes32 private merkleRoot = 0x11ce1ae9b10bdc29f9bd73fb6f38ac01de031b04c203223c1b722a37e249eb93;
    /* Count Total */
      uint private currentTokenId;

    /* Events */
      event Mint(address indexed owner, uint indexed tokenId);
      event PermanentURI(string tokenURI, uint256 indexed _id);

    /* Constructor */
    constructor() ERC721("Saber Mountain", "SABER") {
      /* Set recipient to msg.sender */
      recipient = msg.sender;
    }

    /* Modifiers */
    modifier whitelistMintingOpen() {
      require(closedWhitelistSale == false, 'Our whitelist sale has ended, however our public sale is still live');
      require(isWhitelistLive == true, 'Unfortunately our whitelist sale isnt currently live');
      _;
    }

    modifier publicMintingOpen() {
      require(isWhitelistLive == false, 'Unfortunately our whitelist sale is still currently live, you will either need to be whitelisted or wait till our public sale opens');
      require(closedPublicSale == false, 'The sale has ended, try buying in the open market');
      require(isPublicLive == true, 'Unfortunately our public sale isnt currently live');
      _;
    }

    /* MINT FUNCTIONS */
    function publicMint(uint _qty) external payable publicMintingOpen {
      require(_qty > 0, "Sale Quantity must be greater than zero");
      require(_qty <= publicItemsRemaining, "Looks like we are sold out");
      require(claimedPublic[msg.sender] <= maxItemsPerPublicUser, "You can mint a maximum of 6 monkeys during Public sale");

      // Check proper amount sent
      require(msg.value >= mintPrice * _qty, "You need more ETH");

      /* send to mint */
      _mintLoop(msg.sender, _qty);
      claimedPublic[msg.sender] += _qty;
      publicItemsRemaining -= _qty;
     }


    function whitelistMint(uint _qty, bytes32[] calldata _merkleProof ) external payable whitelistMintingOpen {
      // Require nonzero amount
      require(_qty > 0, "Sale Quantity must be greater than zero");
      require(_qty <= publicItemsRemaining, "Looks like we are sold out");

      // Merkle Check
      bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
      require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), "Sorry your address is not on the whitelist");
      require(claimedWhitelist[msg.sender] < maxItemsPerWLUser, "You can mint a maximum of 4 monkeys during Whitelist sale");

      // Check proper amount sent
      require(msg.value >= whitelistMintPrice * _qty , "You need more ETH");

        /* Mint end  */
      _mintLoop(msg.sender, _qty);
      claimedWhitelist[msg.sender] += _qty;
      publicItemsRemaining -= _qty;
    }

    /* Intenal */
    function _mintLoop(address _to, uint _amount) internal {
      require(
        currentTokenId + _amount <= maxItems,
        "All of Monkeys are out in the Cosmo and so we are sold out"
      );

      for (uint i = 0; i < _amount; i++) {
        currentTokenId += 1;

        /* _safeMint */
        _safeMint(_to, currentTokenId);
        emit Mint(_to, currentTokenId);
        itemsRemaining -= 1;
      }
    }
    // ADMIN FUNCTIONALITY
    // EXTERNAL

    function ownerMint(uint _amount) external onlyOwner {
      require(_amount <= teamMintsRemaining, "You have no more mints left");
      teamMintsRemaining -= _amount;
      sentByOwner[msg.sender] += _amount;
      ownerMintCount += _amount;
      _mintLoop(msg.sender, _amount);
    }

    function ownerSendMint(uint _amount, address to) external onlyOwner {
      require(_amount <= teamMintsRemaining, "You have no more mints left");
      teamMintsRemaining -= _amount;
      sentByOwner[to] += _amount;
      ownerMintCount += _amount;
      _mintLoop(to, _amount);
    }

    function setMaxItems(uint _maxItems) external onlyOwner {
      maxItems = _maxItems;
    }

    function setRecipient(address _recipient) external onlyOwner {
      recipient = _recipient;
    }

    function revealData(string memory __baseTokenURI) external onlyOwner {
      require(!revealed);
      revealed = true;
      setBaseTokenURI(__baseTokenURI);

      for (uint i = 0; i <= totalSupply(); i++) {
        emit PermanentURI(string(abi.encodePacked(__baseTokenURI,'/',i)), i);
      }
    }

    /* State Functions */
    function triggerEndOfSale() external onlyOwner {
      require(closedAllSales == false, "Sorry this sale has already been closed");
      require(closedWhitelistSale == true, "Sorry this sale has already been closed");
      require(closedPublicSale == false, "Sorry this sale has already been closed");

      /* Close sale states */
      closedPublicSale = true;
      /* End live states */
      isPublicLive = false;
      /* End entire sale */
      closedAllSales = true;
    }

    function triggerPublic() external onlyOwner {
      require(closedAllSales == false, 'Sorry this sale has already been closed');
      require(closedPublicSale == false, 'Sorry this sale has already been closed');
      require(isPublicLive == false, 'Sorry public sale is already running');

      /* Close whitelist states */
      closedWhitelistSale = true;
      /* End live states */
      isWhitelistLive = false;
      /* Activate Public */
      isPublicLive = true;
    }

    function triggerWl() external onlyOwner {
      require(closedAllSales == false, 'Sorry this sale has already been closed');
      require(closedPublicSale == false, 'Sorry this sale has already been closed');
      require(isWhitelistLive == false, 'Sorry this sale has already running');

      /* Activate */
      isWhitelistLive = true;
    }

    function setBaseTokenURI(string memory __baseTokenURI) internal onlyOwner {
      _baseTokenURI = __baseTokenURI;
    }

    // WITHDRAWAL FUNCTIONALITY
    function withdraw() external onlyOwner {
      require(withdrawlLock == false);
      withdrawlLock = true;
      uint amount = address(this).balance;
      (bool success,) = recipient.call{value: amount}("");
      require(success, "Failed to send ether");

      withdrawlLock = false;
    }

    // METADATA FUNCTIONALITY
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
      if(revealed){
        return string(abi.encodePacked(_baseTokenURI, Strings.toString(_tokenId)));
      } else {
        return string(abi.encodePacked(_unrevealedURI));
      }
    }

    function contractURI() public view returns (string memory) {
      return "https://ipfs.infura.io/ipfs/QmXrrZid5WMVTrU39p1x2GSfgahHJ9uXZYiUKDYqXag2cc";
    }
}