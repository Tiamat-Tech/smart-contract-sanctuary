// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Cryptotchi is ERC721PresetMinterPauserAutoId {
    using SafeMath for uint256;

    /**
     * @dev Emitted when `tokenId` is assigned `amount` ETH from address `from`.
     */
    event CryptotchiFeed(address indexed from, uint256 indexed tokenId, uint256 amount);

    /**
     * @dev Emitted when address `from` withdraws `amount` ETH from `tokenId` to address `to`.
     */
    event CryptotchiWithdraw(address indexed from, address indexed to, uint256 tokenId, uint256 amount);

    // This role allows an address to change the _baseTokenURI variable for generating token URIs
    bytes32 public constant URI_ROLE = keccak256("URI_ROLE");

    // This variable overrides the _baseTokenURI variable of ERC721PresetMinterPauserAutoId and provides the same functionality.
    string private _baseTokenURI;

    // Mapping from token ID to ETH balance for each token ID. Default initialized value is 0.
    mapping (uint256 => uint256) private _tokenIdBalance;

    /**
     * @dev See {ERC721PresetMinterPauserAutoId-constructor} to see most of what is done here.
     * The only additional functionality present here is to add the URI_ROLE to the deployer of this
     * smart contract, and to set our own _baseTokenURI to be used in our _baseURI and setBaseURI functions.
     */
    constructor(string memory name, string memory symbol, string memory baseTokenURI) ERC721PresetMinterPauserAutoId(name, symbol, baseTokenURI) {
        _baseTokenURI = baseTokenURI;
        _setupRole(URI_ROLE, _msgSender());
    }

    /**
     * @dev Overrides ERC721PresetMinterPauserAutoId's _baseURI() function to allow setBaseURI to work.
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Sets the base URI for tokens to something new - only a sender who has
     * a URI_ROLE associated with their address can invoke this function.
     */
    function setBaseURI(string memory baseTokenURI) public {
        require(hasRole(URI_ROLE, _msgSender()), "Cryptotchi: must have uri role to set base uri");
        _baseTokenURI = baseTokenURI;
    }

    /**
     * @dev Returns the ETH balance of a given tokenId.
     *
     * Requirements:
     * - `tokenId` must exist.
     */
    function balanceOfTokenId(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId), "Cryptotchi: tokenId does not exist for balanceOfTokenId call");
        return _tokenIdBalance[tokenId];
    }

    /**
     * @dev Stores ETH inside the smart contract and associates it with a given Cryptotchi.
     *
     * Requirements:
     * - `tokenId` must exist.
     *
     * Emits a {CryptotchiFeed} event.
     */
    function feedCryptotchi(uint256 tokenId) external payable {
        require(_exists(tokenId), "Cryptotchi: tokenId does not exist for feedCryptotchi call");
        _tokenIdBalance[tokenId] = _tokenIdBalance[tokenId].add(msg.value);
        emit CryptotchiFeed(_msgSender(), tokenId, msg.value);
    }

    /**
     * @dev Withdraws a given amount of ETH from the smart contract associated with a given Cryptotchi.
     * Can only be called by the owner of the tokenId in question, and amount to withdraw must be less than
     * or equal to the amount of ETH associated with the given tokenId's Cryptotchi. Can send to any address
     * specified as the `to` argument.
     *
     * Requirements:
     * - `tokenId` must exist (requirement of _isApprovedOrOwner).
     * - Sender must be owner of or approved for `tokenId`.
     * - `amount` must be less than or equal to the amount owned by the token, i.e. `_tokenIdBalance[tokenId]`
     *
     * Emits a {CryptotchiWithdraw} event.
     */
    function withdrawEthFromCryptotchi(address to, uint256 tokenId, uint256 amount) external {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Cryptotchi: withdraw caller is not owner of or approved to operate on this token");
        require(amount <= _tokenIdBalance[tokenId], "Cryptotchi: withdraw amount is greater than amount owned by token");
        address payable recipient = payable(to);
        recipient.transfer(amount);
        _tokenIdBalance[tokenId] = _tokenIdBalance[tokenId].sub(amount);
        emit CryptotchiWithdraw(_msgSender(), to, tokenId, amount);
    }
}