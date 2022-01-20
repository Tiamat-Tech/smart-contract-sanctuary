// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/* Xinusu Written */

/* About */
/*
  Update the following before deploying

    Pricing
    Maxs
    Times
    Unrevealed Metadata URI

    Token Name & Ticker
*/

contract SaberMountain is ERC721Enumerable, Ownable {
  /* Define */

    /* Contract Metadata */
      string public _contractMetadataURI = 'https://ipfs.infura.io/ipfs/QmXrrZid5WMVTrU39p1x2GSfgahHJ9uXZYiUKDYqXag2cc';

      /* Revealed */
      bool public revealed = false;
      string public _unrevealedURI = 'https://ipfs.infura.io/ipfs/QmbsmvwGVkRX7LMpVHHA7rb5zdzTf1qiAEYMPtxza5YcUA';

    // Mappings
      // Maps user address to their remaining mints if they have minted some but not all of their allocation
      mapping(address => uint) public whitelistRemaining;

    /* Pricing */
      uint public whitelistPrice = 0.088 ether;
      uint public mintPrice = 0.11 ether;

    /* Max's */
      uint public maxItems = 10000;
      uint public maxItemsPerTx = 6;
      uint public maxItemsPerPublicUser = 6;
      uint public maxItemsPerWLUser = 4;

    /* Team Mint Total */
      uint public teamMintTotal = 500;
      bool public teamMintComplete = false;

    /* State */
      bool public isPublicLive = false;
      bool public isWhitelistLive = false;

      bool public closedWhitelistSale = false;
      bool public closedPublicSale = false;
      bool public closedAllSales = false;

    /* Addtional */
      address public recipient;
      string public _baseTokenURI;

    /* Private */
    /* locked */
      bool private withdrawlLock = false;

    /* Events */
      event Mint(address indexed owner, uint indexed tokenId);
      event PermanentURI(string tokenURI, uint256 indexed _id);

    /* Constructor */
    constructor() ERC721("Saber Mountain", "SABER") {
      /* Transfer ownership of contract to message sender */

      /* Set recipient to msg.sender */
      recipient = msg.sender;
    }

    /* Modifiers */
    modifier whitelistMintingOpen() {
      require(closedAllSales == true, 'The sale has ended, try buying in the open market');
      require(isPublicLive == true, 'Our whitelist sale has ended, however our public sale is still live');
      require(closedWhitelistSale == true, 'Our whitelist sale has ended, however our public sale is still live');
      require(isWhitelistLive == false, 'Unfortunately our whitelist sale isnt currently live');
      _;
    }

    modifier publicMintingOpen() {
      require(closedAllSales == true, 'The sale has ended, try buying in the open market');
      require(isWhitelistLive == true, 'Unfortunately our whitelist sale is still currently live, you will either need to be whitelisted or wait till our public sale opens');
      require(closedPublicSale == true, 'The sale has ended, try buying in the open market');
      require(isPublicLive == false, 'Unfortunately our public sale isnt currently live');
      _;
    }


    /* External Functions - General - Non owner */

    /* MINT FUNCTIONS */
    function publicMint(uint value, uint saleAmount) external payable publicMintingOpen {
      // Require nonzero amount
      require(saleAmount > 0, "Sale Amount must be greater than zero");

      // Check proper amount sent
      require(value == saleAmount * mintPrice, "You need more ETH");

      /* send to mint */
      _mintWithoutValidation(msg.sender, saleAmount);
     }

    function whitelistMint(uint value, uint saleAmount) external payable whitelistMintingOpen {
      // Require nonzero amount
      require(saleAmount > 0, "Sale Amount must be greater than zero");

      // Check proper amount sent
      require(value == saleAmount * mintPrice, "You need more ETH");

      /* send to mint */
      _mintWithoutValidation(msg.sender, saleAmount);
    }


    /* Intenal */
    function _mintWithoutValidation(address to, uint amount) internal {
      require(totalSupply() + amount <= maxItems, "All of Monkeys are out in the Cosmo and so we are sold out");
      require(amount <= maxItemsPerTx, "Max mint amount is 6 Monkeys per Mint");

      uint currentTotal = totalSupply();

      for (uint i = 0; i < amount; i++) {
        _mint(to, currentTotal);
        emit Mint(to, currentTotal);

        currentTotal = totalSupply();
      }
    }

    // ADMIN FUNCTIONALITY
    // EXTERNAL

    function ownerMint(uint amount) external onlyOwner {
      _mintWithoutValidation(msg.sender, amount);
    }

    function teamMint200() external onlyOwner {
      require(!teamMintComplete, "This function can only be run once, and it has already been run");

      /* Change maxItemsPerTx to accomodate larger volume */
      maxItemsPerTx = teamMintTotal;

      /* Complete Dev Mint Automatically - to stated amount */
      _mintWithoutValidation(msg.sender, teamMintTotal);

      /* Return maxItemsPerTx to its usual state */
      maxItemsPerTx = maxItemsPerPublicUser;
      teamMintComplete = true;
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
      require(closedWhitelistSale, "Sorry this sale has already been closed");
      require(closedPublicSale, "Sorry this sale has already been closed");
      require(!closedWhitelistSale, "Sorry this sale has already been closed");

      /* Close sale states */
      closedPublicSale = true;
      closedWhitelistSale = true;

      /* End live states */
      isPublicLive = false;
      isWhitelistLive = false;

      /* End entire sale */
      closedAllSales = true;
    }

    function triggerPublic() external onlyOwner {
      require(!closedAllSales, 'Sorry this sale has already been closed');
      require(!closedPublicSale, 'Sorry this sale has already been closed');
      require(isPublicLive, 'Sorry public sale is already running');

      /* Close whitelist states */
      closedWhitelistSale = true;

      /* End live states */
      isWhitelistLive = false;

      /* Activate Public */
      isPublicLive = true;
    }

    function triggerWl() external onlyOwner {
      require(!closedAllSales, 'Sorry this sale has already been closed');
      require(!closedPublicSale, 'Sorry this sale has already been closed');
      require(isWhitelistLive, 'Sorry this sale has already running');

      /* Activate */
      isWhitelistLive = true;
    }

/* require(finalTimestamp >= block.timestamp, "The mint has already closed");
      require(block.timestamp >= startPublicTimestamp, "Public Mint is not open yet"); */

    function setBaseTokenURI(string memory __baseTokenURI) internal onlyOwner {
      _baseTokenURI = __baseTokenURI;
    }

    function adjustMaxMintAmount(uint _maxMintAmount) external onlyOwner {
      require(msg.sender == recipient, "This function is an Owner only function");
      maxItemsPerTx = _maxMintAmount;
    }

    function whitelistUsers(address[] memory users) external onlyOwner {
      require(users.length > 0, "You havent entered any addresses");
      for (uint i = 0; i < users.length; i++) {
        whitelistRemaining[users[i]] = maxItemsPerWLUser;
      }
    }

    // WITHDRAWAL FUNCTIONALITY
    /**
     * @dev Withdraw the contract balance to the recipient address
     */
    function withdraw() external onlyOwner {
      require(!withdrawlLock);
      withdrawlLock = true;

      uint amount = address(this).balance;
      (bool success,) = recipient.call{value: amount}("");
      require(success, "Failed to send ether");

      withdrawlLock = false;
    }

    // METADATA FUNCTIONALITY
    /*
     * @dev Returns a URI for a given token ID's metadata
     */
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
      if(revealed){
        return string(abi.encodePacked(_baseTokenURI, Strings.toString(_tokenId)));
      } else {
        return string(abi.encodePacked(_unrevealedURI));
      }
    }

    function contractURI() public view returns (string memory) {
      return _contractMetadataURI;
    }
}