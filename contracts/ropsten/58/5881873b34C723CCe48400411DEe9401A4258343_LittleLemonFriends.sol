// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721EnumerableLemon.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

/**
 * 
 * ###############################################################################
 * ###############################################################################
 * #############################(,...............)################################
 * #######################*,,,............................########################
 * ###################,,,,,..................................#####################
 * ################*,,,,.......................................(##################
 * ###############,,,,...........................................(################
 * #############,,,,,..............................................###############
 * ###########/,,,,...................LITTLE.........................#############
 * ##########,,,,,,......................................................#########
 * ######,,,,,,,,,.....................LEMON................................(#####
 * ####,,,,,,,,,,.............................................................####
 * ###,,,,,,,,,,,.....................FRIENDS................................#####
 * ####,,,,,,,,,,,.........................................................#######
 * #########(,,,,,......................................................(#########
 * ###########*,,,,...................................................############
 * #############,,,,.................................................#############
 * ##############(,,,,.............................................###############
 * ################,,,,,.........................................,################
 * ###################,,,,......................................(#################
 * #####################,,,,,................................,####################
 * #######################(,,,...........................#########################       
 * #############################(.................)###############################           
 * ###############################################################################                    
 *
 * @title Little Lemon Friends ERC-721 Smart Contract
 */

abstract contract CoolCats {
   function balanceOf(address owner) external virtual view returns (uint256 balance);
}

contract LittleLemonFriends is ERC721EnumerableLemon, Ownable, Pausable, ReentrancyGuard {

    string public LITTLELEMONFRIENDS_PROVENANCE = "";
    string private baseURI;
    uint256 public numTokensMinted = 0;
    uint256 public numBurnedTokens = 0;
    uint256 public constant RESERVED_TOKENS = 20;
    uint256 public constant MAX_TOKENS = 9999;

    // PUBLIC MINT
    uint256 public constant MAX_TOKENS_PUBLIC_MINT = 9799;
    uint256 public constant TOKEN_PRICE = 25000000000000000; // 0.025 ETH
    uint256 public constant MAX_TOKENS_PURCHASE = 5;
    bool public mintIsActive = false;

    // WALLET BASED PRESALE MINT
    bool public presaleIsActive = false;
    mapping (address => bool) public presaleWalletList;

    // COOL CATS PRESALE
    // cool cats mainnet contract 0x1A92f7381B9F03921564a437210bB9396471050C
    /// bayc ropsten  0xA0a62B858C559e56d8eB7be600EeF42BcE5D0d20
    // lolcal test 0x5FbDB2315678afecb367f032d93F642f64180aa3

    CoolCats private coolcats = CoolCats(0xA0a62B858C559e56d8eB7be600EeF42BcE5D0d20);
    uint256 public constant MAX_TOKENS_PURCHASE_PRESALE = 2;
    bool public collectionPresaleIsActive = false;
    mapping (address => bool) public collectionWalletsMinted;

    constructor() ERC721("Little Lemon Friends", "LEMON") {}

    // PUBLIC MINT
    function flipMintState() external onlyOwner {
        mintIsActive = !mintIsActive;
    }

    function mintLemons(uint256 numberOfTokens) external payable nonReentrant{
        require(!paused(), "Pausable: paused"); // Toggle if pausing should suspend minting
        require(mintIsActive, "Mint is not active");
        require(
            numberOfTokens <= MAX_TOKENS_PURCHASE, 
            "You went over max tokens per transaction"
        );
        require(
            numTokensMinted + numberOfTokens <= MAX_TOKENS_PUBLIC_MINT, 
            "Not enough tokens left to mint that many"
        );
        require(
            TOKEN_PRICE * numberOfTokens <= msg.value, 
            "You sent the incorrect amount of ETH"
        );

        for (uint256 i = 0; i < numberOfTokens; i++) {
            uint256 mintIndex = numTokensMinted;
            if (numTokensMinted < MAX_TOKENS_PUBLIC_MINT) {
                numTokensMinted++;
                _safeMint(msg.sender, mintIndex);
            }
        }
    }

    // WALLET BASED PRESALE
    function flipPresaleState() external onlyOwner {
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
	    require(
            presaleWalletList[msg.sender] == true, 
            "You are not on the presale wallet list or have already minted"
        );
	    require(
            numberOfTokens <= MAX_TOKENS_PURCHASE, 
            "You went over max tokens per transaction"
        );
	    require(
            numTokensMinted + numberOfTokens <= MAX_TOKENS_PUBLIC_MINT, 
            "Not enough tokens left to mint that many"
        );
	    require(
            TOKEN_PRICE * numberOfTokens <= msg.value, 
            "You sent the incorrect amount of ETH"
        );

	    for (uint256 i = 0; i < numberOfTokens; i++) {
		    uint256 mintIndex = numTokensMinted;
		    if (numTokensMinted < MAX_TOKENS_PUBLIC_MINT) {
			    numTokensMinted++;
			    _safeMint(msg.sender, mintIndex);
		    }
	    }
	    presaleWalletList[msg.sender] = false;
    }

    // NFT COLLECTION PRESALE
    function flipCollectionPresaleMintState() external onlyOwner {
        collectionPresaleIsActive = !collectionPresaleIsActive;
    }

    function qualifyForCollectionPresaleMint(address _owner) external view returns (bool) {
        return coolcats.balanceOf(_owner) > 0;
    }

    function mintCollectionPresale(uint256 numberOfTokens) external payable nonReentrant{
        require(!paused(), "Pausable: paused"); // Toggle if pausing should suspend minting
        require(collectionPresaleIsActive, "NFT Collection Mint is not active");
        require(collectionWalletsMinted[msg.sender] == false, "You have already minted!");
        require(coolcats.balanceOf(msg.sender) > 0, "You are not a member of Coolcats!");
        require(
            numberOfTokens <= MAX_TOKENS_PURCHASE_PRESALE,
            "You went over max tokens per transaction"
        );
	    require(
            numTokensMinted + numberOfTokens <= MAX_TOKENS_PUBLIC_MINT, 
            "Not enough tokens left to mint that many"
        );
        require(
            TOKEN_PRICE * numberOfTokens <= msg.value, 
            "You sent the incorrect amount of ETH."
        );

        for (uint256 i = 0; i < numberOfTokens; i++) {
		    uint256 mintIndex = numTokensMinted;
		    if (numTokensMinted < MAX_TOKENS_PUBLIC_MINT) {
			    numTokensMinted++;
			    _safeMint(msg.sender, mintIndex);
		    }
	    }

        collectionWalletsMinted[msg.sender] = true;
    }

    // BURN IT 
    function burn(uint256 tokenId) external virtual {
	    require(
            _isApprovedOrOwner(_msgSender(), tokenId), 
            "ERC721Burnable: caller is not owner nor approved"
        );
        numBurnedTokens++;
	    _burn(tokenId);
    }

    // TOTAL SUPPLY
    function totalSupply() external view returns (uint) { 
        return numTokensMinted - numBurnedTokens;
    }

    // OWNER FUNCTIONS
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        Address.sendValue(payable(owner()), balance);
    }

    function reserveTokens(uint256 numberOfTokens) external onlyOwner {
        require(
            numTokensMinted + numberOfTokens <= MAX_TOKENS, 
            "Not enough tokens left to mint that many"
        );
	
         for (uint256 i = 0; i < numberOfTokens; i++) {
		    uint256 mintIndex = numTokensMinted;
		    numTokensMinted++;
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

    function setProvenanceHash(string memory provenanceHash) external onlyOwner {
        LITTLELEMONFRIENDS_PROVENANCE = provenanceHash;
    }

    // Toggle this function if pausing should suspend transfers
    function _beforeTokenTransfer(
	    address from,
	    address to,
	    uint256 tokenId
    ) internal virtual override(ERC721EnumerableLemon) {
	    require(!paused(), "Pausable: paused");
	    super._beforeTokenTransfer(from, to, tokenId);
    }
}