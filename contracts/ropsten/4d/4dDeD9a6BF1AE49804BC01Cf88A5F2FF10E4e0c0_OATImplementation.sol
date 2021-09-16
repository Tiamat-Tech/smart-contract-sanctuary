// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "../BaseRelayRecipient.sol";

// OAT SMART CONTRACT
contract OATImplementation is
    ERC721Upgradeable,
    OwnableUpgradeable,
    BaseRelayRecipient
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIds;
    mapping(string => bool) hashes;
    // user address => admin? mapping
    mapping(address => bool) private _admins;

    event AdminAccessSet(address _admin, bool _enabled);

    /**
     * This function acts as the constructor
     *
     */
    function initialize(address _trustedForwarder) external initializer {
        __Ownable_init();
        __ERC721_init("Original Art Token", "OAT");
        trustedForwarder = _trustedForwarder;
    }
    
    /**
     * Set Trusted Forwarder
     *
     * @param newTrustedForwarder - Address of Trusted Forwarder
     */
    function setTrustedForwarder(address newTrustedForwarder) external onlyAdmin {
        trustedForwarder = newTrustedForwarder;
    }

    /**
     * Set Admin Access
     *
     * @param admin - Address of Minter
     * @param enabled - Enable/Disable Admin Access
     */
    function setAdmin(address admin, bool enabled) external onlyOwner {
        _admins[admin] = enabled;
        emit AdminAccessSet(admin, enabled);
    }

    /**
     * Check Admin Access
     *
     * @param admin - Address of Admin
     * @return whether minter has access
     */
    function isAdmin(address admin) public view returns (bool) {
        return _admins[admin];
    }

    /**
     * Mint + Issue NFT
     *
     * @param recipient - NFT will be issued to recipient
     * @param hash - Artwork Metadata IPFS hash
     * @param data - Artwork Metadata URI/Data
     */
    function issueToken(
        address recipient,
        string memory hash,
        string memory data
    ) public onlyAdmin returns (uint256) {
        require(hashes[hash] == false, "NFT for hash already minted");
        hashes[hash] = true;
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _mint(recipient, newTokenId);
        _setTokenURI(newTokenId, data);
        return newTokenId;
    }

    /**
     * Batch Mint
     *
     * @param recipient - NFT will be issued to recipient
     * @param _hashes - array of Artwork Metadata IPFS hash
     * @param _URIs - array of Artwork Metadata URI/Data
     */
    function issueBatch(
        address recipient,
        string[] memory _hashes,
        string[] memory _URIs
    ) public onlyAdmin returns (uint256[] memory) {
        require(
            _hashes.length == _URIs.length,
            "Hashes & URIs length mismatch"
        );
        uint256[] memory tokenIds = new uint256[](_hashes.length);
        for (uint256 i = 0; i < _hashes.length; i++) {
            string memory hash = _hashes[i];
            string memory data = _URIs[i];
            uint256 tokenId = issueToken(recipient, hash, data);
            tokenIds[i] = tokenId;
        }
        return tokenIds;
    }

    /**
     * Get Holder Token IDs
     *
     * @param holder - Holder of the Tokens
     */
    function getHolderTokenIds(address holder)
        public
        view
        returns (uint256[] memory)
    {
        uint256 count = balanceOf(holder);
        uint256[] memory result = new uint256[](count);
        uint256 index;
        for (index = 0; index < count ; index++) {
            result[index] = tokenOfOwnerByIndex(holder, index);
        }
        return result;
    }

    /**
     * returns the message sender
     */
    function _msgSender()
        internal
        view
        override(ContextUpgradeable, BaseRelayRecipient)
        returns (address payable)
    {
        return BaseRelayRecipient._msgSender();
    }

    /**
     * Throws if called by any account other than the Admin.
     */
    modifier onlyAdmin() {
        require(
            _admins[_msgSender()] || _msgSender() == owner(),
            "Caller does not have Admin Access"
        );
        _;
    }
}