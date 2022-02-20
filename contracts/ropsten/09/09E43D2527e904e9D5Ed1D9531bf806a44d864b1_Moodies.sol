// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/PullPayment.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Moodies is ERC721, PullPayment, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private currentTokenId;

    /// @dev Base token URI used as a prefix by tokenURI().
    string public baseTokenURI;

    string public uriPrefix = "";
    string public uriSuffix = ".json";

    // Constants
    uint256 _totalSupply = 10000;

    struct MoodiesStruct {
        uint id;
        address receiver;
        uint256 timestamp;
    }

    MoodiesStruct[] moodies;

    constructor() ERC721("Moodies", "MOOD") {
        baseTokenURI = "";
    }

    function mintTo(address recipient) public returns (uint256) {
        uint256 tokenId = currentTokenId.current();
        require(tokenId < _totalSupply, "Max supply reached");

        currentTokenId.increment();
        uint256 newItemId = currentTokenId.current();
        _safeMint(recipient, newItemId);
        moodies.push(MoodiesStruct(newItemId, recipient, block.timestamp));

        return newItemId;
    }

    /// @dev Returns an URI for a given token ID
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    /// @dev Sets the base token URI prefix.
    function setBaseTokenURI(string memory _baseTokenURI) public {
        baseTokenURI = _baseTokenURI;
    }

    function tokenURI(uint256 _tokenId)
    public
    view
    virtual
    override
    returns (string memory)
    {
        require(
        _exists(_tokenId),
        "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0
            ? string(abi.encodePacked(currentBaseURI, _tokenId.toString(), uriSuffix))
            : "";
    }

    /// @dev Overridden in order to make it an onlyOwner function
    function withdrawPayments(address payable payee) public override onlyOwner virtual {
      super.withdrawPayments(payee);
    }

    function getAllMoodies() public view returns (MoodiesStruct[] memory) {
        return moodies;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }
}