// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract TestCollectible is ERC721, ERC721Enumerable, Ownable, Pausable {
    using SafeMath for uint256;

    uint256 public mintPrice;

    uint256 public constant maxPurchase = 20;

    uint256 public startingIndexBlock;

    uint256 public startingIndex;

    uint256 public constant NUMBER_OF_LEVELS = 2;
    uint256 public constant MAX_SUPPLY = 10000;

    uint256[5] public MAX_SUPPLY_PER_SECTION = [ // Can't use array constant so using non-constant even though these totals can't be changed
        2000,
        2000,
        2000,
        2000,
        2000
    ];

    uint256 public REVEAL_TIMESTAMP;

    string[NUMBER_OF_LEVELS] public PROVENANCE_BASE;

    uint256[NUMBER_OF_LEVELS] public mintTotals; // Store separately because we need to know what's been minted at each level
    uint16[5][NUMBER_OF_LEVELS] public mintTotalsPerSection;

    uint256 internal nextTokenId; // Keeps track of the next tokenId for minting because we need to cater for burning which reduces total totalSupply

    bool public saleIsActive; // Ready, set, go

    struct item {
        uint8 level;
        uint8 section;
        uint16 sequenceId;
    }

    mapping(uint256 => item) internal items;
    mapping(uint256 => uint256) public transferTimestamps;

    constructor() ERC721("Test Collectible", "TEST") {
        mintPrice =  100000000000000000; //0.1 ETH
        REVEAL_TIMESTAMP = block.timestamp + (86400 * 9);
    }

    function strConcat(string memory _a, string memory _b) internal pure returns(string memory) {
      return string(abi.encodePacked(bytes(_a), bytes(_b)));
    }

    function generateTokenURI(uint8 level, uint8 section, uint16 sequenceId) internal pure returns(string memory){
        string memory uri = strConcat(
                    strConcat(
                        strConcat(
                            strConcat(
                                Strings.toString(level),
                                '-'),
                            Strings.toString(section)),
                        '-'),
                Strings.toString(sequenceId));

        return uri;
    }

    /*
    * Pause sale if active, make active if paused
    */
    function toggleSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }

    /**
     * Set price to mint
     */
    function setMintPrice(uint256 price) external onlyOwner {
        mintPrice = price;
    }

    /*
    * Set reveal timestamp when finished the sale.
    */
    function setRevealTimestamp(uint256 revealTimeStamp) external onlyOwner {
        REVEAL_TIMESTAMP = revealTimeStamp;
    }

    /*
    * Set provenance once it's calculated, hash for each level of base artwork
    */
    function setBaseProvenanceHash(uint256 level, string memory provenanceHash) external onlyOwner {
        require(level < NUMBER_OF_LEVELS, "Invalid level");
        PROVENANCE_BASE[level] = provenanceHash;
    }


    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint (uint8 section, uint256 numberOfTokens) public whenNotPaused payable {
        require(saleIsActive, "Sale not active");
        uint8 level = 0;
        require(section <= 4, "Nonexistent section");
        require(numberOfTokens <= maxPurchase, "Can only mint 20 tokens at a time");
        require(mintTotals[level].add(numberOfTokens) <= MAX_SUPPLY, "Purchase would exceed max supply of items");
        require((mintTotalsPerSection[level][section] + numberOfTokens) <= MAX_SUPPLY_PER_SECTION[section], "Purchase would exceed max supply of items for section");
        require(mintPrice.mul(numberOfTokens) <= msg.value, "Ether value sent is not correct");

        for(uint i = 0; i < numberOfTokens; i++) {
            if (mintTotalsPerSection[level][section] < MAX_SUPPLY_PER_SECTION[section]) {
                // Increment tokenId
                uint256 currentTokenId = nextTokenId;
                nextTokenId = nextTokenId.add(1);

                uint16 sequenceId = mintTotalsPerSection[level][section];
                mintTotalsPerSection[level][section] = mintTotalsPerSection[level][section] + 1;
                mintTotals[level] = mintTotals[level].add(1);

                items[currentTokenId] = item({
                    level: level,
                    section: section,
                    sequenceId: sequenceId
                });

                _safeMint(msg.sender, currentTokenId);
            }
        }

        // If we haven't set the starting index and this is either 1) the last saleable token or 2) the first token to be sold after
        // the end of pre-sale, set the starting index block
        if (startingIndexBlock == 0 && (mintTotals[level] == MAX_SUPPLY || block.timestamp >= REVEAL_TIMESTAMP)) {
            startingIndexBlock = block.number;
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);

    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _burn(uint256 tokenId) internal override {
      super._burn(tokenId);

      // Remove the item data
      delete items[tokenId];
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");

        item memory info = items[tokenId];
        string memory _tokenURI = generateTokenURI(info.level, info.section, info.sequenceId);
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    function itemInfo(uint256 tokenId) public view returns (item memory) {
        require(_exists(tokenId), "Info query for nonexistent token");
        return items[tokenId];
    }

    /**
     * Set the starting index for the collection
     */
    function setStartingIndex() public {
        require(startingIndex == 0, "Starting index is already set");
        require(startingIndexBlock != 0, "Starting index block must be set");

        startingIndex = uint(blockhash(startingIndexBlock)) % MAX_SUPPLY;
        // Just a sanity case in the worst case if this function is called late (EVM only stores last 256 block hashes)
        if (block.number.sub(startingIndexBlock) > 255) {
            startingIndex = uint(blockhash(block.number - 1)) % MAX_SUPPLY;
        }
        // Prevent default sequence
        if (startingIndex == 0) {
            startingIndex = startingIndex.add(1);
        }
    }

    /**
     * Set the starting index block for the collection, essentially unblocking
     * setting starting index
     */
    function emergencySetStartingIndexBlock() public onlyOwner {
        require(startingIndex == 0, "Starting index is already set");

        startingIndexBlock = block.number;
    }

    function withdraw() public onlyOwner {
        // TODO: Check uint can handle enough balance
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function withdrawTokens(IERC20 token) public onlyOwner {
        require(address(token) != address(0));
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    receive() external payable {}

}