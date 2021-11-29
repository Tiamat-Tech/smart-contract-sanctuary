//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Enumerable.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

// import "./WOOL.sol";

contract CryptoBees is ERC721, Ownable, Pausable {
  // mint price ETH
  uint256 public constant MINT_PRICE = .02 ether;
  // mint price HONEY
  uint256 public constant MINT_PRICE_HONEY = 3000 ether;
  // mint price WOOL
  uint256 public constant MINT_PRICE_WOOL = 3000 ether;
  // mint price ETH discount
  uint256 public constant MINT_PRICE_DISCOUNT = .055 ether;

  address public constant BEEKEEPER_1 = 0xA6b42f9D0eb06AA40FcAa2E368cED1A8aa6761b5;
  address public constant BEEKEEPER_2 = 0x55Cb7Cf904070e41441BC8c981fDE03Cea42585d;
  address public constant BEEKEEPER_3 = 0xF40d7CdE92Bc1C3CE72bC41E913e9Ba6023B9F37;

  // max number of tokens that can be minted - 40000 in production
  uint256 public constant MAX_TOKENS = 40000;
  // number of tokens that can be claimed for free - 25% of MAX_TOKENS
  uint256 public constant PAID_TOKENS = 10000;
  // number of tokens have been minted so far
  uint16 public minted;

  /// @notice whitelisted addresses
  mapping(address => bool) public whitelisted;

  /// @notice controls if mintWithEthPresale is paused
  bool public mintWithEthPresalePaused = true;
  /// @notice controls if mintWithEth is paused
  bool public mintWithEthPaused = true;
  /// @notice controls if mintFromController is paused
  bool public mintFromControllerPaused = true;
  /// @notice controls if token reveal is paused
  bool public revealPaused = true;

  // mapping from tokenId to a struct containing the token's traits
  // mapping(uint256 => SheepWolf) public tokenTraits;
  // mapping from hashed(tokenTrait) to the tokenId it's associated with
  // used to ensure there are no duplicates
  // mapping(uint256 => uint256) public existingCombinations;
  // list of probabilities for each trait type
  // 0 - 9 are associated with Sheep, 10 - 18 are associated with Wolves
  // uint8[][18] public rarities;
  // list of aliases for Walker's Alias algorithm
  // 0 - 9 are associated with Sheep, 10 - 18 are associated with Wolves
  // uint8[][18] public aliases;

  // reference to the Barn for choosing random Wolf thieves
  // IBarn public barn;
  // reference to $WOOL for burning on mint
  // WOOL public wool;
  // reference to Traits
  // ITraits public traits;

  // function mintNFT(address recipient, string memory tokenURI)
  //     public onlyOwner
  //     returns (uint256)
  // {
  //     _tokenIds.increment();

  //     uint256 newItemId = _tokenIds.current();
  //     _mint(recipient, newItemId);
  //     _setTokenURI(newItemId, tokenURI);

  //     return newItemId;
  // }

  /**
   * instantiates contract and rarity tables
   */
  constructor() ERC721('CryptoBees Game', 'CRYPTOBEES') {}

  /**
   * mint a token - 90% Sheep, 10% Wolves
   * The first 20% are free to claim, the remaining cost $WOOL
   */
  function mint(uint256 amount, bool stake) external payable whenNotPaused {
    require(tx.origin == _msgSender(), 'Only EOA');
    require(minted + amount <= MAX_TOKENS, 'All tokens minted');
    require(amount > 0 && amount <= 10, 'Invalid mint amount');
    if (minted < PAID_TOKENS) {
      require(minted + amount <= PAID_TOKENS, 'All tokens on-sale already sold');
      require(amount * MINT_PRICE == msg.value, 'Invalid payment amount');
    } else {
      require(msg.value == 0);
    }

    for (uint256 i = 0; i < amount; i++) {
      minted++;
      _safeMint(_msgSender(), minted);
    }
  }

  /**
   * set whitelist addresses
   */
  function setWhitelist(address[] calldata addresses) external onlyOwner {
    for (uint256 i = 0; i < addresses.length; i++) {
      address who = addresses[i];
      whitelisted[who] = true;
    }
  }

  function transferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override {
    _transfer(from, to, tokenId);
  }

  function isWhitelisted(address who) external view returns (bool) {
    return whitelisted[who];
  }

  function withdrawAll() public onlyOwner {
    uint256 balance = address(this).balance;
    require(balance > 0, 'Insufficent balance');
    _widthdraw(BEEKEEPER_1, ((balance * 50) / 100));
    _widthdraw(BEEKEEPER_2, ((balance * 25) / 100));
    _widthdraw(BEEKEEPER_3, ((balance * 25) / 100));
  }

  function _widthdraw(address _address, uint256 _amount) private {
    (bool success, ) = _address.call{ value: _amount }('');
    require(success, 'Failed to widthdraw Ether');
  }

  /**
   * updates the number of tokens for sale
   */
  // function setPaidTokens(uint256 _paidTokens) external onlyOwner {
  //   PAID_TOKENS = _paidTokens;
  // }

  /**
   * enables owner to pause / unpause minting
   */
  function setPaused(bool _paused) external onlyOwner {
    if (_paused) _pause();
    else _unpause();
  }

  /** RENDER */

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), 'ERC721Metadata: URI query for nonexistent token');
    return tokenURI(tokenId);
  }
}