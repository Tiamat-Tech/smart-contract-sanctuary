// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract FashionApe is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using Strings for uint256;
    using ECDSA for bytes32;

    Counters.Counter private _tokenIdCounter;

    address constant team_address = 0xE8043627c48d947aE98f226AafFecc16BA34d76c;

    uint256 public MAXIMUM_SUPPLY = 8765;
    uint256 public MAXIMUM_GIFT = MAXIMUM_SUPPLY;

    uint256 public constant MAXIMUM_MINT_WL = 2;
    uint256 public constant MAXIMUM_MINT_RAFFLE = 4;

    uint256 WL_PRICE = 0.23 ether;
    uint256 RAFFLE_PRICE = 0.23 ether;

    uint256 public giftCount;

    bytes32 public merkleRoot;

    string public baseURI;
    string public notRevealedUri;

    bool public isRevealed = false;

    enum WorkflowStatus {
        Before,
        Presale,
        Sale,
        SoldOut,
        Reveal
    }

    WorkflowStatus public workflow;

    address private _owner;

    mapping(address => uint256) public tokensPerWalletRaffle;
    mapping(address => uint256) public tokensPerWalletWhitelist;

    event ChangePresaleConfig(uint256 _maxCount);
    event ChangeSaleConfig(uint256 _maxCount);
    event ChangeIsBurnEnabled(bool _isBurnEnabled);
    event ChangeBaseURI(string _baseURI);
    event GiftMint(address indexed _recipient, uint256 _amount);
    event PresaleMint(address indexed _minter, uint256 _amount, uint256 _price);
    event SaleMint(address indexed _minter, uint256 _amount, uint256 _price);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);

    constructor(
        string memory _initBaseURI,
        string memory _initNotRevealedUri
    ) ERC721("FASHION APE", "FAPE") {
        transferOwnership(msg.sender);
        workflow = WorkflowStatus.Before;
        setBaseURI(_initBaseURI);
        setNotRevealedURI(_initNotRevealedUri);
        _tokenIdCounter.increment();
    }

    //GETTERS

    function publicSaleLimit() public view returns (uint256) {
        return MAXIMUM_SUPPLY;
    }

    function privateSalePrice() public view returns (uint256) {
        return WL_PRICE;
    }

    function getPrice() public view returns (uint256) {
        return RAFFLE_PRICE;
    }

    function allowedGiftLimit() public view returns (uint256) {
        return MAXIMUM_GIFT;
    }

    function getSaleStatus() public view returns (WorkflowStatus) {
        return workflow;
    }

    function hasWhitelist(bytes32[] calldata _merkleProof) public view returns (bool) {
      bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
      return MerkleProof.verify(_merkleProof, merkleRoot, leaf);
    }

    function presaleMint(uint256 ammount, bytes32[] calldata _merkleProof) external payable nonReentrant
    {
        uint256 supply = totalSupply();
        uint256 price = privateSalePrice();

        require(workflow == WorkflowStatus.Presale, "FASHION APE: Presale is not started yet!");

        require(tokensPerWalletWhitelist[msg.sender] + ammount <= MAXIMUM_MINT_WL, string(abi.encodePacked("FASHION APE: Presale mint is ", MAXIMUM_MINT_WL, " token only.")));

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), "FASHION APE: You are not whitelisted");

        require(msg.value >= price * ammount, "FASHION APE: Not enough ETH sent");

        tokensPerWalletWhitelist[msg.sender] += ammount;
        for (uint256 i = 1; i <= ammount; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }

    function raffleMint(uint256 ammount) public payable nonReentrant {
        uint256 supply = totalSupply();
        uint256 price = getPrice();

        require(workflow != WorkflowStatus.SoldOut, "FASHION APE: SOLD OUT!");
        require(workflow == WorkflowStatus.Sale, "FASHION APE: Raffle is not started yet");
        require(msg.value >= price * ammount, "FASHION APE: Not enough ETH sent");
        require(ammount <= MAXIMUM_MINT_RAFFLE, string(abi.encodePacked("FASHION APE: You can only mint up to ", MAXIMUM_MINT_RAFFLE, " token at once!")));
        require(tokensPerWalletRaffle[msg.sender] + ammount <= MAXIMUM_MINT_RAFFLE, string(abi.encodePacked("FASHION APE: You cant mint more than ", MAXIMUM_MINT_RAFFLE, " tokens!")));
        require(supply + ammount <= MAXIMUM_SUPPLY, "FASHION APE: Mint too large!");

        tokensPerWalletRaffle[msg.sender] += ammount;

        if (supply + ammount == MAXIMUM_SUPPLY) {
            workflow = WorkflowStatus.SoldOut;
        }

        for (uint256 i = 1; i <= ammount; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }

    function gift(uint256 _mintAmount) public onlyOwner {
        uint256 supply = totalSupply();
        require(supply + _mintAmount <= MAXIMUM_SUPPLY, "The presale is not endend yet!");
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        require(giftCount + _mintAmount <= MAXIMUM_GIFT, "max NFT limit exceeded");
        uint256 initial = 1;
        uint256 condition = _mintAmount;
        giftCount += _mintAmount;
        for (uint256 i = initial; i <= condition; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }

    function restart() external onlyOwner {
        workflow = WorkflowStatus.Before;
    }

    function setUpPresale() external onlyOwner {
        workflow = WorkflowStatus.Presale;
    }

    function setUpSale() external onlyOwner {
        require(workflow == WorkflowStatus.Presale, "FASHION APE: Unauthorized Transaction");
        workflow = WorkflowStatus.Sale;
        emit WorkflowStatusChange(WorkflowStatus.Presale, WorkflowStatus.Sale);
    }

    function setMerkleRoot(bytes32 root) public onlyOwner {
        merkleRoot = root;
    }

    function reveal() public onlyOwner {
        isRevealed = true;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function updateWLPrice(uint256 _newPrice) public onlyOwner {
        WL_PRICE = _newPrice;
    }

    function updateRafflePrice(uint256 _newPrice) public onlyOwner {
        RAFFLE_PRICE = _newPrice;
    }

    function updateSupply(uint256 _newSupply) public onlyOwner {
        MAXIMUM_SUPPLY = _newSupply;
        MAXIMUM_GIFT = _newSupply;
    }

    function withdraw() public onlyOwner {
      uint256 balance = address(this).balance;
      payable(team_address).transfer(balance);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        if (isRevealed == false) {
            return notRevealedUri;
        }

        string memory currentBaseURI = baseURI;
        return
            bytes(currentBaseURI).length > 0
                ? string(abi.encodePacked(currentBaseURI, tokenId.toString()))
                : ".json";
    }

}