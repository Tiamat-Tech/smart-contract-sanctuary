//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFT is ERC721Enumerable, Ownable {
    uint public immutable price;
    uint public immutable preSaleStart;
    uint public immutable publicSaleStart;
    uint public immutable maxSupply;
    mapping (address => bool) public isWhitelisted;
    string public baseUri;

    uint private nextTokenId;

    /**
     * @notice Initialise NFT smart contract
     * @param _name Name of the NFT
     * @param _symbol Symbol of the NFT
     * @param _baseUri base uri of the collection
     * @param _price Price of each NFT
     */
    constructor(string memory _name, string memory _symbol, string memory _baseUri, uint _price,
        uint _preSaleStart, uint _publicSaleStart, uint _maxSupply) ERC721(_name, _symbol) {
        baseUri = _baseUri;
        price = _price;
        preSaleStart = _preSaleStart;
        publicSaleStart = _publicSaleStart;
        maxSupply = _maxSupply;
    }

    // Public methods
    function mint() external payable returns (bool) {
        // Check if caller can mint
        uint currTime = block.timestamp;
        bool canMint = (currTime >= preSaleStart && isWhitelisted[msg.sender]) || currTime >= publicSaleStart;
        require(canMint, "Cannot mint yet");

        // Check transaction value
        require(msg.value >= price, "Insufficient fund");

        // Check max supply
        require(nextTokenId < maxSupply, "Max supply reached");

        // Mint nft
        _safeMint(msg.sender, nextTokenId);
        nextTokenId += 1;

        return true;
    }

    // Privileged methods
    /**
     * @notice Send raised amount to the owner
     */
    function withdraw() external onlyOwner returns (bool) {
        payable(msg.sender).transfer(address(this).balance);
        return true;
    }

    /**
     * @notice Whitelist user for pre sale
     * @param _user User to whitelist
     */
    function whitelist(address _user) external onlyOwner returns (bool) {
        isWhitelisted[_user] = true;
        return true;
    }

    // Private methods
    /**
     * @dev Returns set base uri. It's used in tokenURI
     */
    function _baseURI() internal view override returns (string memory) {
        return baseUri;
    }
}