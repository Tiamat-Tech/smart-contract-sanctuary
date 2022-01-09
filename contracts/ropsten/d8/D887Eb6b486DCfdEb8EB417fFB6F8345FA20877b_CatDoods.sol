// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract CatDoods is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 public constant MAX_SUPPLY = 5555;

    uint256 public TOTAL_SUPPLY = 0;

    uint256 public constant MAX_MINT_PER_TX = 5;

    uint256 public constant MAX_MINT_PER_TX_PRESALE = 3;

    uint256 public constant PRICE = 0.05 ether;

    string public baseURI;

    bool public mintable = false;

    bool public preSaleMintable = false;

    uint256 public totalSupplyRemaining = MAX_SUPPLY;

    mapping(address => bool) public allowList;

    event Mintable(bool mintable);

    event PreSaleMintable(bool preSaleMintable);

    event BaseURI(string baseURI);

    event AddToAllowList(address[] accounts);

    event RemoveFromAllowList(address account);

    constructor() ERC721("Cat Doods", "CDOOD") {
        _tokenIds.increment();
    }

    modifier isMintable() {
        require(mintable, "NFT cannot be minted yet.");
        _;
    }

    modifier isPreSaleMintable() {
        require(preSaleMintable, "NFT cannot be minted yet.");
        _;
    }

    modifier isNotExceedMaxMintPerTx(uint256 amount) {
        require(
            amount <= MAX_MINT_PER_TX,
            "Mint amount exceeds max limit per tx."
        );
        _;
    }

    modifier isNotExceedMaxMintPerTxPresale(uint256 amount) {
        require(
            amount <= MAX_MINT_PER_TX_PRESALE,
            "Mint amount exceeds max limit per tx."
        );
        _;
    }

    modifier isNotExceedAvailableSupply(uint256 amount) {
        require(
            TOTAL_SUPPLY + amount <= MAX_SUPPLY,
            "There are no more remaining NFT's to mint."
        );
        _;
    }

    modifier isPaymentSufficient(uint256 amount) {
        require(
            msg.value == amount * PRICE,
            "There was not enough/extra ETH transferred to mint an NFT."
        );
        _;
    }

    modifier isAllowList() {
        require(
            allowList[msg.sender],
            "You're not on the list for the presale."
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
        uint256 id = _tokenIds.current();
        _safeMint(msg.sender, id);
        _tokenIds.increment();
        totalSupplyRemaining--;
        TOTAL_SUPPLY++;
        allowList[msg.sender] = false;
    }

    function mint(uint256 amount)
        public
        payable
        isMintable
        isNotExceedMaxMintPerTx(amount)
        isNotExceedAvailableSupply(amount)
        isPaymentSufficient(amount)
    {
        for (uint256 index = 0; index < amount; index++) {
            uint256 id = _tokenIds.current();
            _safeMint(msg.sender, id);
            _tokenIds.increment();
            TOTAL_SUPPLY++;
        }
    }

    function setBaseURI(string memory _URI) public onlyOwner {
        baseURI = _URI;

        emit BaseURI(baseURI);
    }

    function setMintable(bool _mintable) public onlyOwner {
        mintable = _mintable;

        emit Mintable(mintable);
    }

    function setPreSaleMintable(bool _preSaleMintable) public onlyOwner {
        preSaleMintable = _preSaleMintable;

        emit PreSaleMintable(preSaleMintable);
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