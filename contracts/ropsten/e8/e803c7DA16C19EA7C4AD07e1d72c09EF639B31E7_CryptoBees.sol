//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

// import "./WOOL.sol";

contract CryptoBees is ERC721, Ownable, Pausable {
  using Strings for uint256;

  // mint price ETH
  uint256 public constant MINT_PRICE = .02 ether;
  // mint price HONEY
  uint256 public constant MINT_PRICE_HONEY = 3000 ether;
  // mint price WOOL
  uint256 public constant MINT_PRICE_WOOL = 3000 ether;
  // mint price ETH discount
  uint256 public constant MINT_PRICE_DISCOUNT = .055 ether;

  address private constant BEEKEEPER_1 = 0xA6b42f9D0eb06AA40FcAa2E368cED1A8aa6761b5;
  address private constant BEEKEEPER_2 = 0x55Cb7Cf904070e41441BC8c981fDE03Cea42585d;
  address private constant BEEKEEPER_3 = 0xF40d7CdE92Bc1C3CE72bC41E913e9Ba6023B9F37;

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

  function getTokenIds(address _owner) public view returns (uint256[] memory _tokensOfOwner) {
    _tokensOfOwner = new uint256[](balanceOf(_owner));
    for (uint256 i; i < balanceOf(_owner); i++) {
      _tokensOfOwner[i] = tokenOfOwnerByIndex(_owner, i);
    }
  }

  // function tokenURI(uint256 tokenId) public view override returns (string memory) {
  //   require(_exists(tokenId), 'ERC721Metadata: URI query for nonexistent token');
  //   return 'https://gateway.pinata.cloud/ipfs/QmVPMv3Kxg94vAJo4fQY2FGnYTYp4RM1dq7anwr9psbz9P';
  // }
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    string memory metadata = string(
      abi.encodePacked(
        '{"name": "Bear #',
        uint256(tokenId).toString(),
        '", "type": "bear',
        '", "description": "Not too long ago, people realized that the path to prosperity is to relocate to a farm. Some bought sheep, some land but many ended up with nothing.',
        '","image": "ipfs://QmVPMv3Kxg94vAJo4fQY2FGnYTYp4RM1dq7anwr9psbz9P"}"'
      )
    );

    return string(abi.encodePacked('data:application/json;base64,', _base64(bytes(metadata))));
  }

  string internal constant TABLE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

  function _base64(bytes memory data) internal pure returns (string memory) {
    if (data.length == 0) return '';

    // load the table into memory
    string memory table = TABLE;

    // multiply by 4/3 rounded up
    uint256 encodedLen = 4 * ((data.length + 2) / 3);

    // add some extra buffer at the end required for the writing
    string memory result = new string(encodedLen + 32);

    // solhint-disable-next-line no-inline-assembly
    assembly {
      // set the actual output length
      mstore(result, encodedLen)

      // prepare the lookup table
      let tablePtr := add(table, 1)

      // input ptr
      let dataPtr := data
      let endPtr := add(dataPtr, mload(data))

      // result ptr, jump over length
      let resultPtr := add(result, 32)

      // run over the input, 3 bytes at a time
      for {

      } lt(dataPtr, endPtr) {

      } {
        dataPtr := add(dataPtr, 3)

        // read 3 bytes
        let input := mload(dataPtr)

        // write 4 characters
        mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(18, input), 0x3F)))))
        resultPtr := add(resultPtr, 1)
        mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(12, input), 0x3F)))))
        resultPtr := add(resultPtr, 1)
        mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(6, input), 0x3F)))))
        resultPtr := add(resultPtr, 1)
        mstore(resultPtr, shl(248, mload(add(tablePtr, and(input, 0x3F)))))
        resultPtr := add(resultPtr, 1)
      }

      // padding with '='
      switch mod(mload(data), 3)
      case 1 {
        mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
      }
      case 2 {
        mstore(sub(resultPtr, 1), shl(248, 0x3d))
      }
    }

    return result;
  }
}