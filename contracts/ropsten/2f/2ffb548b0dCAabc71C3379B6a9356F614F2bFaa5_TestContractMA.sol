// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract TestContractMA is ERC721Enumerable, PaymentSplitter, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter public _tokenIdCounter;

    uint256 public constant MAX_TOTAL_SUPPLY = 7777;
    uint256 public constant MAX_MINT_PER_WHITELIST_SALE_WALLET = 4;
    uint256 public constant MAX_MINT_PER_RAFFLE_SALE_WALLET = 4;
    uint256 public MAX_MINT_PER_PUBLIC_SALE_WALLET = 4;
    uint256 public constant PRIVATE_SALE_PRICE = 0.33 ether; 
    uint256 public constant RAFFLE_SALE_PRICE = 0.33 ether; 
    uint256 public PUBLIC_SALE_PRICE = 0.33 ether; 
    uint256 public constant MAX_MINT_PRICE = 1.2 ether;
    uint256 public MAX_MINT_PUBLIC_PRICE = 1.2 ether;

    string public baseURI;
    string public legendaryBaseUri;
    string public soonBaseUri;

    bool public legendaryReveal = false;
    bool public officialReveal = false;

    enum currentStatus {
        Before,
        PrivateSale,
        RaffleSale,
        PublicSale,
        SoldOut, 
        Pause
    }

    currentStatus public status;

    address private _owner;
    address[] private contributors = [0xB18Fa1C28070165D19d7B1c464c9d202592E7dea, 
                                        0x35a1bAcF750f3d969D57A4508453f329D8A4dEA0
                                    ];
    uint256[] private sharesContributors = [7000, 3000];

    mapping(address => uint256) public tokensPerWallet;

    bytes32 public whitelistRootTree;
    bytes32 public rafflelistRootTree;

    event liveMinted(uint256 nbMinted);

    constructor( 
        string memory _initSoonBaseURI,
        bytes32 whitelistMerkleRoot, 
        bytes32 rafflelistMerkleRoot
    ) ERC721("TestContractMA", "MA") PaymentSplitter(contributors, sharesContributors) {
        status = currentStatus.Before;
        setSoonBaseURI(_initSoonBaseURI);
        whitelistRootTree = whitelistMerkleRoot;
        rafflelistRootTree = rafflelistMerkleRoot;
    }

    function getCurrentStatus() public view returns(currentStatus) {
        return status;
    }

    function getActualPrice() public view returns(uint256 actualPrice){
        if (status == currentStatus.PrivateSale){
            actualPrice = PRIVATE_SALE_PRICE;
            return actualPrice;
        }
        if (status == currentStatus.RaffleSale){
            actualPrice = RAFFLE_SALE_PRICE;
            return actualPrice;
        }
        if (status == currentStatus.PublicSale){
            actualPrice = PUBLIC_SALE_PRICE;
            return actualPrice;
        }
    }

    function setInPause() external onlyOwner {
        status = currentStatus.Pause;
    }

    function startPrivateSale() external onlyOwner {
        status = currentStatus.PrivateSale;
    }

    function startRaffleSale() external onlyOwner {
        status = currentStatus.RaffleSale;
    }

    function startPublicSale() external onlyOwner {
        status = currentStatus.PublicSale;
    }

    function setLegendaryReveal() public onlyOwner {
        legendaryReveal = true;
    }

    function setOfficialReveal() public onlyOwner {
        legendaryReveal = false;
        officialReveal = true;
    }

    function setSoonBaseURI(string memory _soonBaseURI) public onlyOwner {
        soonBaseUri = _soonBaseURI;
    }

    function setLegendaryBaseURI(string memory _legendaryBaseURI) public onlyOwner {
        legendaryBaseUri = _legendaryBaseURI;
    }

    function setBaseURI(string memory _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }

    function leafMerkle(address accountListed) internal pure returns(bytes32) {
        return keccak256(abi.encodePacked(accountListed));
    }

    function verifyWhitelistLeafMerkle(bytes32 leafWhitelist, bytes32[] memory proofWhitelistMerkle) internal view returns(bool) {
        return MerkleProof.verify(proofWhitelistMerkle, whitelistRootTree, leafWhitelist);
    }

    function verifyRafflelistLeafMerkle(bytes32 leafRafflelist, bytes32[] memory proofRaffleMerkle) internal view returns(bool) {
        return MerkleProof.verify(proofRaffleMerkle, rafflelistRootTree, leafRafflelist);
    }

    function isWhiteListed(address account, bytes32[] calldata proofWhitelistMerkle) public view returns(bool){
        return verifyWhitelistLeafMerkle(leafMerkle(account), proofWhitelistMerkle);
    }

    function isRaffleListed(address account, bytes32[] calldata proofRaffleMerkle) public view returns(bool){
        return verifyRafflelistLeafMerkle(leafMerkle(account), proofRaffleMerkle);
    }

    function setWhiteList(bytes32 whiteList_) public onlyOwner {
        whitelistRootTree = whiteList_;
    }

    function setRaffleList(bytes32 raffleList_) public onlyOwner {
        rafflelistRootTree = raffleList_;
    }

    function setPublicSaleMaxWallet(uint256 maxMintPublicSaleWallet_) public onlyOwner {
        MAX_MINT_PER_PUBLIC_SALE_WALLET = maxMintPublicSaleWallet_;
    }

    function setPublicSalePrice(uint256 publicSalePrice_) public onlyOwner {
        PUBLIC_SALE_PRICE = publicSalePrice_;
    }

    function setPublicMAXPrice(uint256 publicMaxPrice_) public onlyOwner {
        MAX_MINT_PUBLIC_PRICE = publicMaxPrice_;
    }

    function privateSaleMint(bytes32[] calldata proofWhitelistMerkle, uint32 amount) external payable nonReentrant {
        require(status == currentStatus.PrivateSale, "TestContractMA: Private Sale is not Open !");
        require(msg.value >= PRIVATE_SALE_PRICE * amount || msg.value > MAX_MINT_PRICE, "TestContractMA: Insufficient Funds !"); 
        require(isWhiteListed(msg.sender, proofWhitelistMerkle), "TestContractMA: You're not Eligible for the Private Sale !");
        require(amount <= MAX_MINT_PER_WHITELIST_SALE_WALLET, "TestContractMA: Max 2 Tokens mint at once !");
        require(tokensPerWallet[msg.sender] + amount <= MAX_MINT_PER_WHITELIST_SALE_WALLET, "TestContractMA: Max 2 Tokens Mintable per Wallet !");

        tokensPerWallet[msg.sender] += amount;
        uint256 amountNb = amount;
        for (uint256 i = 1; i <= amountNb; i++) {
            _tokenIdCounter.increment();
            _safeMint(msg.sender, _tokenIdCounter.current()); 
        }
    }

    function raffleSaleMint (bytes32[] calldata proofRaffleMerkle, uint32 amount) external payable nonReentrant {
        uint256 totalSupply = totalSupply();
        require(status != currentStatus.SoldOut, "TestContractMA: We're SOLD OUT !");
        require(status == currentStatus.RaffleSale, "TestContractMA: Raffle Sale is not Open !");
        require(msg.value >= RAFFLE_SALE_PRICE * amount || msg.value > MAX_MINT_PRICE, "TestContractMA: Insufficient Funds !");
        require(isRaffleListed(msg.sender, proofRaffleMerkle), "TestContractMA: You're not Eligible for the Raffle Sale !");
        require(amount <= MAX_MINT_PER_RAFFLE_SALE_WALLET, "TestContractMA: Max 2 Tokens mint at once !");
        require(totalSupply + amount <= MAX_TOTAL_SUPPLY, "TestContractMA: You're mint amount is too large for the remaining tokens !");
        require(tokensPerWallet[msg.sender] + amount <= MAX_MINT_PER_RAFFLE_SALE_WALLET, "TestContractMA: Max 2 Tokens Mintable per Wallet !");

        tokensPerWallet[msg.sender] += amount;
        uint256 amountNb = amount;
        for (uint256 i = 1; i <= amountNb; i++) {
            _tokenIdCounter.increment();
            _safeMint(msg.sender, _tokenIdCounter.current()); 
        }
        if (totalSupply + amount == MAX_TOTAL_SUPPLY){
            status = currentStatus.SoldOut;
        }
    }

    function publicSaleMint (uint32 amount) public payable nonReentrant {
        uint256 totalSupply = totalSupply();
        require(status != currentStatus.SoldOut, "TestContractMA: We're SOLD OUT !");
        require(status == currentStatus.PublicSale, "TestContractMA: Public Sale is not Open !");
        require(msg.value >= PUBLIC_SALE_PRICE * amount || msg.value > MAX_MINT_PER_PUBLIC_SALE_WALLET, "TestContractMA: Insufficient Funds !");
        require(amount <= MAX_MINT_PER_PUBLIC_SALE_WALLET, "TestContractMA: Max 5 Tokens mint at once !");
        require(totalSupply + amount <= MAX_TOTAL_SUPPLY, "TestContractMA: You're mint amount is too large for the remaining tokens !");
        require(tokensPerWallet[msg.sender] + amount <= MAX_MINT_PER_PUBLIC_SALE_WALLET, "TestContractMA: Max 5 Tokens Mintable per Wallet !");

        tokensPerWallet[msg.sender] += amount;
        uint256 amountNb = amount;
        for (uint256 i = 1; i <= amountNb; i++) {
            _tokenIdCounter.increment();
            _safeMint(msg.sender, _tokenIdCounter.current()); 
        }
        if (totalSupply + amount == MAX_TOTAL_SUPPLY){
            status = currentStatus.SoldOut;
        }
    }

    function gift(uint256 amount, address giveawayAddress) public onlyOwner {
        uint256 totalSupply = totalSupply();
        require(amount > 0, "TestContractMA: Need to gift 1 TestContractMA min !");
        require(totalSupply + amount <= MAX_TOTAL_SUPPLY, "TestContractMA: You're mint amount is too large for the remaining tokens !");

        uint256 amountNb = amount;
        for (uint256 i = 1; i <= amountNb; i++) {
            _tokenIdCounter.increment();
            _safeMint(giveawayAddress, _tokenIdCounter.current()); 
        }
        if (totalSupply + amount == MAX_TOTAL_SUPPLY){
            status = currentStatus.SoldOut;
        }
    }

    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        if (officialReveal == false && legendaryReveal == false) {
            return soonBaseUri;
        }

        if (officialReveal == false && legendaryReveal == true) {
            string memory currentLegendaryBaseURI = legendaryBaseUri;
            return bytes(currentLegendaryBaseURI).length > 0 ? string(abi.encodePacked(currentLegendaryBaseURI, tokenId.toString())) : "";
        }

        string memory currentBaseURI = baseURI;
        return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI, tokenId.toString())) : "";
    }
}