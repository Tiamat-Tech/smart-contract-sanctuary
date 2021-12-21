// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

/**
 * @title Myth Division All Access Token ERC1155 Smart Contract
 * @dev Extends ERC1155 
 */

contract MythDivisionAllAccessToken is ERC1155, ERC1155Supply, ERC1155Burnable, ERC1155Pausable, Ownable, PaymentSplitter {
    string private _contractURI;
    address public minterAddress;
    uint256 public mintingTokenID = 0;

    /// PUBLIC MINT
    uint256 public tokenPricePublic = 1.0 ether; 
    bool public mintIsActivePublic = false;
    uint256 public maxTokensPerTransactionPublic = 5;
    uint256 public numberMintedPublic = 0;
    uint256 public maxTokensPublic  = 100;

    /// PRESALE MINT
    uint256 public tokenPricePresale = 0.5 ether;
    bool public mintIsActivePresale = false;
    mapping (address => bool) public presaleWalletList;
    uint256 public maxTokensPerTransactionPresale = 2;
    uint256 public numberMintedPresale = 0;
    uint256 public maxTokensPresale = 250;

    /// FREE WALLET BASED MINT
    bool public mintIsActiveFree = false;
    mapping (address => bool) public freeWalletList;

    constructor(address[] memory _payees, uint256[] memory _shares) ERC1155("") PaymentSplitter(_payees, _shares) {}

    /// @title PUBLIC MINT

    /**
     * @dev turn on/off public mint
     */
    function flipMintStatePublic() external onlyOwner {
         mintIsActivePublic = !mintIsActivePublic;
    }

    /**
     * @dev public mint function
     */
    function mint(uint256 numberOfTokens) external payable {
        require(mintIsActivePublic, "Mint is not active");
        require(
            numberOfTokens <= maxTokensPerTransactionPublic, 
            "You went over max tokens per transaction"
        );
        require(
	        msg.value >= tokenPricePublic * numberOfTokens,
            "You sent the incorrect amount of ETH"
        );
        require(
            numberMintedPublic + numberOfTokens <= maxTokensPublic, 
            "Not enough tokens left to mint that many"
        );

        _mint(msg.sender, mintingTokenID, numberOfTokens, "");
        numberMintedPublic += numberOfTokens;
    }

    /// @title PRESALE WALLET MINT

    /**
     * @dev turn on/off presale wallet mint
     */
    function flipPresaleMintState() external onlyOwner {
        mintIsActivePresale = !mintIsActivePresale;
    }

    /**
     * @dev add wallets to presale wallet list
     */
    function initPresaleWalletList(address[] memory walletList) external onlyOwner {
	    for (uint i; i < walletList.length; i++) {
		    presaleWalletList[walletList[i]] = true;
	    }
    }

    /**
     * @dev presale wallet mint for wallets in presaleWalletList
     */
    function mintPresale(uint256 numberOfTokens) external payable {
        require(mintIsActivePresale, "Mint is not active");
        require(
            numberOfTokens <= maxTokensPerTransactionPresale, 
            "You went over max tokens per transaction"
        );
        require(
	        msg.value >= tokenPricePresale * numberOfTokens,
            "You sent the incorrect amount of ETH"
        );
        require(
            presaleWalletList[msg.sender] == true, 
            "You are not on the presale wallet list or have already minted"
        );
        require(
            numberMintedPresale + numberOfTokens <= maxTokensPresale, 
            "Not enough tokens left to mint that many"
        );

        _mint(msg.sender, mintingTokenID, numberOfTokens, "");
        numberMintedPresale += numberOfTokens;

        presaleWalletList[msg.sender] = false;
    }


    /// @title Free Wallet Mint

    /**
     * @dev turn on/off free wallet mint
     */
    function flipFreeWalletState() external onlyOwner {
	    mintIsActiveFree = !mintIsActiveFree;
    }

    /**
     * @dev data structure for uploading free mint wallets
     */
    function initFreeWalletList(address[] memory walletList) external onlyOwner {
	    for (uint256 i = 0; i < walletList.length; i++) {
		    freeWalletList[walletList[i]] = true;
	    }
    }

    /**
     * @dev one free mint for wallets in freeWalletList 
     */
    function mintFreeWalletList() external {
        require(mintIsActiveFree, "Mint is not active");
	    require(
            freeWalletList[msg.sender] == true, 
            "You are not on the free wallet list or have already minted"
        );

        _mint(msg.sender, mintingTokenID, 1, "");

	    freeWalletList[msg.sender] = false;
    }

    /**
     * @dev get contractURI
     */
    function contractURI() public view returns (string memory) {
	    return _contractURI;
    }

    // OWNER FUNCTIONS

    /**
    *  @dev reserve mint a token
    */
    function mintReserve(uint256 id, uint256 numberOfTokens) public onlyOwner {
        _mint(msg.sender, id, numberOfTokens, "");
    }

   /**
    * @dev enable additional wallet to airdrop tokens
    */
    modifier onlyMinter {
	    require(minterAddress == msg.sender, "You must have the Minter role");
	    _;
    }

    /**
    * @dev airdrop a specific token to a list of addresses
    */
    function airdrop(address[] calldata addresses, uint id, uint amt_each) public onlyMinter {
        for (uint i=0; i < addresses.length; i++) {
            _mint(addresses[i], id, amt_each, "");
        }
    }
  
    /**
     *  @dev Pauses all token transfers.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev Total amount of tokens in with a given id.
     */
    // function totalSupply(uint256 id) public view virtual returns (uint256) {
    //     return _totalSupply[id];
    // }

    /**
     * @dev Withdraw ETH in contract to ownership wallet
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        Address.sendValue(payable(owner()), balance);
    }

    // @title SETTER FUNCTIONS

    /**
    *  @dev set airdrop minter address
    */
   function setMinterAddress(address minter) public onlyOwner {
	    minterAddress = minter;
    }

    /**
    *  @dev set contract uri
    */
    function setContractURI(string memory newContractURI) public onlyOwner {
        _contractURI = newContractURI;
    }

    /**
    *  @dev set base URI
    */
    function setURI(string memory baseURI) public onlyOwner {
        _setURI(baseURI);
    }

    /**
    *  @dev set token price of presale - tokenPricePublic
    */
    function setTokenPricePublic(uint256 tokenPrice) external onlyOwner {
        require(tokenPrice >= 0, "Must be greater or equal then zer0");
        tokenPricePublic = tokenPrice;
    }

    /**
    *  @dev set max tokens allowed minted in public sale - maxTokensPublic
    */
    function setMaxTokensPublic (uint256 amount) external onlyOwner {
        require(amount >= 0, "Must be greater or equal than zer0");
        maxTokensPublic = amount;
    }

    /**
    *  @dev set total number of tokens minted in public sale - numberMintedPublic
    */
    function setNumberMintedPublic(uint256 amount) external onlyOwner {
        require(amount >= 0, "Must be greater or equal than zer0");
        numberMintedPublic = amount;
    }

    /**
    *  @dev set max tokens per transaction for public sale - maxTokensPerTransactionPublic 
    */
    function setMaxTokensPerTransactionPublic(uint256 amount) external onlyOwner {
        require(amount >= 0, "Invalid amount");
        maxTokensPerTransactionPublic = amount;
    }

    /**
    *  @dev set token price of presale - tokenPricePresale
    */
    function setTokenPricePresale(uint256 tokenPrice) external onlyOwner {
        require(tokenPrice >= 0, "Must be greater or equal than zer0");
        tokenPricePresale = tokenPrice;
    }

    /**
    *  @dev set max tokens allowed minted in presale - maxTokensPresale
    */
    function setMaxTokensPresale(uint256 amount) external onlyOwner {
        require(amount >= 0, "Invalid amount");
        maxTokensPresale = amount;
    }

    /**
    *  @dev set total number of tokens minted in presale - numberMintedPresale
    */
    function setNumberMintedPresale(uint256 amount) external onlyOwner {
        require(amount >= 0, "Invalid amount");
        numberMintedPresale = amount;
    }

    /**
    *  @dev set max tokens per transaction for presale - maxTokensPerTransactionPresale 
    */
    function setMaxTokensPerTransactionPresale(uint256 amount) external onlyOwner {
        require(amount >= 0, "Invalid amount");
        maxTokensPerTransactionPresale = amount;
    }

    /**
    *  @dev set the current token ID minting - mintingTokenID
    */
    function setMintingTokenID(uint256 tokenID) external onlyOwner {
        require(tokenID >= 0, "Invalid token id");
        mintingTokenID = tokenID;
    }

    /**
    *  @dev set the current token ID minting and reset all counters and active mints to 0 and false respectively
    */
    function setMintingTokenIdAndResetState(uint256 tokenID) external onlyOwner {
	    require(tokenID >= 0, "Invalid token id");
	    mintingTokenID = tokenID;

	    mintIsActivePublic = false;
	    mintIsActivePresale = false;
	    mintIsActiveFree = false;

	    numberMintedPresale = 0;
	    numberMintedPublic = 0;
    }
    

    function release(address payable account) public override {
        require(msg.sender == account || msg.sender == owner(), "Release: no permission");

        super.release(account);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155, ERC1155Supply, ERC1155Pausable) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

}