// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NFTokenName is ERC721, ERC721Enumerable, Ownable, Pausable {
    using SafeMath for uint256;
    using Strings for uint256;
    using SafeERC20 for IERC20;

    struct TokenBucket {
        uint256 min;
        uint256 max;
        string prefix;
    }

    address contractAddress;

    string _baseDynamicURI; // Our API server for dynamic metadata
    string public contractURI;

    uint256 public MAX_MINTABLE = 10_001;
    uint256 public mintPrice = 0.042 ether;
    uint256 public maxPurchaseCount = 20;
    uint256 public totalNFTokenName = 0;
    bool public mintingComplete = false;
    bool public recyclingActive = false;
    uint256 public recycleCost = 2;
    uint256 public recycleSupply = 0;

    IERC20 public weth;

    TokenBucket[] buckets;

    constructor(string memory baseURIVal_, address weth_)
        ERC721("TokenName", "VSTR")
    {
        contractAddress = address(this);
        weth = IERC20(weth_);
        _baseDynamicURI = baseURIVal_;
        _pause();
    }

    function _mintTokens(uint256 numberOfTokens) internal {
        for (uint256 i = 0; i < numberOfTokens; i++) {
            _mint(msg.sender, totalNFTokenName + 1);
            totalNFTokenName += 1;
        }
    }

    function mintTokens(uint256 numberOfTokens)
        public
        payable
        whenNotPaused
        whenMintingNotComplete
        mintCountMeetsSupply(numberOfTokens)
        doesNotExceedMaxPurchaseCount(numberOfTokens)
    {
        uint256 amount = calculatePrice(numberOfTokens);
        uint256 balance = weth.balanceOf(msg.sender);
        require(balance >= amount, "Not enough wETH");
        weth.safeTransferFrom(msg.sender, contractAddress, amount);
        _mintTokens(numberOfTokens);
        if (totalNFTokenName >= MAX_MINTABLE) {
            mintingComplete = true;
        }
    }

    function recycle(uint256[] memory tokenIds)
        public
        whenNotPaused
        recyclingIsActive
        meetsRecyclingSupply
        meetsRecyclingCost(tokenIds)
        meetsOwnership(tokenIds)
    {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _burn(tokenIds[i]);
        }
        _mintTokens(1);
        recycleSupply -= 1;
    }

    /**
     * @dev Returns the total cost in WETH for numberOfTokens
     */
    function calculatePrice(uint256 numberOfTokens)
        internal
        view
        returns (uint256)
    {
        return mintPrice.mul(numberOfTokens);
    }

    /**
     * @dev The ability to create buckets of varying size
     * as for reference for the tokenURI
     */
    function addBucket(
        uint256 min,
        uint256 max,
        string memory prefix
    ) public onlyOwner {
        require(min < max, "Min must be less than Max");
        require(bytes(prefix).length > 0, "Prefix can not be blank");
        for (uint256 i = 0; i < buckets.length; i++) {
            require(
                min > buckets[i].max,
                "Bucket min must start after previous bucket max"
            );
        }
        buckets.push(TokenBucket(min, max, prefix));
    }

    /**
     * @dev Because of the recycler we will be adding new NFT's in the
     * future. We use batches of uploads to IPFS to reduce contract storage
     */
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

        string memory prefix = _baseDynamicURI;
        for (uint256 i = 0; i < buckets.length; i++) {
            if (buckets[i].min <= tokenId && buckets[i].max >= tokenId) {
                prefix = buckets[i].prefix;
                break;
            }
        }
        return
            bytes(prefix).length > 0
                ? string(abi.encodePacked(prefix, tokenId.toString()))
                : "";
    }

    function setContractURI(string memory newContractURI) public onlyOwner {
        contractURI = newContractURI;
    }

    /**
     * @dev Sets the URI for our dynamic API
     */
    function setBaseURI(string memory newBase) public onlyOwner {
        _baseDynamicURI = newBase;
    }

    function setMintPrice(uint256 newPrice) public onlyOwner {
        mintPrice = newPrice;
    }

    /**
     * @dev Typically recycling will cost 2 to mint 1, but this
     * is configurable for future drops that are more expensive
     * and exclusive
     */
    function setRecycleCost(uint256 newCost) public onlyOwner {
        require(newCost > 0, "recycleCost must be greater than zero");
        recycleCost = newCost;
    }

    /**
     * @dev Each time the recycler is turned on, this is the max
     * amount that can be minted
     */
    function setRecycleSupply(uint256 newSupply) public onlyOwner {
        recycleSupply = newSupply;
    }

    function recyclingOn() public onlyOwner {
        recyclingActive = true;
    }

    function recyclingOff() public onlyOwner {
        recyclingActive = false;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function withdrawMatic() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function withdrawWeth() public onlyOwner {
        uint256 balance = weth.balanceOf(contractAddress);
        weth.transfer(owner(), balance);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev This is our check for standard minting, once
     * we surpass MAX_MINTABLE NFTokenName the mintTokens is
     * no longer available. From then on the only way to
     * mint a TokenName you must recycle and burn existing
     * tokens
     */
    modifier mintCountMeetsSupply(uint256 numberOfTokens) {
        require(
            totalNFTokenName + numberOfTokens <= MAX_MINTABLE,
            "Purchase would exceed max supply"
        );
        _;
    }

    modifier doesNotExceedMaxPurchaseCount(uint256 numberOfTokens) {
        require(
            numberOfTokens <= maxPurchaseCount,
            "Cannot mint more than 20 tokens at a time"
        );
        _;
    }

    modifier whenMintingNotComplete() {
        require(mintingComplete == false, "Normal minting is complete");
        _;
    }

    modifier recyclingIsActive() {
        require(recyclingActive == true, "Recycler is not active");
        _;
    }

    modifier meetsRecyclingSupply() {
        require(
            recycleSupply > 0,
            "There are no NFTokenName available via recycling"
        );
        _;
    }

    modifier meetsRecyclingCost(uint256[] memory tokenIds) {
        require(
            tokenIds.length == recycleCost,
            "Incorrect number of NFTokenName passed for recycling"
        );
        _;
    }

    modifier meetsOwnership(uint256[] memory tokenIds) {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                this.ownerOf(tokenIds[i]) == msg.sender,
                "You may only recycle NFTokenName you own"
            );
        }
        _;
    }
}