// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "contracts/ERC721A.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/// @title The Dicks
contract TheDicks is Ownable, ReentrancyGuard, ERC721A("The Dicks", "DICKS") {
    using Strings for uint256;
    using Counters for Counters.Counter;
    using MerkleProof for bytes32[];

    Counters.Counter private tokenCounter;

    bool private isOpenSeaProxyActive = true;

    /// @notice Max total supply.
    uint256 public constant dicksMax = 6969;
    /// @notice Max transaction amount.
    uint256 public constant dicksPerTx = 5;
    /// @notice Max Dicks per wallet in pre-sale
    uint256 public constant dicksMintPerWalletPresale = 2;
    /// @notice Total Dicks available in pre-sale
    uint256 public constant maxPreSaleDicks = 222;
    /// @notice Dicks price.
    uint256 public constant dicksPrice = 0.069 ether;

    /// @notice 0 = FREE, 1 = EARLY, 2 = PUBLIC
    uint256 public saleState;
    /// @notice Metadata baseURI.
    string public baseURI;
    /// @notice Metadata unrevealed uri.
    string public unrevealedURI;
    /// @notice Metadata baseURI extension.
    string public baseExtension;

    /// @notice OpenSea proxy registry.
    address public opensea = 0xa5409ec958C83C3f309868babACA7c86DCB077c1;
    /// @notice LooksRare marketplace transfer manager.
    address public looksrare = 0x3f65A762F15D01809cDC6B43d8849fF24949c86a;
    /// @notice Check if marketplaces pre-approve is enabled.
    bool public marketplacesApproved = true;

    /// @notice Free mint merkle root.
    bytes32 public freeMintRoot;
    /// @notice Pre access merkle root.
    bytes32 public preMintRoot;
    /// @notice Amount minted by address on free mint.
    mapping(address => uint256) public freeMintCounts;
    /// @notice Amount minted by address on pre access.
    mapping(address => uint256) public preMintCount;
    /// @notice Authorized callers mapping.
    mapping(address => bool) public auth;

    // ============ ACCESS CONTROL/SANITY MODIFIERS ============

    modifier canMintDicks(uint256 numberOfTokens) {
        require(
            tokenCounter.current() + numberOfTokens <= dicksMax,
            "Not enough Dicks remaining to mint"
        );
        _;
    }

    modifier freeSaleActive() {
        require(saleState == 0, "Free sale is not open");
        _;
    }

    modifier preSaleActive() {
        require(saleState == 1, "Pre sale is not open");
        _;
    }

    modifier PublicSaleActive() {
        require(saleState == 2, "Public sale is not open");
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

    modifier isCorrectPayment(uint256 price, uint256 numberOfTokens) {
        require(
            price * numberOfTokens == msg.value,
            "Incorrect ETH value sent"
        );
        _;
    }

    modifier maxDicksPerTransaction(uint256 numberOfTokens) {
        require(
            numberOfTokens == dicksPerTx,
            "Max Dicks to mint per transaction is 5"
        );
        _;
    }

    constructor(string memory newUnrevealedURI) {
        unrevealedURI = newUnrevealedURI;
    }

    // CURRENTLY ONLY LET ONE FREE MINT PER ADDRESS
    /// @notice Mint one free token.
    function mintFree(uint256 numberOfTokens, bytes32[] calldata merkleProof)
        external
        nonReentrant
        freeSaleActive
        canMintDicks(numberOfTokens)
        isValidMerkleProof(merkleProof, freeMintRoot)
    {
        if (msg.sender != owner()) {
            require(
                freeMintCounts[msg.sender] == 0,
                "User already minted a free token"
            );
            require(numberOfTokens == 1);
        }

        freeMintCounts[msg.sender]++;
        _safeMint(msg.sender, 1);
    }

    /// @notice Mint one or more tokens for user on pre-sale list.
    function mintPreDick(uint256 numberOfTokens, bytes32[] calldata merkleProof)
        external
        payable
        nonReentrant
        preSaleActive
        canMintDicks(numberOfTokens)
        isCorrectPayment(dicksPrice, numberOfTokens)
        isValidMerkleProof(merkleProof, preMintRoot)
    {
        uint256 numAlreadyMinted = preMintCount[msg.sender];

        require(
            numAlreadyMinted + numberOfTokens <= dicksMintPerWalletPresale,
            "Max Dicks to mint in pre-sale is three"
        );

        require(
            tokenCounter.current() + numberOfTokens <= maxPreSaleDicks,
            "Not enough Dicks remaining in pre-sale"
        );

        preMintCount[msg.sender] = numAlreadyMinted + numberOfTokens;

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, nextTokenId());
        }

        preMintCount[msg.sender] += numberOfTokens;
        _safeMint(msg.sender, numberOfTokens);
    }

    /// @notice Mint one or more tokens.
    function mintDick(uint256 numberOfTokens)
        external
        payable
        nonReentrant
        isCorrectPayment(dicksPrice, numberOfTokens)
        PublicSaleActive
        canMintDicks(numberOfTokens)
        maxDicksPerTransaction(numberOfTokens)
    {
        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, nextTokenId());
        }
    }

    /// @notice See {IERC721-tokenURI}.
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        if (bytes(unrevealedURI).length > 0) return unrevealedURI;
        return
            string(
                abi.encodePacked(baseURI, tokenId.toString(), baseExtension)
            );
    }

    /// @notice Set baseURI to `newBaseURI`, baseExtension to `newBaseExtension` and deletes unrevealedURI, triggering a reveal.
    function setBaseURI(
        string memory newBaseURI,
        string memory newBaseExtension
    ) external onlyOwner {
        baseURI = newBaseURI;
        baseExtension = newBaseExtension;
        delete unrevealedURI;
    }

    /// @notice Set unrevealedURI to `newUnrevealedURI`.
    function setUnrevealedURI(string memory newUnrevealedURI)
        external
        onlyOwner
    {
        unrevealedURI = newUnrevealedURI;
    }

    /// @notice Set Sale State. 0 = free mint 2 = pre-sale 3 = public.
    function setSaleState(uint256 newSaleState) external onlyOwner {
        saleState = newSaleState;
    }

    /// @notice Set freeMintRoot to `newMerkleRoot`.
    function setFreeMintRoot(bytes32 newMerkleRoot) external onlyOwner {
        freeMintRoot = newMerkleRoot;
    }

    /// @notice Set preMintRoot to `newMerkleRoot`.
    function setPreMintRoot(bytes32 newMerkleRoot) external onlyOwner {
        preMintRoot = newMerkleRoot;
    }

    // function to disable gasless listings for security in case
    // opensea ever shuts down or is compromised
    function setIsOpenSeaProxyActive(bool _isOpenSeaProxyActive)
        external
        onlyOwner
    {
        isOpenSeaProxyActive = _isOpenSeaProxyActive;
    }

    /// @notice Set opensea to `newOpensea`.
    function setOpensea(address newOpensea) external onlyOwner {
        opensea = newOpensea;
    }

    /// @notice Set looksrare to `newLooksrare`.
    function setLooksrare(address newLooksrare) external onlyOwner {
        looksrare = newLooksrare;
    }

    /// @notice Toggle marketplaces pre-approve feature.
    function toggleMarketplacesApproved() external onlyOwner {
        marketplacesApproved = !marketplacesApproved;
    }

    /// @notice Withdraw balance to Owner
    function withdrawMoney() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    /// @notice See {ERC721-isApprovedForAll}.
    function isApprovedForAll(address owner, address operator)
        public
        view
        override
        returns (bool)
    {
        if (!marketplacesApproved)
            return auth[operator] || super.isApprovedForAll(owner, operator);
        return
            auth[operator] ||
            operator == address(ProxyRegistry(opensea).proxies(owner)) ||
            operator == looksrare ||
            super.isApprovedForAll(owner, operator);
    }

    // ============ SUPPORTING FUNCTIONS ============

    function nextTokenId() private returns (uint256) {
        tokenCounter.increment();
        return tokenCounter.current();
    }

    // ============ PUBLIC READ-ONLY FUNCTIONS ============
    function getLastTokenId() external view returns (uint256) {
        return tokenCounter.current();
    }
}

contract OwnableDelegateProxy {}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}