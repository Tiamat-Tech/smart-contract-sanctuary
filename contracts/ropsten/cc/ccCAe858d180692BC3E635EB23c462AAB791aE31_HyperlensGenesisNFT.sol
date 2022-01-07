// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract HyperlensGenesisNFT is ERC721, ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    using SafeMath for uint8;

    // maximum number of tokens that can be purchased in one transaction
    uint8 public constant MAX_PURCHASE = 2;

    // price of a single crystal in wei
    uint256 public constant NFT_PRICE = 1200000000000000000 wei;

    // maximum number of crystals that can be minted on this contract
    uint256 public maxTotalSupply;

    // maximum number of crystals that can be minted on this contract
    uint256 public maxPrivateSupply = 0;

    // maximum number of crystals that can be minted on this contract
    uint256 public maxPublicSupply = 0;

    // private sale current status - active or not
    bool public privateSale = false;

    // public sale current status - active or not
    bool public publicSale = false;

    bool public isFreeze = false;

    // whitelisted addresses that can participate in the presale event
    mapping(address => uint8) private _whiteList;

    uint8 private _initialMintReserve;

    // base uri for token metadata
    string private _baseTokenURI;

    // event that emits when private sale changes state
    event privateSaleState(bool active);

    // event that emits when public sale changes state
    event publicSaleState(bool active);

    Counters.Counter private _tokenIdCounter;

    constructor(
        uint256 maxSupply,
        uint8 initialMintReserve,
        string memory initialBaseTokenURI
    ) ERC721("Hyperlens Genesis NFT", "Hyperlens Genesis NFT") {
        maxTotalSupply = maxSupply;
        _initialMintReserve = initialMintReserve;
        _baseTokenURI = initialBaseTokenURI;
    }

    function availableForMint() public view virtual returns (uint256) {
        return (maxTotalSupply - totalSupply() - _initialMintReserve);
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function setBaseURI(string memory uri) external onlyOwner {
        _baseTokenURI = uri;
    }

    function baseTokenURI() public view virtual returns (string memory) {
        return _baseTokenURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function safeMint(address to) private {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
    internal
    override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function mintInitial(uint8 numberOfTokens) external onlyOwner {
        require(!isFreeze, "contract have already frozen!");
        require(availableForMint() >= numberOfTokens, "Total Supply limit have reached!");

        _initialMintReserve = uint8(_initialMintReserve.sub(numberOfTokens));
        _mintTokens(msg.sender, numberOfTokens);
    }


    function flipPrivateSaleState() external onlyOwner {
        privateSale = !privateSale;
        emit privateSaleState(privateSale);
    }

    function isPublicSaleActive() public view virtual returns (bool) {
        return publicSale;
    }

    function isPublicSaleEnded() public view virtual returns (bool) {
        return maxTotalSupply == totalSupply();
    }

    function flipPublicSaleState() external onlyOwner {
        publicSale = !publicSale;
        emit publicSaleState(publicSale);
    }

    function freeze() external onlyOwner {
        require(!isFreeze, "contract have already frozen!");
        isFreeze = true;
        maxTotalSupply = totalSupply();
    }

    function addWhitelistAddresses(uint8 numberOfTokens, address[] calldata addresses) external onlyOwner {
        require(!isFreeze, "contract have already frozen!");
        require(!privateSale, "Private sale is not running!!!");
        require(numberOfTokens <= MAX_PURCHASE, "numberOfTokens is higher that MAX PURCHASE limit!");

        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] != address(0)) {
                _whiteList[addresses[i]] = numberOfTokens;
            }
        }
    }

    function removeWhitelistAddresses(address[] calldata addresses) external onlyOwner {
        require(!isFreeze, "contract have already frozen!");
        require(!privateSale, "Private sale is now running!!!");

        for (uint256 i = 0; i < addresses.length; i++) {
            _whiteList[addresses[i]] = 0;
        }
    }

    function mintPrivate(uint8 numberOfTokens) public payable {
        require(!isFreeze, "contract have already frozen!");
        require(privateSale, "Private sale is not active!");
        require(numberOfTokens > 0, "Number of tokens cannot be lower than, or equal to 0!");
        require(availableForMint() >= numberOfTokens, "Total Supply limit have reached!");
        require(numberOfTokens <= _whiteList[msg.sender], "Not enough presale slots to mint tokens!");
        require(NFT_PRICE * numberOfTokens == msg.value, "Ether value sent is not correct!");

        _whiteList[msg.sender] = uint8(_whiteList[msg.sender].sub(numberOfTokens));
        _mintTokens(msg.sender, numberOfTokens);
    }

    function mintPublic(uint8 numberOfTokens) public payable {
        require(!isFreeze, "contract have already frozen!");
        require(publicSale, "Public sale is not active!");
        require(numberOfTokens > 0, "Number of tokens cannot be lower than, or equal to 0!");
        require(numberOfTokens <= MAX_PURCHASE, "Trying to mint too many tokens!");
        require(availableForMint() >= numberOfTokens, "Total Supply limit have reached!");
        require(NFT_PRICE * numberOfTokens == msg.value, "Ether value sent is not correct!");

        _mintTokens(msg.sender, numberOfTokens);
    }

    function _mintTokens(address to, uint8 numberOfTokens) private {
        require(!isFreeze, "contract have already frozen!");

        for (uint8 i = 0; i < numberOfTokens; i++) {
            safeMint(to);
        }
    }
}