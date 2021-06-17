// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title MyContract contract
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */
contract MyContract is ERC721Pausable, ERC721Enumerable, Ownable {
    using SafeMath for uint256;

    uint public constant MAX_TOKEN_PURCHASE = 20;
    uint public constant TOKEN_PRICE = 0.1 ether; // 100000000000000000 Wei
    
    uint public maxTokenSupply;
    uint public reservedTokens;
    uint public presaleDurationSecs;
    uint256 public saleStartTime;
    uint public startingIndex;
    string public baseURI;

    constructor(uint _maxTokenSupply, uint _reservedTokens, string memory _baseURI, uint _presaleDurationSecs) 
            ERC721("MyContract", "MYCO") {
        require(_maxTokenSupply > 0, "_maxTokenSupply was not given");
        require(_reservedTokens > 0, "_reservedTokens was not given");
        require(_reservedTokens < _maxTokenSupply, "_reservedTokens was too big");

        bytes memory stringLength = bytes(_baseURI);
        require(stringLength.length > 0, "_baseURI for metadata was not given");
        require(_presaleDurationSecs > 0, "_presaleDurationSecs was not given");

        maxTokenSupply = _maxTokenSupply;
        reservedTokens = _reservedTokens;
        baseURI = _baseURI;
        presaleDurationSecs = _presaleDurationSecs;
    }

    /**
     * Override the presale duration
     */
    function setPresaleDuration(uint _presaleDurationSecs) public onlyOwner {
        presaleDurationSecs = _presaleDurationSecs;
    }

    /**
     * Calculate the end time of the presale
     */
    function getRevealTime() public view returns (uint256){
        return saleStartTime.add(presaleDurationSecs);
    }

    /**
     * Start the sale & set some tokens aside
     */
    function startSale() public onlyOwner {
        require(saleStartTime == 0, "Sale has already started");

        // reserve tokens
        for (uint i = 0; i < reservedTokens; i++) {
            uint tokenId = totalSupply();
            _safeMint(msg.sender, tokenId);
        }

        // start the sale
        saleStartTime = block.timestamp;
    }

     /**
     * Get the start of the sale
     */
    function getSaleStart() public view returns (uint256) {
        return saleStartTime;
    }

    /**
     *  Set the starting index number. Requires randomness seeded by the current block number
     *  See: https://fravoll.github.io/solidity-patterns/randomness.html
     */
    function setStartingIndex() private {
        require(startingIndex == 0, "Starting index is already set");

        // generate a pseudo-random number with the has of the last block mined
        startingIndex = uint(blockhash(block.number - 1)) % maxTokenSupply;
        
        // Prevent value of 0 (means 'not set')
        if (startingIndex == 0) {
            startingIndex = startingIndex.add(1);
        }
    }

    /**
     * Get the startingIndex
     */
    function getStartingIndex() public view returns (uint) {
        return startingIndex;
    }

    /**
     * Convert token id based on the startingIndex
     */
    function convertTokenId(uint id) public view returns (uint) {
        return startingIndex.add(id) % maxTokenSupply;
    }

    /**
     * Pause or unpause the token sale
     */
    function pauseTokenSale(bool pause) public onlyOwner {
        if (pause) {
             _pause();
        } else {
            _unpause();
        }
    }

    /**
    * Set Base URI - allow late override, in case of emergency where metadata stops being accessible on IPFS.
    */
    function setBaseURI(string memory newBaseURI) public onlyOwner {
        baseURI = newBaseURI;
    }

    /**
    * Mint Tokens
    */
    function mintTokens(uint numberOfTokens) public payable {
        require(saleStartTime > 0, "Sale has not yet been started");
        require(!paused(), "Contract must not be paused to mint a token");
        require(numberOfTokens <= MAX_TOKEN_PURCHASE, "Can only mint 20 tokens at a time");
        require(totalSupply().add(numberOfTokens) <= maxTokenSupply, "Purchase would exceed max supply of tokens");
        require(TOKEN_PRICE.mul(numberOfTokens) <= msg.value, "Ether value sent is not correct");
        
        for(uint i = 0; i < numberOfTokens; i++) {
            uint tokenId = totalSupply();
                _safeMint(msg.sender, tokenId);
        }

        // If we haven't set the starting index and this is either 1) the last saleable token or 2) the first token to be sold after
        // the end of pre-sale, set the starting index block
        if (startingIndex == 0 && (totalSupply() == maxTokenSupply || block.timestamp >= getRevealTime())) {
            setStartingIndex();
        } 
    }

    /**
     * Get the metadata for a given tokenId
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        require(startingIndex > 0, "TokenURI not available until the end of the presale");

        // use the startingIndex to get the real tokenID
        uint256 realId = startingIndex.add(tokenId) % maxTokenSupply;

        return bytes(baseURI).length > 0
            ? string(abi.encodePacked(baseURI, Strings.toString(realId), string(".json")))
            : "";
    }

    /**
     * Get current balance of contract (Owner only)
     */
    function getBalance() public view onlyOwner returns (uint)  {
        uint balance = address(this).balance;
        return balance;
    }

    /**
     * Withdraw all funds from contract (Owner only)
     */
    function withdrawFunds() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    /**
     * Withdraw specified amount of funds from contract (Owner only)
     */
    function withdrawAmount(uint amount) public onlyOwner {
        require(amount <= address(this).balance);
        payable(msg.sender).transfer(amount);
    }

    /**
     * Override for ERC721Enumerable
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721Pausable, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * Override for ERC721Enumerable
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}