// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract SplytLineNFT is ERC721Enumerable, Ownable {
  using Strings for uint256;
  using Counters for Counters.Counter;
  IERC20 private _token; // The token to be used in this smart contract
  uint256 maxSupply;     // Maximum supply of NFT
  uint256 minTokens;     // Minimum tokens required to mint NFTs

  /*
  * We rely on the OZ Counter util to keep track of the next available ID.
  * We track the nextTokenId instead of the currentTokenId to save users on gas costs. 
  * Read more about it here: https://shiny.mirror.xyz/OUampBbIz9ebEicfGnQf5At_ReMHlZy0tB4glb9xQ0E
  */ 
  Counters.Counter private _nextTokenId;

  // Base URI
  string private baseURI;

  // Mapping from tokenIDs to token URIs
  mapping(uint256 => string) private _tokenURIs;

  constructor (address token, string memory name, string memory symbol, uint256 _maxSupply, uint256 _minTokens) ERC721(name, symbol) {
    _token = IERC20(token);
    maxSupply = _maxSupply;
    minTokens = _minTokens;
    // nextTokenId is initialized to 1, since starting at 0 leads to higher gas cost for the first minter
    _nextTokenId.increment();
  }

  // -----------------------------------------------------------------------
  // SETTERS
  // -----------------------------------------------------------------------

  function updateMinTokens(uint256 _minTokens) onlyOwner external {
    require(_minTokens >= 0, "MinTokens: minimum tokens must be a positive number");
    minTokens = _minTokens;
  }

  function updateMaxSupply(uint256 _maxSupply) onlyOwner external {
    // new max supply > current supply
    require(_maxSupply > totalSupply(), "MaxSupply: _maxSupply must be greater than the current totalSupply");
    maxSupply = _maxSupply;
  }

  function setTokenURI(uint256 tokenId, string memory _tokenURI) onlyOwner external {  
    _setTokenURI(tokenId, _tokenURI);
  }


  // -----------------------------------------------------------------------
  // GETTERS
  // -----------------------------------------------------------------------


  /**
    * @dev See {IERC721Metadata-tokenURI}.
    */
  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    require(_exists(tokenId), "ERC721URIStorage: URI query for nonexistent token");

    string memory _tokenURI = _tokenURIs[tokenId];
    string memory base = _baseURI();

    // If there is no base URI, return the token URI.
    if (bytes(base).length == 0) {
        return _tokenURI;
    }
    // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
    if (bytes(_tokenURI).length > 0) {
        return string(abi.encodePacked(base, _tokenURI));
    }

    return super.tokenURI(tokenId);
  }

  function tokensOfOwner(address owner) external view returns (uint256[] memory tokens) {
    uint256[] memory _tokens = new uint256[](balanceOf(owner));
    for (uint256 i = 0; i < _tokens.length; i++) {
      _tokens[i] = tokenOfOwnerByIndex(owner, i);
    }
    return _tokens;
  }

  function exists(uint256 tokenId) public view returns (bool) {
    return _exists(tokenId);
  }  

  /**
    * @dev Returns the base URI set via {_setBaseURI}. This will be
    * automatically added as a prefix in {tokenURI} to each token's URI, or
    * to the token ID if no specific URI is set for that token ID.
    */
  function getBaseURI() public view virtual returns (string memory) {
      return baseURI;
  } 

  /**
      @dev Returns the total tokens minted so far.
      1 is always subtracted from the Counter since it tracks the next available tokenId.
    */
  function totalSupply() override public view returns (uint256) {
    return _nextTokenId.current() - 1;
  }

  /**
 * @dev Gets info about line nft
 * @return _maxSupply Max supply of line NFTs
 * @return _totalSupply Total supply of line NFTs minted so far
 * @return _minTokens Minimum tokens required to mint line NFTs
 */
  function getInfo() public view returns (uint256 _maxSupply, uint256 _totalSupply, uint256 _minTokens) {
    return (
      maxSupply,
      totalSupply(),
      minTokens
    );
  }

  // -----------------------------------------------------------------------
  // NFT
  // -----------------------------------------------------------------------

  /**
    * @dev Mints a token to an address with a tokenURI.
    * @param to address of the future owner of the token
    */
  function mint(address to) public {
    require(_token.balanceOf(msg.sender) >= minTokens, "TokenBalance: User must hold the minimum tokens required to mint NFTs");
    uint256 currentTokenId = _nextTokenId.current();
    _nextTokenId.increment();
    _safeMint(to, currentTokenId);
  }

  function burn(uint256 tokenId) public {
    _burn(tokenId);
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /**
    * @dev function to set the base URI for all token IDs. It is
    * automatically added as a prefix to the value returned in {tokenURI},
    * or to the token ID if {tokenURI} is empty.
    */   
  function _setBaseURI(string memory baseURI_) internal virtual {
    baseURI = baseURI_;
  }

  /**
    * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
    *
    * Requirements:
    *
    * - `tokenId` must exist.
    */
  function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
    require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
    _tokenURIs[tokenId] = _tokenURI;
  }

  /**
    * @dev Destroys `tokenId`.
    * The approval is cleared when the token is burned.
    *
    * Requirements:
    *
    * - `tokenId` must exist.
    *
    * Emits a {Transfer} event.
    */
  function _burn(uint256 tokenId) internal virtual override {
    super._burn(tokenId);

    // Remove tokenURI for the tokenID to be deleted
    if (bytes(_tokenURIs[tokenId]).length != 0) {
        delete _tokenURIs[tokenId];
    }
  }

  /**
    * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
    * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
    * by default, can be overriden in child contracts.
    */
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

}