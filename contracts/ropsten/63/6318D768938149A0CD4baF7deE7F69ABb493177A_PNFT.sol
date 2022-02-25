//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PNFT is 
    Context,
    AccessControl,
    ReentrancyGuard,
    ERC721,
    ERC721Pausable 
{
    using Counters for Counters.Counter;

    /*** Events ***/
    event PNFTMint (uint256 indexed tokenId, address indexed to, uint256 skuId, uint256 size, uint256 ctime);

    /*** Constants ***/
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /*** Storage Properties ***/

    struct PNFTMeta {
        uint256 skuId;
        uint256 size;
        uint256 ctime;
    }

    Counters.Counter private _tokenIdTracker;
    mapping(uint256 => PNFTMeta) public nftMeta;

    /*** Contract Logic Starts Here ***/

    constructor(
        address _admin
    ) ERC721("pNFT", "pNFT") {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    // ---------------------------------------------------------
    // Asset Mgr

    function mintPNFT(address to, uint256 skuId, uint256 size) external nonReentrant onlyRole(MINTER_ROLE) returns (uint256) {

        _tokenIdTracker.increment();
        uint256 newTokenId = _tokenIdTracker.current();

        nftMeta[newTokenId] = PNFTMeta(skuId, size, block.timestamp);
        _mint(to, newTokenId);

        emit PNFTMint(newTokenId, to, skuId, size, block.timestamp);

        return newTokenId;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "PNFT: Nonexistent token");

        PNFTMeta memory meta = nftMeta[tokenId];

        return string(abi.encodePacked(
            "PNFT,", 
            Strings.toString(meta.skuId),
            ",",
            Strings.toString(meta.size),
            ",",
            Strings.toString(meta.ctime)
        ));
    }

    function getMeta(uint256 tokenId) public view returns (uint256 skuId, uint256 size, uint256 ctime) {
        PNFTMeta memory meta = nftMeta[tokenId];
        skuId = meta.skuId;
        size = meta.size;
        ctime = meta.ctime;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // ---------------------------------------------------------
    // Manage

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // ---------------------------------------------------------
    // MISC
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl, ERC721)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}