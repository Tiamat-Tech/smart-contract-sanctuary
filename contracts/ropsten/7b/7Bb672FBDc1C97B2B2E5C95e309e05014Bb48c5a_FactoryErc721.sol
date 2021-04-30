// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "openzeppelin-solidity/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-solidity/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "openzeppelin-solidity/contracts/access/AccessControl.sol";
import "openzeppelin-solidity/contracts/utils/cryptography/ECDSA.sol";

contract ERC721Main is
    ERC721Burnable,
    ERC721Enumerable,
    ERC721URIStorage,
    AccessControl
{
    bytes32 public SIGNER_ROLE = keccak256("SIGNER_ROLE");

    string public baseURI;

    address public factory;
    
    address private exchange;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory baseURI_,
        address _exchange,
        address signer
    ) ERC721(_name, _symbol) {
        factory = _msgSender();
        exchange = _exchange;
        baseURI = baseURI_;
        _setupRole(DEFAULT_ADMIN_ROLE, signer);
        _setupRole(SIGNER_ROLE, signer);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        ERC721._beforeTokenTransfer(from, to, tokenId);
        ERC721Enumerable._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        virtual
        override(ERC721, ERC721URIStorage)
    {
        ERC721URIStorage._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return
            ERC721.supportsInterface(interfaceId) ||
            ERC721Enumerable.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return ERC721URIStorage.tokenURI(tokenId);
    }

    function mint(
        uint256 tokenId,
        string calldata _tokenURI,
        bytes calldata signature
    ) external {
        _verifySigner(tokenId, signature);
        _safeMint(_msgSender(), tokenId);
        _setTokenURI(tokenId, _tokenURI);
        _approve(exchange, tokenId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function _verifySigner(uint256 id, bytes calldata signature) private view {
        address signer =
            ECDSA.recover(keccak256(abi.encodePacked(this, id)), signature);
        require(
            hasRole(SIGNER_ROLE, signer),
            "ERC721Main: Signer should sign transaction"
        );
    }
}