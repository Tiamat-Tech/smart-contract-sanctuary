//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";

// These contract definitions are used to create a reference to the OpenSea
// ProxyRegistry contract by using the registry's address (see isApprovedForAll).
contract OwnableDelegateProxy {

}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

contract CarNFT is ERC721, Ownable {
    using Address for address payable;

    uint8 public constant MAX_PURCHASE = 20;

    // uint256 public constant MAX_SUPPLY = 20006;

    // uint256 public constant SALE_PRICE = 0.1 ether;

    uint256 public MAX_SUPPLY;

    uint256 public SALE_PRICE;

    uint256 public REVEAL_TIMESTAMP;

    string public PROVENANCE_HASH = '';

    string public baseTokenURI = '';

    bool public saleIsActive = false;

    uint256 public startingIndexBlock;

    uint256 public startingIndex;

    uint256 public tokenCount = 0;

    address public recipient = 0x242d76b0689f38508f411F1bb5E280Afd6cb2823;

    address public openSeaProxyRegistryAddress;

    bool public isOpenSeaProxyActive = true;

    constructor(address _openSeaProxyRegistryAddress, uint256 _supply, uint256 _price, uint256 _revealTimeStamp) ERC721('Car', 'CARR') {
        openSeaProxyRegistryAddress = _openSeaProxyRegistryAddress;

        // for testing purposes - could be set as constants before contract deployment
        MAX_SUPPLY = _supply;
        SALE_PRICE = _price;
        REVEAL_TIMESTAMP = _revealTimeStamp;
    }

    modifier onlyExternal() {
        require(msg.sender == tx.origin, 'Contracts not allowed to mint');
        _;
    }

    /**
     * Mint Carrier NFT's reserved for the contract owner
     */
    function mintReserved(uint256 _numberOfTokens) external onlyOwner {
        require(tokenCount + _numberOfTokens <= MAX_SUPPLY, 'Minting would exceed total supply of tokens');

        for (uint256 i = 0; i < _numberOfTokens; i++) {
            _safeMint(_msgSender(), ++tokenCount);
        }
    }

    /**
     * Mint Carrier NFT
     */
    function mint(uint256 _numberOfTokens) external payable onlyExternal {
        require(saleIsActive, 'Sale must be active in order to mint');
        require(_numberOfTokens <= MAX_PURCHASE, 'Can only mint 20 tokens at a time');
        require(tokenCount + _numberOfTokens <= MAX_SUPPLY, 'Minting would exceed total supply of tokens');
        require(SALE_PRICE * _numberOfTokens <= msg.value, 'Ether value sent is not enough for the purchase');

        payable(recipient).sendValue(msg.value);

        for (uint256 i = 0; i < _numberOfTokens; i++) {
            _safeMint(_msgSender(), ++tokenCount);
        }

        // Set the starting index block if it is not already set and this is either 
        // 1) the last saleable token or 2) the first token to be sold after the end of pre-sale 
        if (startingIndexBlock == 0 && (tokenCount == MAX_SUPPLY || block.timestamp >= REVEAL_TIMESTAMP)) {
            startingIndexBlock = block.number;
        } 
    }

    function flipSaleState() external onlyOwner {
        saleIsActive = !saleIsActive;
    }

    /**    
     * Set provenance hash when it's calculated
     */
    function setProvenanceHash(string memory _provenanceHash) external onlyOwner {
        PROVENANCE_HASH = _provenanceHash;
    }

    function setRevealTimestamp(uint256 _revealTimeStamp) external onlyOwner {
        REVEAL_TIMESTAMP = _revealTimeStamp;
    }

    function setBaseURI(string memory _uri) external onlyOwner {
        baseTokenURI = _uri;
    }

    function setOpenSeaProxyRegistryAddress(address _openSeaProxyRegistryAddress) external onlyOwner {
        openSeaProxyRegistryAddress = _openSeaProxyRegistryAddress;
    }

    /**
     * Function to disable gasless listings for security in case OpenSea ever shuts down or is compromised
     */
    function setIsOpenSeaProxyActive(bool _isOpenSeaProxyActive) external onlyOwner {
        isOpenSeaProxyActive = _isOpenSeaProxyActive;
    }

    function setRecipientAddress(address _recipient) external onlyOwner {
        recipient = _recipient;
    }

    /**
     * Set the starting index for the collection
     */
    function setStartingIndex() external {
        require(startingIndex == 0, 'Starting index is already set');
        require(startingIndexBlock != 0, 'Starting index block must be set');

        // Just a sanity check if this function is called late (EVM only stores last 256 block hashes)
        if (block.number - startingIndexBlock > 255) {
            startingIndexBlock = block.number - 1;
        }

        startingIndex = uint(blockhash(startingIndexBlock)) % MAX_SUPPLY;
        // Prevent default sequence
        if (startingIndex == 0) {
            startingIndex = startingIndex + 1;
        }
    }

    /**
     * Set the starting index block for the collection, essentially unblocking
     * setting starting index
     */
    function emergencySetStartingIndexBlock() external onlyOwner {
        require(startingIndex == 0, 'Starting index is already set');

        startingIndexBlock = block.number;
    }

    function withdraw() external onlyOwner {
        // (bool success, ) = _msgSender().call{value: address(this).balance}('');
        // require(success, 'Withdraw failed');

        payable(_msgSender()).sendValue(address(this).balance);
    }

    /**
     * OVERRIDES
     */

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    /**
     * Override isApprovedForAll to allowlist user's OpenSea proxy accounts to enable gas-less listings.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        override
        returns (bool)
    {
        // Get a reference to OpenSea's proxy registry contract by instantiating
        // the contract using the already existing address.
        ProxyRegistry proxyRegistry = ProxyRegistry(openSeaProxyRegistryAddress);
        if (
            isOpenSeaProxyActive &&
            address(proxyRegistry.proxies(owner)) == operator
        ) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
    }
}