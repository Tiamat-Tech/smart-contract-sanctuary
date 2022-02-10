// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Symbols is ERC721, Ownable {
    using Strings for uint256;

    // Maximum supply of tokens
    uint256 public immutable MAX_SUPPLY;

    string public baseExtension = ".json";

    // Maximum number of tokens that can be minted in a single transaction
    uint256 public constant MAX_MINT_NUMBER = 8;

    // Maximum number of tokens that can be minted for single account
    uint256 public constant MAX_MINT_PER_ACCOUNT = 8;

    // Number of tokens issued for sale
    uint256 public issuedTotal;

    // Number of minted tokens (includes reserve mints)
    uint256 public mintedTotal;

    // Single token price in wei
    uint256 public price;

    // Base URI of the token metadata
    string public baseUri;

    // True if the public token sale is enabled
    bool public publicSaleEnabled;

    // Contains minter addresses
    mapping(address => uint256) public minterAddresses;

    /**
     * @dev Throws if the given number of tokens can't be bought by current transaction
     * @param number Requested number of tokens
     *
     * Requirements:
     * - There should be enough issued unsold tokens
     * - Transaction value should be equal or bigger than the total price
     * - The given number of tokens shouldn't exceed MAX_MINT_NUMBER
     */
    modifier canBuy(uint256 number) {
        require(number <= remainingUnsoldSupply(), "Not enough issued tokens left");
        require(msg.value >= price * number, "Insufficient value for mint");
        require(number <= MAX_MINT_NUMBER, "Can't mint that many tokens at once");
        require(minterAddresses[msg.sender] + number <= MAX_MINT_PER_ACCOUNT, "You can't mint so much tokens");
        _;
    }

    /**
     * @param price_ Single token price
     * @param maxSupply Max amount of tokens that can be minted
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 price_,
        uint256 maxSupply
    ) ERC721(_name, _symbol) {
        MAX_SUPPLY = maxSupply;
        price = price_;
    }

    /**
     * @dev Issues given number of tokens for sale
     * @param number Number of tokens to issue
     *
     * Requirements:
     * - There should be enough supply remaining
     */
    function issue(uint256 number) external onlyOwner {
        require(number <= remainingUnissuedSupply(), "Not enough remaining tokens");
        issuedTotal += number;
    }

    /**
     * @dev Public sale mint
     * @param number Number of tokens to mint
     *
     * Requirements:
     * - Public sale should be enabled
     * - All requirements of the canBuy modifier must be satisfied
     */
    function mint(uint256 number) external payable canBuy(number) {
        require(publicSaleEnabled, "Public sale disabled");
        _batchMint(number);
    }

    function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
    {

        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = baseUri;

        return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
        : "";
    }

    /**
     * @dev Enables minting for non-whitelisted addresses
     */
    function enablePublicSale() external onlyOwner {
        publicSaleEnabled = true;
    }

    /**
     * @dev Disables minting for non-whitelisted addresses
     */
    function disablePublicSale() external onlyOwner {
        publicSaleEnabled = false;
    }

    /**
     * @dev Sets the price of a single token
     * @param price_ Price in eth
     */
    function setPrice(uint256 price_) external onlyOwner {
        price = price_;
    }

    /**
     * @dev Sets base URI for the metadata
     * @param baseUri_ Base URI, where the token's ID could be appended at the end of it
     */
    function setBaseUri(string memory baseUri_) external onlyOwner {
        baseUri = baseUri_;
    }

    /**
     * @dev Sends contract's balance to the owner's wallet
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }

    /**
     * @dev Mints new tokens
     * @param number Number of tokens to mint
     */
    function _batchMint(uint256 number) private {
        uint256 lastTokenId = mintedTotal;
        mintedTotal += number;
        for (uint256 i = 1; i <= number; i++) {
            _safeMint(msg.sender, lastTokenId + i);
        }
        minterAddresses[msg.sender] += number;
    }

    /**
     * @dev Overwrites parent to provide actual base URI
     * @return Base URI of the token metadata
     */
    function _baseURI() override internal view returns (string memory) {
        return baseUri;
    }

    /**
     * @dev Checks if the given token exists (has been minted)
     * @param tokenId Token ID
     * @return True, if token is minted
     */
    function exists(uint256 tokenId) external view returns (bool) {
        return _exists(tokenId);
    }

    /**
     * @dev Returns total number of minted tokens
     * @return Total number of minted tokens
     *
     * Note: Partially implements IERC721Enumerable
     */
    function totalSupply() external view returns (uint256) {
        return mintedTotal;
    }

    /**
     * @dev Returns the number of tokens than could still be minted
     * @return Number of tokens
     */
    function remainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - mintedTotal;
    }

    /**
     * @dev Returns the number of tokens that could still be issued for sale
     * @return Number of tokens
     */
    function remainingUnissuedSupply() public view returns (uint256) {
        return MAX_SUPPLY - issuedTotal;
    }

    /**
     * @dev Returns the number of issued tokens that could still be minted
     * @return Number of tokens
     */
    function remainingUnsoldSupply() public view returns (uint256) {
        return issuedTotal - (mintedTotal);
    }

    function remainingSupplyForAddress(address _address) public view returns (uint256) {
        return minterAddresses[_address];
    }
}