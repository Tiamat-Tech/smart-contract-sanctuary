//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFT is ERC721Enumerable, Ownable {
    uint public immutable preSalePrice;
    uint public immutable publicSalePrice;
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
     * @param _preSalePrice Pre sale price of an NFT
     * @param _preSaleStart Pre sale start timestamp
     * @param _publicSalePrice Public sale price of an NFT
     * @param _publicSaleStart Public sale start timestamp
     */
    constructor(string memory _name, string memory _symbol, string memory _baseUri, uint _preSalePrice,
        uint _preSaleStart, uint _publicSalePrice, uint _publicSaleStart, uint _maxSupply) ERC721(_name, _symbol) {
        baseUri = _baseUri;
        preSalePrice = _preSalePrice;
        preSaleStart = _preSaleStart;
        publicSalePrice = _publicSalePrice;
        publicSaleStart = _publicSaleStart;
        maxSupply = _maxSupply;
    }

    // Public methods
    function mint() external payable returns (bool) {
        // Check if caller can mint
        require (block.timestamp >= preSaleStart, "Cannot mint yet");

        if (isWhitelisted[msg.sender] && block.timestamp >= preSaleStart) {
            require(msg.value >= preSalePrice, "Insufficient fund");
        }
        else if (block.timestamp >= publicSaleStart) {
            require(msg.value >= publicSalePrice, "Insufficient fund");
        }

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