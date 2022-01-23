// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract AZDAOToken is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    uint8 max_tokens = 25;
    uint64 price = 0.05 ether;
    bytes32 hash = 0x3162633630346235316539646435316538373435633162366636386234613662;

    mapping(string => uint8) existingURIs;

    constructor() ERC721("AZDAOToken", "AZT") {}

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://";
    }

    function safeMint(address to, string memory uri) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        existingURIs[uri] = 1;
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
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

    function isContentOwned(string memory uri) public view returns (bool) {
        return existingURIs[uri] == 1;
    }

    function payToMintMultiple(
        address recipient,
        string[] memory metadataURIs,
        uint256 userHas
    ) public payable returns (uint256[] memory) {
        require(userHas + metadataURIs.length <= max_tokens, 'Already has 25!');
        require(msg.value >= metadataURIs.length * price, 'Not enough coins!');

        uint256[] memory itemIds = new uint256[](metadataURIs.length);

        for (uint i = 0; i < metadataURIs.length; i++) {
            uint256 newItemId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            existingURIs[metadataURIs[i]] = 1;

            _mint(recipient, newItemId);
            _setTokenURI(newItemId, metadataURIs[i]);
        }

        return itemIds;
    }

    function payToMintSingle(
        address recipient,
        string memory metadataURI,
        uint256 userHas
    ) public payable returns (uint256) {
        require(userHas < max_tokens, 'Already has 25!');
        require(msg.value >= price, 'Not enough coins!');

        uint256 newItemId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        existingURIs[metadataURI] = 1;

        _mint(recipient, newItemId);
        _setTokenURI(newItemId, metadataURI);

        return newItemId;
    }

    function freeMintMultiple(
        address recipient,
        string[] memory metadataURIs,
        uint256 userHas,
        string memory key
    ) public returns (uint256[] memory) {
        require(userHas + metadataURIs.length <= max_tokens, 'Already has 25!');
        require(keccak256(abi.encodePacked(key)) == hash, 'Invalid key!');
        uint256[] memory itemIds = new uint256[](metadataURIs.length);

        for (uint i = 0; i < metadataURIs.length; i++) {
            uint256 newItemId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            existingURIs[metadataURIs[i]] = 1;

            _mint(recipient, newItemId);
            _setTokenURI(newItemId, metadataURIs[i]);
        }
        return itemIds;
    }

    function freeMintSingle(
        address recipient,
        string memory metadataURI,
        string memory key
    ) public returns (uint256) {
        require(keccak256(abi.encodePacked(key)) == hash, 'Invalid key!');
        uint256 newItemId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        existingURIs[metadataURI] = 1;

        _mint(recipient, newItemId);
        _setTokenURI(newItemId, metadataURI);
        return newItemId;
    }

    function withdraw(address owner, string memory key) public {
        require(keccak256(abi.encodePacked(key)) == hash, 'Invalid key!');
        payable(owner).transfer(address(this).balance);
    }

    function count() public view returns (uint256) {
        return _tokenIdCounter.current();
    }
}