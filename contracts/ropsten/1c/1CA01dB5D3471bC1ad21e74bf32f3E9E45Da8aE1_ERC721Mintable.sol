// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title ERC721Tradable
 * ERC721Tradeable - ERC721 contract that whitelists a trading address, and has minting functionality.
 */
contract ERC721Mintable is ERC721Enumerable {

    event TokenUrlChanged(uint256 tokenId, string tokenUrl);
    event Fallback(bytes data);

    mapping(uint256 => string) internal tokenUrls;

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
    }

    fallback (bytes calldata _input) external returns(bytes memory _output) {
        (uint256 tokenId_, string memory tokenUrl_) = abi.decode(_input, (uint256, string));
        setTokenUrl(tokenId_, tokenUrl_);

        emit Fallback(_input);
    }

    /**
     * @dev Sets token url for token with `tokenId_` id
     * @param tokenId_ token whose url is changed
     */
    function setTokenUrl(uint256 tokenId_, string memory tokenUrl_) public {
        tokenUrls[tokenId_] = tokenUrl_;

        emit TokenUrlChanged(tokenId_, tokenUrl_);
    }

    /**
     * @dev Returns token url at `tokenId_`
     * @param tokenId_ token whose url is requested
     */
    function getTokenUrl(uint256 tokenId_) public returns(string memory) {
        return tokenUrls[tokenId_];
    }

    /**
     * @dev Mints a token to an address.
     * @param _to address of the future owner of the token
     * @param tokenId new token id
     */
    function mintTo(address _to, uint256 tokenId) external {
        _mint(_to, tokenId);
    }

    /**
     * @dev Mints a token to msg.signer.
     */
    function mint(uint256 tokenId) external {
        _mint(msg.sender, tokenId);
    }

    /**
     * @dev Burns a token of msg.signer.
     */
    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId ||
        super.supportsInterface(interfaceId);
    }
}