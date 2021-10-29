// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

/**
 * @title The Collectors ERC-721 Smart Contract
 */

contract TheCollectors is ERC721Enumerable, Ownable, Pausable, ReentrancyGuard {

    string public THECOLLECTORS_PROVENANCE = "";
    string private baseURI;
    uint256 public numTokensMinted = 0;
    uint256 public constant RESERVED_TOKENS = 20;

    // PUBLIC MINT
    uint256 public constant TOKEN_PRICE = 60000000000000000; // 0.06 ETH
    uint256 public constant MAX_TOKENS_PURCHASE = 5;
    uint256 public constant MAX_TOKENS = 8888;
    bool public mintIsActive = false;

    // WALLET BASED PRESALE MINT
    uint256 public constant PRESALE_TOKEN_PRICE = 60000000000000000; // 0.06 ETH
    uint256 public constant MAX_TOKENS_PURCHASE_PRESALE = 2;
    bool public presaleIsActive = false;
    mapping (address => bool) public presaleWalletList;


    constructor() ERC721("The Collectors", "COLLECTOR") {}

    // PUBLIC MINT
    function flipMintState() public onlyOwner {
        mintIsActive = !mintIsActive;
    }

    function mint(uint256 numberOfTokens) public payable nonReentrant{
        require(!paused(), "Pausable: paused"); // Toggle if pausing should suspend minting
        require(mintIsActive, "Mint is not active.");
        require(numberOfTokens <= MAX_TOKENS_PURCHASE, "You went over max tokens per transaction.");
        require(numTokensMinted + numberOfTokens <= MAX_TOKENS, "Not enough tokens left to mint that many");
        require(TOKEN_PRICE * numberOfTokens <= msg.value, "You sent the incorrect amount of ETH.");

        for (uint256 i = 0; i < numberOfTokens; i++) {
            uint256 mintIndex = numTokensMinted;
            if (numTokensMinted < MAX_TOKENS) {
                numTokensMinted++;
                _safeMint(msg.sender, mintIndex);
            }
        }
    }

    // WALLET BASED PRESALE
    function flipPresaleState() public onlyOwner {
	    presaleIsActive = !presaleIsActive;
    }

    function initPresaleWalletList(address[] memory walletList) external onlyOwner {
	    for (uint i; i < walletList.length; i++) {
		    presaleWalletList[walletList[i]] = true;
	    }
    }

    function mintPresale(uint256 numberOfTokens) external payable nonReentrant{
        require(!paused(), "Pausable: paused"); // Toggle if pausing should suspend minting
	    require(presaleIsActive, "Presale is not active");
	    require(presaleWalletList[msg.sender] == true, "You are not on the presale waller list or have already minted");
	    require(numberOfTokens <= MAX_TOKENS_PURCHASE_PRESALE, "You went over max tokens per transaction.");
	    require(numTokensMinted + numberOfTokens <= MAX_TOKENS, "Not enough tokens left to mint that many");
	    require(PRESALE_TOKEN_PRICE * numberOfTokens <= msg.value, "You sent the incorrect amount of ETH.");

	    for (uint256 i = 0; i < numberOfTokens; i++) {
		    uint256 mintIndex = numTokensMinted;
		    if (numTokensMinted < MAX_TOKENS) {
			    numTokensMinted++;
			    _safeMint(msg.sender, mintIndex);
		    }
	    }
	    presaleWalletList[msg.sender] = false;
    }

    // BURN IT 
    function burn(uint256 tokenId) public virtual {
	    require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721Burnable: caller is not owner nor approved");
	    _burn(tokenId);
    }

    // OWNER FUNCTIONS
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        Address.sendValue(payable(owner()), balance);
    }

    function reserveTokens() external onlyOwner {
        uint256 mintIndex = numTokensMinted;
        for (uint256 i = 0; i < RESERVED_TOKENS; i++) {
            numTokensMinted++;
            _safeMint(msg.sender, mintIndex + i);
        }
    }

    function setPaused(bool _setPaused) public onlyOwner {
	    return (_setPaused) ? _pause() : _unpause();
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory uri) external onlyOwner {
        baseURI = uri;
    }

    function setProvenanceHash(string memory provenanceHash) public onlyOwner {
        THECOLLECTORS_PROVENANCE = provenanceHash;
    }

    // Toggle this function if pausing should suspend transfers
    function _beforeTokenTransfer(
	    address from,
	    address to,
	    uint256 tokenId
    ) internal virtual override(ERC721Enumerable) {
	    require(!paused(), "Pausable: paused");
	    super._beforeTokenTransfer(from, to, tokenId);
    }
}