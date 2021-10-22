// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

/// @title Ownership and settings for CYPHER_WATCH
/// @notice Facilities for issuing new watches, transferring ownership,
///         updating fees, and changing watch settings.
/// @dev Watch ownership is implemented through {ERC721}.
/// @custom:security-contact [email protected]
contract CypherWatch is ERC721, ERC721Burnable {
    /// @dev The symbols used to convert numbers to hex strings.
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /// @notice The address authorized to issue new watches and update fees.
    /// @dev This address is fixed to the creator of the contract.
    address payable public _manufacturer;

    /// @notice The fee in Wei charged for using {changeNFT}.
    /// @dev The fee is initialized to 0 and may be updated by the
    ///      {_manufacturer} through {updateChangeFee}.
    uint256 public _changeFee;

    /// @dev An NFT, uniquely defined by its contract address and token ID.
    struct NFT {
        address _contract;
        uint256 _tokenID;
    }

    /// @dev A mapping from a watch ID to the associcated {NFT}.
    mapping(uint256 => NFT) public _nft;

    /// @dev Initializes the {_manufacturer} to the contract creator.
    constructor() ERC721("CYPHER_WATCH", "C_W") {
        _manufacturer = payable(msg.sender);
    }

    /// @notice Allows the {_manufacturer} to update the {_changeFee}.
    /// @param changeFee The new value for {_changeFee}.
    function updateChangeFee(uint256 changeFee) public {
        require(
            msg.sender == _manufacturer,
            "Only the manufacturer can update the change fee"
        );

        _changeFee = changeFee;
    }

    /// @notice Allows the {_manufacturer} to issue new watches.
    /// @dev The watch ID should resolve when appended to the {_baseURI}.
    /// @param watchID The unique ID for the new watch.
    function issue(uint256 watchID) public {
        require(
            msg.sender == _manufacturer,
            "Only the manufacturer can issue new watches"
        );
        require(!_exists(watchID), "This watch already exists");
        require(watchID < 2**128, "The watch ID has to fit into 128 bits");

        _safeMint(_manufacturer, watchID);
    }

    /// @notice Allows the owner of a watch to change the associcated {NFT}.
    ///         This requires payment of the {_changeFee}.
    /// @param watchID The ID of the watch to change.
    /// @param nft The new {NFT} to associate with the watch.
    function changeNFT(uint256 watchID, NFT memory nft) public payable {
        require(
            msg.sender == ownerOf(watchID),
            "Only the watch owner can change the NFT"
        );
        require(
            msg.value == _changeFee,
            "The transaction value has to match the change fee"
        );
        require(
            _nft[watchID]._contract != nft._contract &&
                _nft[watchID]._tokenID != nft._tokenID,
            "This NFT is already associated with the watch"
        );

        // Pay the change fee to the manufacturer.
        (bool paid, ) = _manufacturer.call{value: msg.value}("");
        require(paid, "Failed to pay the change fee");

        // Change the NFT for the watch.
        _nft[watchID] = nft;
    }

    /// @dev Concatenates the {_baseURI} with a hex string of the watch ID.
    function tokenURI(uint256 watchID)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(watchID), "This watch does not exist");
        return string(abi.encodePacked(_baseURI(), asHexString(watchID)));
    }

    /// @dev Converts a watch ID to a 32-character hex string without the 0x
    ///      prefix. The watch ID must fit into 128 bits.
    function asHexString(uint256 watchID)
        internal
        pure
        returns (string memory)
    {
        assert(watchID < 2**128);
        bytes memory buffer = new bytes(32);
        for (uint256 i = buffer.length; i > 0; --i) {
            buffer[i - 1] = _HEX_SYMBOLS[watchID & 0xf];
            watchID >>= 4;
        }
        return string(buffer);
    }

    /// @dev The {tokenURI} is always prepended by this base URI.
    function _baseURI() internal pure override returns (string memory) {
        return "https://cypher.watch/set/";
    }

    /// @dev Cleans up the internal state after a watch has been burned.
    function burn(uint256 watchID) public override {
        super.burn(watchID);
        delete _nft[watchID];
    }
}