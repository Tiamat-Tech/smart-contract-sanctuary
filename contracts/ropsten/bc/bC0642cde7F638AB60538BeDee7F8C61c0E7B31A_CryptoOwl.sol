// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./ICryptoOwl.sol";
import "./ICryptoOwlCollection.sol";
import "./ICryptoOwlGuardian.sol";

contract CryptoOwl is ERC721, Ownable, ERC721Enumerable, ICryptoOwl {
    using Counters for Counters.Counter;
    using Address for address;

    string baseURI;
    address guardianContractAddress;
    address collectionContractAddress;

    Counters.Counter private _nextTokenId;

    mapping(uint256 => Metadata) public metadatas;
    mapping(uint256 => MetadataAppraisal) public suggestedMetadataChanges;
    mapping(uint256 => address) public changeSuggestedBy;

    constructor() ERC721("Crypto Owls", "COC") {
        _nextTokenId.increment();
    }

    /**
     * @notice Require that the token has not been burned and has been minted
     */
    modifier onlyExistingToken(uint256 tokenId) {
        require(_exists(tokenId), "CryptoOwl: nonexistent token");
        _;
    }

    /**
     * @notice Ensure that the provided spender is the approved or the owner of
     * the media for the specified tokenId
     */
    modifier onlyApprovedOrOwner(address spender, uint256 tokenId) {
        require(
            _isApprovedOrOwner(spender, tokenId),
            "CryptoOwl: Only approved or owner"
        );
        _;
    }

    modifier onlyGuardian() {
        require(
            ICryptoOwlGuardian(guardianContractAddress).isGuardian(
                _msgSender()
            ),
            "CryptoOwl: only a guardian can call this method"
        );
        _;
    }

    modifier onlyGovernor() {
        require(
            ICryptoOwlGuardian(guardianContractAddress).isGovernor(
                _msgSender()
            ),
            "CryptoOwl: only a governor can call this method"
        );
        _;
    }

    function setGuardianAddress(address _guardian) external override onlyOwner {
        require(_guardian.isContract(), "CryptoOwl: invalid contract address");
        guardianContractAddress = _guardian;
    }

    function setCollectionContract(address _collection)
        external
        override
        onlyOwner
    {
        require(
            _collection.isContract(),
            "CryptoOwl: invalid  collection contract address"
        );
        collectionContractAddress = _collection;
    }

    function baseTokenURI() public view returns (string memory) {
        return baseURI;
    }

    function setBaseTokenURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
        metadatas[tokenId].currentOwner = to;
        metadatas[tokenId].ownershipConfirmedBy = address(0);
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
            uint256 tokenId = ERC721Enumerable.tokenOfOwnerByIndex(account, i);
            tokenIds[i] = tokenId;
        }
        return tokenIds;
    }

    function mintToken(
        address user,
        MetadataBasicInfo calldata basicInfo,
        MetadataAppraisal calldata appraisal
    ) public override returns (uint256) {
        require(
            (user == _msgSender() || _msgSender() == owner()),
            "CryptoOwl: cannot mint to other user"
        );

        Metadata memory metadata = Metadata(
            basicInfo,
            appraisal,
            address(0),
            user,
            address(0),
            address(0),
            address(0)
        );

        uint256 tokenId = _nextTokenId.current();
        _nextTokenId.increment();

        if (metadata.basicInfo.collectionId > 0) {
            ICryptoOwlCollection(collectionContractAddress)
                .addTokenToCollection(
                    tokenId,
                    metadata.basicInfo.collectionId,
                    metadata.basicInfo.serialNumber
                );
        }
        metadatas[tokenId] = metadata;
        _safeMint(user, tokenId);
        return tokenId;
    }

    function getTokenMetadata(uint256 tokenId)
        external
        view
        override
        onlyExistingToken(tokenId)
        returns (Metadata memory)
    {
        return metadatas[tokenId];
    }

    function confirmOwnerShip(uint256 tokenId)
        external
        override
        onlyGovernor
        onlyExistingToken(tokenId)
    {
        metadatas[tokenId].ownershipConfirmedBy = _msgSender();
        emit OwnershipConfirmed(tokenId, _msgSender());
    }

    function confirmAppraisal(uint256 tokenId)
        external
        override
        onlyGovernor
        onlyExistingToken(tokenId)
    {
        metadatas[tokenId].appraisalConfirmedBy = _msgSender();
        emit AppraisalConfirmed(tokenId, _msgSender());
    }

    function confirmPopProvided(uint256 tokenId)
        external
        override
        onlyGovernor
        onlyExistingToken(tokenId)
    {
        metadatas[tokenId].popConfirmedBy = _msgSender();
        emit PopConfirmed(tokenId, _msgSender());
    }

    function suggestChange(
        uint256 tokenId,
        MetadataAppraisal calldata appraisal
    ) external override {
        ICryptoOwlGuardian guardianContract = ICryptoOwlGuardian(
            guardianContractAddress
        );
        require(
            _msgSender() == ownerOf(tokenId) ||
                guardianContract.isCustodian(_msgSender()) ||
                guardianContract.isGovernor(_msgSender()),
            "CryptoOwl: no permission to suggest a metadata change"
        );
        changeSuggestedBy[tokenId] = _msgSender();
        suggestedMetadataChanges[tokenId] = appraisal;
        emit AppraisalChangeSuggested(tokenId);
    }

    function confirmAppraisalSuggest(uint256 tokenId)
        external
        override
        onlyGovernor
    {
        require(
            _msgSender() != changeSuggestedBy[tokenId],
            "CryptoOwl: cannot confirm a change suggested by urself"
        );
        metadatas[tokenId].appraisalConfirmedBy = _msgSender();
        changeSuggestedBy[tokenId] = address(0);
        delete suggestedMetadataChanges[tokenId];
        emit AppraisalConfirmed(tokenId, _msgSender());
    }
}