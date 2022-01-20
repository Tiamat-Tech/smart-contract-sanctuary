//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/*

*/

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract KataboliczGenesis is ERC721, IERC2981, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter private tokenCounter;

    string private baseURI;
    string public verificationHash;

    uint256 public constant MAX_PER_TXN = 1;
    uint256 public constant MAX_PER_WALLET = 1;
    uint256 public maxKatz;

    uint256 public constant SALE_PRICE = 0.125 ether;
    bool public isPublicSaleActive;

    uint256 public maxPreSaleKatz;
    bytes32 public preSaleMerkleRoot;
    bool public isPreSaleActive;

    bytes32 public claimListMerkleRoot;

    mapping(address => uint256) public presaleMintCounts;
    mapping(address => bool) public claimed;

    // ============ ACCESS CONTROL/SANITY MODIFIERS ============

    modifier publicSaleActive() {
        require(isPublicSaleActive, "Public sale is not open");
        _;
    }

    modifier preSaleActive() {
        require(isPreSaleActive, "Presale is not open");
        _;
    }

    modifier canMintKatz(uint256 numberOfTokens) {
        require(
            tokenCounter.current() + numberOfTokens <= maxKatz,
            "Not enough katz remaining to mint"
        );
        _;
    }

    modifier isCorrectPayment(uint256 price, uint256 numberOfTokens) {
        require(
            price * numberOfTokens == msg.value,
            "Incorrect ETH value sent"
        );
        _;
    }

    modifier isValidMerkleProof(bytes32[] calldata merkleProof, bytes32 root) {
        require(
            MerkleProof.verify(
                merkleProof,
                root,
                keccak256(abi.encodePacked(msg.sender))
            ),
            "Address does not exist in list"
        );
        _;
    }

        modifier maxTxn(uint256 numberOfTokens) {
        require(
            numberOfTokens <= MAX_PER_TXN,
            "Max katz to mint is three"
        );
        _;
    }


    constructor(
        uint256 _maxKatz,
        uint256 _maxPreSaleKatz
    ) ERC721("Katabolicz Genesis", "GENKATZ") {
        maxKatz = _maxKatz;
        maxPreSaleKatz = _maxPreSaleKatz;
    }

    // ---  PUBLIC MINTING FUNCTIONS ---

    // mint allows for regular minting while the supply does not exceed maxKatz.
    function mint(uint256 numberOfTokens)
        external
        payable
        nonReentrant
        isCorrectPayment(SALE_PRICE, numberOfTokens)
        publicSaleActive
        canMintKatz(numberOfTokens)
        maxTxn(numberOfTokens)
    {
        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, nextTokenId());
        }
    }

    // mintPreSale allows for minting by allowed addresses during the pre-sale.
    function mintPreSale(
        uint8 numberOfTokens,
        bytes32[] calldata merkleProof
    )
        external
        payable
        nonReentrant
        preSaleActive
        canMintKatz(numberOfTokens)
        isCorrectPayment(SALE_PRICE, numberOfTokens)
        isValidMerkleProof(merkleProof, preSaleMerkleRoot)
    {
        uint256 numAlreadyMinted = presaleMintCounts[msg.sender];

        require(
            numAlreadyMinted + numberOfTokens <= MAX_PER_WALLET,
            "Max katz to mint in Presale is one"
        );

        require(
            tokenCounter.current() + numberOfTokens <= maxPreSaleKatz,
            "Not enough katz remaining to mint"
        );

        presaleMintCounts[msg.sender] = numAlreadyMinted + numberOfTokens;

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, nextTokenId());
        }
    }

    // claim allows for a free mint by allowed addresses.
    function claim(bytes32[] calldata merkleProof)
        external
        isValidMerkleProof(merkleProof, claimListMerkleRoot)
    {
        require(!claimed[msg.sender], "You have already claimed your free Genesis Kat.");

        claimed[msg.sender] = true;

        _safeMint(msg.sender, nextTokenId());
    }

    // --- READ-ONLY FUNCTIONS ---

    // getBaseURI returns the baseURI hash for collection metadata.
    function getBaseURI() external view returns (string memory) {
        return baseURI;
    }

    // getLastTokenId returns the last tokenId minted.
    function getLastTokenId() external view returns (uint256) {
        return tokenCounter.current();
    }

    // -- ADMIN FUNCTIONS --

    // setBaseURI sets the base URI for token metadata.
    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    function setVerificationHash(string memory _verificationHash)
        external
        onlyOwner
    {
        verificationHash = _verificationHash;
    }

    // setIsPublicSaleActive toggles the functionality of the public minting function.
    function setIsPublicSaleActive(bool _isPublicSaleActive)
        external
        onlyOwner
    {
        isPublicSaleActive = _isPublicSaleActive;
    }

    // setIsPreSaleActive toggles the functionality of the presale minting function.
    function setIsPreSaleActive(bool _isPreSaleActive)
        external
        onlyOwner
    {
        isPreSaleActive = _isPreSaleActive;
    }

    // setPresaleListMerkleRoot sets the merkle root for presale allowed addresses.
    function setPresaleListMerkleRoot(bytes32 merkleRoot) external onlyOwner {
        preSaleMerkleRoot = merkleRoot;
    }

    // setClaimListMerkleRoot sets the merkle root for free claim addresses.
    function setClaimListMerkleRoot(bytes32 merkleRoot) external onlyOwner {
        claimListMerkleRoot = merkleRoot;
    }

    // withdraw allows for the withdraw of all ETH to the owner wallet.
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    // withdrawTokens allow for the withdrawl of any ERC20 token from contract.
    function withdrawTokens(IERC20 token) public onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        token.transfer(msg.sender, balance);
    }

    // nextTokenId collects the next tokenId to mint.
    function nextTokenId() private returns (uint256) {
        tokenCounter.increment();
        return tokenCounter.current();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }


    /**
     * Override royalty % for future application.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        require(_exists(tokenId), "Nonexistent token");

        return (address(this), SafeMath.div(SafeMath.mul(salePrice, 5), 100));
    }
}