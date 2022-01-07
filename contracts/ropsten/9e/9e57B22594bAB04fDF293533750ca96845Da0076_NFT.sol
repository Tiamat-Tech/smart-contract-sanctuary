//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFT is ERC721Enumerable, Ownable {
    uint public immutable preSalePrice;
    uint public immutable preSaleStart;
    uint public immutable preSaleBuyLimit;
    uint public immutable publicSalePrice;
    uint public immutable publicSaleStart;
    uint public immutable publicSaleBuyLimit;
    uint public immutable maxSupply;
    mapping (address => bool) public isWhitelisted;
    mapping (address => uint) public preSaleMinted;
    mapping (address => uint) public publicSaleMinted;
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
        uint _preSaleStart, uint _preSaleBuyLimit, uint _publicSalePrice, uint _publicSaleStart, uint _publicSaleBuyLimit,
        uint _maxSupply) ERC721(_name, _symbol) {

        baseUri = _baseUri;
        preSalePrice = _preSalePrice;
        preSaleStart = _preSaleStart;
        preSaleBuyLimit = _preSaleBuyLimit;
        publicSalePrice = _publicSalePrice;
        publicSaleStart = _publicSaleStart;
        publicSaleBuyLimit = _publicSaleBuyLimit;
        maxSupply = _maxSupply;
    }

    // Public methods
    function mint(uint _amount) external payable returns (bool) {
        // Check if caller can mint
        require (block.timestamp >= preSaleStart, "Cannot mint yet");

        if (isWhitelisted[msg.sender] && block.timestamp >= preSaleStart) {
            require(msg.value >= preSalePrice, "Insufficient fund");
            require(preSaleMinted[msg.sender] + _amount <= preSaleBuyLimit, "Minting too many NFTs");
            preSaleMinted[msg.sender] += _amount;
        }
        else if (block.timestamp >= publicSaleStart) {
            require(msg.value >= publicSalePrice, "Insufficient fund");
            require(publicSaleMinted[msg.sender] + _amount <= publicSaleBuyLimit, "Minting too many NFTs");
            publicSaleMinted[msg.sender] += _amount;
        }

        // Check max supply
        require(nextTokenId + _amount < maxSupply, "Max supply reached");

        // Mint nft
        for (uint i = 0; i < _amount; i++) {
            _safeMint(msg.sender, nextTokenId);
            nextTokenId += 1;
        }


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
        require(block.timestamp < preSaleStart, "Cannot whitelist after pre sale started");
        isWhitelisted[_user] = true;
        return true;
    }

    /**
     * @notice Reserve _amount NFTs for the owner
     * @param _amount Amount of NFT to reserve
     */
    function reserve(uint _amount) external onlyOwner returns (bool) {
        // Check max supply
        require(nextTokenId + _amount < maxSupply, "Max supply reached");

        // Mint nft
        for (uint i = 0; i < _amount; i++) {
            _safeMint(msg.sender, nextTokenId);
            nextTokenId += 1;
        }

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