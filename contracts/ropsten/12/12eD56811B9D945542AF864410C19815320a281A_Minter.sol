// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./IToken.sol";

contract Minter is Ownable, ReentrancyGuard {

    // ======== Supply =========
    uint256 public constant MAX_MINTS_PER_TX = 20;
    uint256 public constant MINTS_PER_WHITELIST = 1;
    uint256 public maxMintsPerAddress;
    uint256 public maxTokens;

    // ======== Cost =========
    uint256 public constant TOKEN_COST = 0.08 ether;

    // ======== Sale Status =========
    bool public saleIsActive = false;
    uint256 public immutable preSaleStart; // Whitelist start date/time
    uint256 public immutable publicSaleStart; // Public sale start  date/time

    // ======== Claim Tracking =========
    mapping(address => uint256) private addressToMintCount;
    mapping(address => bool) public whitelistClaimed;

    // ======== Whitelist Validation =========
    bytes32 public whitelistMerkleRoot;

    // ======== External Storage Contract =========
    IToken public immutable token;

    // ======== Constructor =========
    constructor(address contractAddress,
                uint256 preSaleStartTimestamp,
                uint256 publicSaleStartTimestamp,
                uint256 tokenSupply,
                uint256 maxMintsAddress) {
        token = IToken(contractAddress);
        preSaleStart = preSaleStartTimestamp;
        publicSaleStart = publicSaleStartTimestamp;
        maxTokens = tokenSupply;
        maxMintsPerAddress = maxMintsAddress;
    }

    // ======== Modifier Checks =========
    modifier isWhitelistMerkleRootSet() {
        require(whitelistMerkleRoot != 0, "Whitelist merkle root not set!");
        _;
    }

    modifier isValidMerkleProof(address _address, bytes32[] calldata merkleProof) {
        require(
            MerkleProof.verify(
                merkleProof,
                whitelistMerkleRoot,
                keccak256(abi.encodePacked(_address))
            ),
            "Address is not on whitelist!"
        );
        _;
    }
    
    modifier isSupplyAvailable(uint256 numberOfTokens) {
        uint256 supply = token.tokenCount();
        require(supply + numberOfTokens <= maxTokens, "Exceeds max token supply!");
        _;
    }
    
    modifier isPaymentCorrect(uint256 numberOfTokens) {
        require(msg.value >= TOKEN_COST * numberOfTokens, "Invalid ETH value sent!");
        _;
    }

    modifier isSaleActive() {
        require(saleIsActive, "Sale is not active!");
        _;
    }

    modifier isSaleStarted(uint256 saleStartTime) {
        require(block.timestamp >= saleStartTime, "Sale not started!");
        _;
    }

    modifier isMaxMintsPerWalletExceeded(uint amount) {
        require(addressToMintCount[msg.sender] + amount <= MAX_MINTS_PER_TX, "Exceeds max mint per tx!");
        _;
    }

    // ======== Mint Functions =========
    function mintWhitelist(bytes32[] calldata merkleProof) public payable 
        isSaleActive()
        isSaleStarted(preSaleStart)
        isWhitelistMerkleRootSet()
        isValidMerkleProof(msg.sender, merkleProof) 
        isSupplyAvailable(MINTS_PER_WHITELIST) 
        isPaymentCorrect(MINTS_PER_WHITELIST)
        isMaxMintsPerWalletExceeded(MINTS_PER_WHITELIST)
        nonReentrant {
            require(!whitelistClaimed[msg.sender], "Whitelist is already claimed by this wallet!");

            token.mint(MINTS_PER_WHITELIST, msg.sender);

            addressToMintCount[msg.sender] += MINTS_PER_WHITELIST;

            whitelistClaimed[msg.sender] = true;
    }

    function mintPublic(uint amount) public payable 
        isSaleActive()
        isSaleStarted(publicSaleStart)
        isSupplyAvailable(amount) 
        isPaymentCorrect(amount)
        isMaxMintsPerWalletExceeded(amount)
        nonReentrant  {
            require(amount <= MAX_MINTS_PER_TX, "Exceeds max mint per tx!");

            token.mint(amount, msg.sender);

            addressToMintCount[msg.sender] += amount;
    }

    function mintTeamTokens(address _to, uint256 _reserveAmount) public 
        onlyOwner 
        isSupplyAvailable(_reserveAmount) {
            token.mint(_reserveAmount, _to);
    }

    // ======== Whitelisting =========
    function setWhitelistMerkleRoot(bytes32 merkleRoot) external onlyOwner {
        whitelistMerkleRoot = merkleRoot;
    }

    function isWhitelisted(address _address, bytes32[] calldata merkleProof) external view
        isValidMerkleProof(_address, merkleProof) 
        returns (bool) {            
            require(!whitelistClaimed[_address], "Whitelist is already claimed by this wallet");

            return true;
    }

    function isWhitelistClaimed(address _address) external view returns (bool) {
        return whitelistClaimed[_address];
    }

    // ======== Utilities =========
    function mintCount(address _address) external view returns (uint) {
        return addressToMintCount[_address];
    }

    function isPreSaleActive() external view returns (bool) {
        return block.timestamp >= preSaleStart && block.timestamp < publicSaleStart && saleIsActive;
    }

    function isPublicSaleActive() external view returns (bool) {
        return block.timestamp >= publicSaleStart && saleIsActive;
    }

    // ======== State Management =========
    function flipSaleStatus() public onlyOwner {
        saleIsActive = !saleIsActive;
    }
 
    // ======== Token Supply Management=========
    function setMaxMintPerAddress(uint _max) public onlyOwner {
        maxMintsPerAddress = _max;
    }

    function decreaseTokenSupply(uint256 newMaxTokenSupply) external onlyOwner {
        require(maxTokens > newMaxTokenSupply, "Max token supply can only be decreased!");
        maxTokens = newMaxTokenSupply;
    }

    // ======== Withdraw =========
    function withdraw() public payable onlyOwner {
        uint balance = address(this).balance;
        require(payable(msg.sender).send(balance));
    }
}