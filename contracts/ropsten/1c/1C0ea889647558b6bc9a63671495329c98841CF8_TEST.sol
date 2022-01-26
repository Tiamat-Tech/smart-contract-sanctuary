// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract TEST is Ownable, ERC721A, ReentrancyGuard {

    uint256 public immutable maxPerAddressDuringMint;

    uint256 public immutable amountForDevs;

    uint256 public immutable amountForPublicAndDev;

    uint256 public constant MAX_SUPPLY = 7777;

    uint256 public constant MAX_MINT_PER_TX = 3;

    uint256 public constant MAX_MINT_PER_TX_PRESALE = 1;

    uint256 public constant PRICE = 0.05 ether;

    string public baseURI;

    bool public publicSaleActive = false;

    bool public preSaleActive = false;

    mapping(address => bool) public allowList;

    event Mintable(bool publicSaleActive);

    event PreSaleMintable(bool preSaleActive);

    event BaseURI(string baseURI);

    event AddToAllowList(address[] accounts);

    event RemoveFromAllowList(address account);

    constructor(
        uint256 maxBatchSize_,
        uint256 collectionSize_,
        uint256 amountPublicAndDev_,
        uint256 amountDevs_
    ) ERC721A("TEST", "TEST", maxBatchSize_) {
        maxPerAddressDuringMint = maxBatchSize_;
        amountForPublicAndDev = amountPublicAndDev_;
        amountForDevs = amountDevs_;
        require(
            amountPublicAndDev_ <= collectionSize_,
            "larger collection size needed"
        );
    }

    modifier isMintable() {
        require(publicSaleActive, "TEST: Public sale not active sir.");
        _;
    }

    modifier isPreSaleMintable() {
        require(preSaleActive, "TEST: Presale not active sir.");
        _;
    }

    modifier isNotExceedMaxMintPerTx(uint256 amount) {
        require(
            amount <= MAX_MINT_PER_TX,
            "TEST: Mint amount exceeds max limit per tx."
        );
        _;
    }

    modifier isNotExceedMaxMintPerTxPresale(uint256 amount) {
        require(
            amount <= MAX_MINT_PER_TX_PRESALE,
            "TEST: Mint amount exceeds max limit per tx."
        );
        _;
    }

      modifier callerIsUser() {
        require(tx.origin == msg.sender, "TEST: Caller is a contract.");
        _;
  }

    modifier isNotExceedAvailableSupply(uint256 amount) {
        require(
            totalSupply() + amount <= MAX_SUPPLY,
            "TEST: Sorry, supply exhausted."
        );
        _;
    }

    modifier isPaymentSufficient(uint256 amount) {
        require(
            msg.value == amount * PRICE,
            "TEST: Ether value does not meet requirement."
        );
        _;
    }

    modifier isAllowList() {
        require(
            allowList[msg.sender],
            "TEST: You're not on the list for the presale."
        );
        _;
    }

    function preSaleMint(uint256 amount)
        public
        payable
        isPreSaleMintable
        isNotExceedMaxMintPerTxPresale(amount)
        isAllowList
        isNotExceedAvailableSupply(amount)
        isPaymentSufficient(amount)
    {
        _safeMint(msg.sender, amount);
        allowList[msg.sender] = false;
    }

    function mint(uint256 amount)
        public
        payable
        callerIsUser
        isMintable
        isNotExceedMaxMintPerTx(amount)
        isNotExceedAvailableSupply(amount)
        isPaymentSufficient(amount)
    {
        _safeMint(msg.sender, amount);
    }

    function setBaseURI(string memory _URI) public onlyOwner {
        baseURI = _URI;
        emit BaseURI(baseURI);
    }

    function setPublicSaleStatus(bool status) public onlyOwner {
        publicSaleActive = status;
        emit Mintable(publicSaleActive);
    }

    function setPreSaleStatus(bool status) public onlyOwner {
        preSaleActive = status;
        emit PreSaleMintable(preSaleActive);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function setAddressesToAllowList(address[] memory _addresses)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < _addresses.length; i++) {
            allowList[_addresses[i]] = true;
        }

        emit AddToAllowList(_addresses);
    }

    function removeAddressFromAllowList(address _address) public onlyOwner {
        allowList[_address] = false;
        emit RemoveFromAllowList(_address);
    }
}