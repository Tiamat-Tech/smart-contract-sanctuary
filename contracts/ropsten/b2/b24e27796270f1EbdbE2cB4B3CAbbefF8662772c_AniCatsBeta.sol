// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AniCatsBeta is ERC721, Ownable {
    address constant public CHARITY_ADDRESS = 0x897fe74d43CDA5003dB8917DFC53eA770D12ef71; // Public charity 5% to Best Friends Animal Society

    uint constant public TICKET_ID = 0;
    uint constant public MAX_SUPPLY = 9000; // 9000 unique AniCats will be in total.
    uint constant public PRICE = 0.07 ether; // 0.07 ETH + gas per transaction

    string private _apiURI;
    uint private _presaleTokensLimit = 1000;
    uint private _reservedTokensLimit = 200; // 200 AniCats will be reserved for marketing needs.
    
    
    uint private _tokensPerMintLimit = 20; // Up to 20 AniCats per transaction.
    uint private _presaleTokensPerMintLimit = 10; // Up to 10 AniCats per transaction during the presale.
    uint private _presaleTokensPerWalletLimit = 10; // Up to 10 AniCats per unique wallet during the presale.

    bool public _isClaimingAvailable = true;
    bool public _isMintingAvailable = true;
    bool public _isPresaleAvailable = true;
    uint public _tokensMinted = 0;
    uint public _presaleTokensMinted = 0;

    mapping(address => bool) public _presaleList;
    mapping(address => uint) public _claimedWithMintpass;

    IERC1155 public _mintPassContract;
    IERC721 public _friendContract = ERC721(0x1A92f7381B9F03921564a437210bB9396471050C); // Cool Cats https://www.coolcatsnft.com/

    constructor() ERC721("AniCatsBeta", "ANCV1") {
        mintNFTs(1); // auto mint to the team
    }

    function _baseURI() internal view override returns (string memory) {
        return _apiURI;
    }

    // Admin methods region
    function configure(
        IERC1155 mintPassContract,
        bool isClaimingAvailable,
        bool isMintingAvailable,
        bool isPresaleAvailable
    ) external onlyOwner {
        _mintPassContract = mintPassContract;
        _isMintingAvailable = isMintingAvailable;
        _isPresaleAvailable = isPresaleAvailable;
        _isClaimingAvailable = isClaimingAvailable;
    }

    function setBaseURI(string memory uri) external onlyOwner {
        _apiURI = uri;
    }

    function setIsMintingAvailable(bool state) external onlyOwner {
        _isMintingAvailable = state;
    }
    function setIsClaimingAvailable(bool state) external onlyOwner {
        _isClaimingAvailable = state;
    }
    function setIsPresaleAvailable(bool state) external onlyOwner {
        _isPresaleAvailable = state;
    }
    function setReservedTokenLimit(uint limit) external onlyOwner() {
        _reservedTokensLimit = limit;
    }

    function setPresaleTokenLimit(uint limit) external onlyOwner() {
        _presaleTokensLimit = limit;
    }

    function giveAway(address to, uint256 amount) external onlyOwner {
        require(amount <= _reservedTokensLimit, "Not enough reserve left for team");
        uint fromToken = _tokensMinted + 1;
        _tokensMinted += amount;
        for (uint i = 0; i < amount; i++) {
            _mint(to, fromToken + i);
        }
        _reservedTokensLimit -= amount;
    }

    function withdraw(address to) external onlyOwner {
        uint balance = address(this).balance;
        uint share = balance * 5 / 100; // 5% goes to a charity wallet

        payable(CHARITY_ADDRESS).transfer(share);
        payable(to).transfer(balance - share);
    }
    // endregion

    // Presale helper methodsregion
    function addToPresale(address wallet) public onlyOwner() {
        _presaleList[wallet] = true;
    }

    function removeFromPresale(address wallet) public onlyOwner() {
        _presaleList[wallet] = false;
    }
    
    function addToPresaleMany(address[] memory wallets) public onlyOwner() {
        for(uint256 i = 0; i < wallets.length; i++) {
            addToPresale(wallets[i]);
        }
    }

    function removeFromPresaleMany(address[] memory wallets) public onlyOwner() {
        for(uint256 i = 0; i < wallets.length; i++) {
            removeFromPresale(wallets[i]);
        }
    }
    // endregion

    // Claim a token using Mintpass ticket 
    function claim(uint amount) external {
        require(_isClaimingAvailable, "Claiming is not available");
        require(_tokensMinted + amount <= MAX_SUPPLY - _reservedTokensLimit - _presaleTokensLimit, "Tokens supply reached limit");
        
        uint tickets = _mintPassContract.balanceOf(msg.sender, TICKET_ID);
        require(_claimedWithMintpass[msg.sender] + amount <= tickets, "Insufficient Mintpasses balance");
        _claimedWithMintpass[msg.sender] += amount;
        mintNFTs(amount);
    }

    function mintPrice(uint amount) public pure returns (uint) {
        return amount * PRICE;
    }

    // Main sale mint
    function mint(uint amount) external payable {
        require(_isMintingAvailable, "Minting is not available");
        require(_tokensMinted + amount <= MAX_SUPPLY - _reservedTokensLimit, "Tokens supply reached limit");
        require(amount > 0 && amount <= _tokensPerMintLimit, "Can only mint 20 tokens at a time");
        require(mintPrice(amount) == msg.value, "Wrong ethers value");

        mintNFTs(amount);
    }

    // Presale mint
    function presaleMint(uint amount) external payable {
        require(_isPresaleAvailable, "Presale is not available");
        require(_presaleTokensMinted + amount <= _presaleTokensLimit, "Presale tokens supply reached limit"); // Only presale token validation
        require(_tokensMinted + amount <= MAX_SUPPLY - _reservedTokensLimit, "Tokens supply reached limit"); // Total tokens validation
        require(amount > 0 && amount <= _presaleTokensPerMintLimit, "Can only mint 20 tokens at a time");
    
        require(presaleAllowedForWallet(), "Sorry you are not on the presale list");
        require(mintPrice(amount) == msg.value, "Wrong ethers value");
        require(balanceOf(msg.sender) + amount <= _presaleTokensPerWalletLimit, "Can only mint 10 tokens during the presale per wallet");

        _presaleTokensMinted += amount;
        mintNFTs(amount);
    }
    
    // Validate if sender owns a mintpass or a friend collection token (Cool Cats) or in the presale list
    function presaleAllowedForWallet() public view returns(bool) {
        return _presaleList[msg.sender] ||
               _friendContract.balanceOf(msg.sender) > 0 ||
               _mintPassContract.balanceOf(msg.sender, TICKET_ID) > 0;
    }

    function mintNFTs(uint amount) internal {
        uint fromToken = _tokensMinted + 1;
        _tokensMinted += amount;
        for (uint i = 0; i < amount; i++) {
            _mint(msg.sender, fromToken + i);
        }
    }
}