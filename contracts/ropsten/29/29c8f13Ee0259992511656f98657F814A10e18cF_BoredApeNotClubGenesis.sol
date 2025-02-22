// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Bored Ape Not Club Genesis ERC-721 Smart Contract
 */

contract BoredApeNotClubGenesis is ERC721, Ownable, Pausable, ReentrancyGuard {

    string private baseURI;
    uint256 public maxTokens = 95;
    uint256 public mintTokenIndex = 86;
    uint256 public numTokensMinted = 0; 
    uint256 public numTokensBurned = 0;

    // PUBLIC MINT
    uint256 public tokenPrice = 0.05 ether;
    uint256 public maxTokensPurchased = 1;
    bool public mintIsActive = false;

    // FREE WALLET BASED MINT
    bool public freeWalletIsActive = false;
    mapping (address => bool) public freeWalletList;


    constructor() ERC721("Bored Ape Not Club", "BANC") {}

    // PUBLIC MINT
    function flipMintState() external onlyOwner {
        mintIsActive = !mintIsActive;
    }

    function mint(uint256 numberOfTokens) external payable nonReentrant{
        require(!paused(), "Pausable: paused"); // Toggle if pausing should suspend minting
        require(mintIsActive, "Mint is not active");
        require(numberOfTokens > 0 && numberOfTokens <= maxTokensPurchased, "You went over max tokens per transaction");
        require(mintTokenIndex + numberOfTokens - 1 <= maxTokens, "Not enough tokens left to mint that many");
        require(tokenPrice * numberOfTokens <= msg.value, "You sent the incorrect amount of ETH");

        for (uint256 i = 0; i < numberOfTokens; i++) {
            uint256 mintIndex = mintTokenIndex;
            numTokensMinted++;
            mintTokenIndex++;
            _safeMint(msg.sender, mintIndex);
        }
    }

    // FREE WALLET BASED GIVEAWAY MINT - Only Mint One
    function flipFreeWalletState() external onlyOwner {
	    freeWalletIsActive = !freeWalletIsActive;
    }

    function initFreeWalletList(address[] memory walletList) external onlyOwner {
	    for (uint256 i = 0; i < walletList.length; i++) {
		    freeWalletList[walletList[i]] = true;
	    }
    }

    function mintFreeWalletList() external nonReentrant {
        require(freeWalletIsActive, "Mint is not active");
	    require(freeWalletList[msg.sender] == true, "You are not on the free wallet list or have already minted");
	    require(mintTokenIndex <= maxTokens, "Not enough tokens left to mint that many");

        freeWalletList[msg.sender] = false;

        uint256 mintIndex = mintTokenIndex;
        numTokensMinted++;
        mintTokenIndex++;
        _safeMint(msg.sender, mintIndex);
    }

    // TOTAL SUPPLY
    function totalSupply() external view returns (uint) { 
        return numTokensMinted - numTokensBurned;
    }

    // BURN IT 
    function burn(uint256 tokenId) public virtual {
	    require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721Burnable: caller is not owner nor approved");
        _burn(tokenId);
    }

    // OWNER FUNCTIONS
    /**
    *  @notice withdraw funds 
    */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        Address.sendValue(payable(owner()), balance);
    }

    /**
    *  @notice mint to wallet 
    *  @dev next sequential token id
    */
    function mintTokenToWallet(address toWallet, uint256 tokenId) public onlyOwner {
        require(!_exists(tokenId), "ERC721: approved query for nonexistent token");
        numTokensMinted++;
        _safeMint(toWallet, tokenId);
    }

    /**
    *  @notice mint tokens ids to wallet
    */
    function mintTokensToWallet(address toWallet, uint256[] calldata tokens) public onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            require(!_exists(tokens[i]), "ERC721: approved query for nonexistent token");
            numTokensMinted++;
            _safeMint(toWallet, tokens[i]);
        }
    }

    /**
    *  @notice reserve mint 
    *  @dev next sequential token id
    */
    function reserveMint(uint256 numberOfTokens) external onlyOwner {
        for (uint256 i = 0; i < numberOfTokens; i++) {
            uint256 mintIndex = mintTokenIndex;
            numTokensMinted++;
            mintTokenIndex++;
            _safeMint(msg.sender, mintIndex);
        }
    }

    function setPaused(bool _setPaused) external onlyOwner {
	    return (_setPaused) ? _pause() : _unpause();
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory uri) external onlyOwner {
        baseURI = uri;
    }

    /**
    *  @notice Set total tokens of collection - maxTokens
    */
    function setMaxTokens(uint256 amount) external onlyOwner {
        require(amount >= 0, "Must be greater or equal than zer0");
        maxTokens = amount;
    }

    /**
    *  @notice Set token price  - tokenPrice
    */
    function setTokenPrice(uint256 price) external onlyOwner {
        require(tokenPrice >= 0, "Must be greater or equal then zer0");
        tokenPrice = price;
    }

    /**
    *  @notice Set max tokens allowed minted in public sale - maxTokensPublic
    */
    function setMaxTokensPurchased(uint256 amount) external onlyOwner {
        require(amount >= 0, "Must be greater or equal than zer0");
        maxTokensPurchased = amount;
    }

    /**
    *  @notice Set max tokens allowed minted in public sale - maxTokensPublic
    */
    function setMintTokenIndex(uint256 amount) external onlyOwner {
        require(amount >= 0, "Must be greater or equal than zer0");
        mintTokenIndex = amount;
    }

    // Toggle this function if pausing should suspend transfers
    function _beforeTokenTransfer(
	    address from,
	    address to,
	    uint256 tokenId
    ) internal virtual override(ERC721) {
	    require(!paused(), "Pausable: paused");

        if (to == address(0)) {
            numTokensBurned++;
        }

	    super._beforeTokenTransfer(from, to, tokenId);
    }
}