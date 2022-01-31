// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "./ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract FlyFroogles is ERC721A, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter private tokenCounter;

    string private baseURI;
    address private OSProxyRegistry             = 0xa5409ec958C83C3f309868babACA7c86DCB077c1;
    bool private isOpenSeaProxyActive           = true;

    uint256 public constant MaxPerTx_pub        = 20;
    uint256 public maxSupply                    = 10001;

    uint256 public constant NFTPrice            = 0.0099 ether;
    uint256 public MaxFree                      = 1001;
    bool public isPublicSaleActive = true;
    mapping(address => bool) public projectProxy;

    
    // Sanity Modifiers
    modifier publicSaleActive() {
        require(isPublicSaleActive, "Public sale is not active.");
        _;
    }

    modifier maxMintsPerTX(uint256 numberOfTokens) {
        require(numberOfTokens <= MaxPerTx_pub, "Exceeds number of tokens per transaction.");
        _;
    }

    modifier canMintNFTs(uint256 numberOfTokens) {
        require(totalSupply() + numberOfTokens <= maxSupply, "Transaction would exceed total token supply.");
        _;
    }

    modifier freeMintsAvailable() {
        require(totalSupply() < MaxFree, "Transaction would exceed free token supply.");
        _;
    }

    modifier isCorrectPayment(uint256 price, uint256 numberOfTokens) {
        if(totalSupply() > MaxFree){
        require((price * numberOfTokens) == msg.value, "Incorrect ETH value sent.");
        }
        _;
    }

    constructor()
        ERC721A("Fly Froogles", "Fly Froogles")
    {}

    // Mint Function
    function mint(uint256 numberOfTokens)
        external
        payable
        nonReentrant
        isCorrectPayment(NFTPrice, numberOfTokens)
        publicSaleActive
        canMintNFTs(numberOfTokens)
        maxMintsPerTX(numberOfTokens)
    {
        _safeMint(msg.sender, numberOfTokens);
    }

    // Free Mint Function
    function freeMint(uint256 numberOfTokens)
        external
        nonReentrant
        publicSaleActive
        canMintNFTs(numberOfTokens)
        maxMintsPerTX(numberOfTokens)
        freeMintsAvailable()
    {
        _safeMint(msg.sender, numberOfTokens);
    }

    // Read Only Function
    function getBaseURI() external view returns (string memory) {
        return baseURI;
    }

    // Owner Only Function
    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    // Function to disable gasless listings for security in case OpenSea ever shuts down or is compromised
    function setIsOpenSeaProxyActive(bool _isOpenSeaProxyActive)
        external
        onlyOwner
    {
        isOpenSeaProxyActive = _isOpenSeaProxyActive;
    }

    function setIsPublicSaleActive(bool _isPublicSaleActive)
        external
        onlyOwner
    {
        isPublicSaleActive = _isPublicSaleActive;
    }

    function setNumFreeMints(uint256 _numfreemints)
        external
        onlyOwner
    {
        MaxFree = _numfreemints;
    }

    function withdraw() public payable onlyOwner {
	(bool success, ) = payable(address(0x03918bA3395F5f92665931B229e34aFF87537Deb)).call{value: address(this).balance}("");
	require(success);
	}

    // Supporting Funcitons
    function nextTokenId() private returns (uint256) {
        tokenCounter.increment();
        return tokenCounter.current();
    }

    function isApprovedForAll(address _owner, address operator) public view override returns (bool) {
        require(isOpenSeaProxyActive, "OpenSea Proxy Registry is not active.");
        OpenSeaProxyRegistry proxyRegistry = OpenSeaProxyRegistry(OSProxyRegistry);
        if (address(proxyRegistry.proxies(_owner)) == operator || projectProxy[operator]) return true;
        return super.isApprovedForAll(_owner, operator);
    }
    // Function Overrides
    // function supportsInterface(bytes4 interfaceId)
    //     public
    //     view
    //     virtual
    //     override(ERC721A, IERC165)
    //     returns (bool)
    // {
    //     return
    //         interfaceId == type(IERC2981).interfaceId ||
    //         super.supportsInterface(interfaceId);
    // }
}

contract OwnableDelegateProxy { }
contract OpenSeaProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}