// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/IMedia.sol";
import "./interfaces/IMarket.sol";

contract Media is
    ERC721Enumerable,
    ERC721URIStorage,
    ERC721Burnable,
    Ownable,
    ReentrancyGuard,
    IMedia
{
    string baseURI;

    // Address for the market
    address public marketContract;

    mapping(uint256 => address) public tokenCreators;

    // Mapping from creator address to their (enumerable) set of created tokens
    mapping(address => EnumerableSet.UintSet) private _creatorTokens;

    // Counters.Counter private _tokenIdTracker;

    constructor(address marketContractAddr) ERC721("OpenOasis", "OpenOasis") {
        baseURI = "ipfs://";
        marketContract = marketContractAddr;
    }

    /**
     * @notice Require that the token has not been burned and has been minted
     */
    modifier onlyExistingToken(uint256 tokenId) {
        require(_exists(tokenId), "Media: nonexistent token");
        _;
    }

    /**
     * @notice Ensure that the provided spender is the approved or the owner of
     * the media for the specified tokenId
     */
    modifier onlyApprovedOrOwner(address spender, uint256 tokenId) {
        require(
            _isApprovedOrOwner(spender, tokenId),
            "Media: Only approved or owner"
        );
        _;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @notice transfer a token and remove the ask for it.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        IMarket(marketContract).removeAsk(tokenId);

        super._transfer(from, to, tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function tokenIdsByOwner(address account)
        external
        view
        returns (uint256[] memory)
    {
        uint256 count = ERC721.balanceOf(account);

        uint256[] memory tokenIds = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(account, i);
            tokenIds[i] = tokenId;
        }
        return tokenIds;
    }

    function mintToken(
        address user,
        string memory metadataURI,
        uint256 amount
    ) public returns (uint256) {
        require((user == _msgSender() || _msgSender() == owner()));
        uint256 id = totalSupply() + 1;
        _safeMint(user, id);
        _setTokenURI(id, metadataURI);
        tokenCreators[id] = user;
        setAsk(id, amount);
        return id;
    }

    function burnToken(uint256 tokenId)
        external
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        address owner = ownerOf(tokenId);

        require(
            tokenCreators[tokenId] == owner,
            "Media: owner is not creator of media"
        );

        _burn(tokenId);
    }

    /**
     * @notice see IMedia
     * @dev only callable by approved or owner
     */
    function updateTokenURI(uint256 tokenId, string calldata _tokenURI)
        external
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        _setTokenURI(tokenId, _tokenURI);
        emit TokenURIUpdated(tokenId, msg.sender, _tokenURI);
    }

    /**
     * @notice see IMedia
     */
    function auctionTransfer(uint256 tokenId, address recipient)
        external
        override
    {
        require(msg.sender == marketContract, "Media: only market contract");
        // previousTokenOwners[tokenId] = ownerOf(tokenId);
        _safeTransfer(ownerOf(tokenId), recipient, tokenId, "");
    }

    /**
     * @notice see IMedia
     */
    function setAsk(uint256 tokenId, uint256 amount)
        public
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        IMarket(marketContract).setAsk(tokenId, amount);
    }

    /**
     * @notice see IMedia
     */
    function removeAsk(uint256 tokenId)
        external
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        IMarket(marketContract).removeAsk(tokenId);
    }

    /**
     * @notice see IMedia
     */
    function setBid(uint256 tokenId, IMarket.Bid memory bid)
        public
        payable
        override
        nonReentrant
        onlyExistingToken(tokenId)
    {
        require(msg.sender == bid.bidder, "Media: Bidder must be msg sender");
        IMarket(marketContract).setBid{value: msg.value}(tokenId, bid);
    }

    /**
     * @notice see IMedia
     */
    function removeBid(uint256 tokenId) external override nonReentrant {
        IMarket(marketContract).removeBid(tokenId, msg.sender);
    }

    /**
     * @notice see IMedia
     */
    function acceptBid(uint256 tokenId, IMarket.Bid memory bid)
        public
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        IMarket(marketContract).acceptBid(tokenId, bid);
    }

    /**
     * @notice Burn a token.
     * @dev Only callable if the media owner is also the creator.
     */
    function burn(uint256 tokenId)
        public
        override
        nonReentrant
        onlyExistingToken(tokenId)
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        address owner = ownerOf(tokenId);

        require(
            tokenCreators[tokenId] == owner,
            "Media: owner is not creator of media"
        );

        _burn(tokenId);
    }

    /**
     * @notice Revoke the approvals for a token. The provided `approve` function is not sufficient
     * for this protocol, as it does not allow an approved address to revoke it's own approval.
     * In instances where a 3rd party is interacting on a user's behalf via `permit`, they should
     * revoke their approval once their task is complete as a best practice.
     */
    function revokeApproval(uint256 tokenId) external override nonReentrant {
        require(
            msg.sender == getApproved(tokenId),
            "Media: caller not approved address"
        );
        _approve(address(0), tokenId);
    }
}