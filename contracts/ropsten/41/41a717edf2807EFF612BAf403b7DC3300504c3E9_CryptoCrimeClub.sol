pragma solidity ^0.8.0;                                                                                                                                                                                                                                
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract CryptoCrimeClub is ERC721, Ownable, ERC721Burnable {
    using Strings for uint256;
    using Counters for Counters.Counter;
    
    uint16 public reserved = 400;
    uint16 public maxSupply = 10000;
    bool public isBurnable = false;
    string public baseURI;
    // presale
    uint256 public presaleMintPrice = 0.12 ether;
    uint16 public presaleMaxPerTransaction = 5;
    uint16 public presaleMaxPerWallet = 5;
    // public sale
    uint256 public publicSaleMintPrice = 0.12 ether;
    uint16 public publicSaleMaxPerTransaction = 5;
    uint16 public publicSaleMaxPerWallet = 50;
    // whitelist
    bytes32 public merkleRoot;

    enum MintState {
        CLOSED,
        PRESALE,
        PUBLIC_SALE,
        SOLD_OUT
    }

    MintState public mintState = MintState.CLOSED;
    
    // Private
    mapping(address => uint16) private _totalMinted;
    Counters.Counter _numOfReservedClaimed;
    Counters.Counter _tokenIdCounter;
    address[] private _payees;
    mapping(address => uint256) _shares;
    
    constructor(address[] memory payees_, uint256[] memory shares_) 
    ERC721("CryptoCrimeClub", "CCC") 
    { 
        updatePayouts(payees_, shares_);
    }

    // Modifiers

    modifier publicSaleIsLive() {
        require(mintState != MintState.SOLD_OUT, "CryptoCrimeClub is sold out");
        require(mintState == MintState.PUBLIC_SALE, "Public sale has not started");
        _;
    }

    modifier presaleIsLive() {
        require(mintState != MintState.SOLD_OUT, "CryptoCrimeClub is sold out");
        require(mintState == MintState.PRESALE, "Presale is closed");
        _;
    }

    function isOwner() public view returns(bool) {
        return owner() == msg.sender;
    }

    // Mint

    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function mint(uint16 _quantity) public payable publicSaleIsLive {
        uint256 supply = totalSupply();
        uint16 walletCount = _totalMinted[msg.sender];
        require(msg.sender != address(0), "Cannot mint to null address");
        require(supply < maxSupply, "Sold Out");
        require(walletCount < publicSaleMaxPerWallet, "Exceeded max allowed per wallet");
        require(walletCount + _quantity <= publicSaleMaxPerWallet, "Minting would exceed max allowed per wallet, please decrease quantity and try again");
        require(_quantity > 0, "Need to mint at least one!");
        require(_quantity <= publicSaleMaxPerTransaction, "More than the max allowed in one transaction");
        require(supply + _quantity <= maxSupply, "Minting would exceed max supply, please select a smaller quantity.");
        require(msg.value == publicSaleMintPrice * _quantity, "Incorrect amount of ETH sent");

        for (uint256 i = 0; i < _quantity; i++) {
            _tokenIdCounter.increment();
            _safeMint(msg.sender, _tokenIdCounter.current());
        }

        _totalMinted[msg.sender] = _quantity + walletCount;
        if (totalSupply() == maxSupply) {
            mintState = MintState.SOLD_OUT;
        }
    }

    // MARK: Presale

    function mintPreSale(uint16 _quantity, bytes32[] memory proof) public payable presaleIsLive {
        uint16 count = _totalMinted[msg.sender];
        require(isInWhitelist(proof, msg.sender), "You are not eligible for Presale");
        require(count < presaleMaxPerWallet, "Exceeded max mint allowed per wallet for Presale");
        require(count + _quantity <= presaleMaxPerWallet, "Minting would exceed max allowed for presale. Please decreae quantity.");
        require(totalSupply() < maxSupply, "Collection Sold Out");
        require(_quantity > 0, "Need to mint at least one!");
        require(_quantity <= presaleMaxPerTransaction, "Exceeded max allowed for one transaction");
        require(totalSupply() + _quantity <= maxSupply, "Minting would exceed max supply, please decrease quantity");
        require(_quantity*presaleMintPrice == msg.value, "Incorrect amount of ETH sent");
        
        for (uint256 i = 0; i < _quantity; i++) {
            _tokenIdCounter.increment();
            _safeMint(msg.sender, _tokenIdCounter.current());
        }

        _totalMinted[msg.sender] = _quantity + count;
        if (totalSupply() == maxSupply) {
            mintState = MintState.SOLD_OUT;
        }
    }

    function isInWhitelist(bytes32[] memory proof, address _account) public view returns (bool) {
        return MerkleProof.verify(proof, merkleRoot, keccak256(abi.encodePacked(_account)));
    }
   
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory)
    {
        require(_exists(tokenId), "URI query for nonexistent token");

        string memory currentBaseURI = baseURI;
        return bytes(currentBaseURI).length > 0
            ? string(abi.encodePacked(currentBaseURI, "/", tokenId.toString(), ".json"))
            : "";
    }

    function burn(uint256 tokenId) public virtual override {
        require(isBurnable, "Burning is disabled");
        super.burn(tokenId);
    }

    // MARK: onlyOwner

    function setMerkleRoot(bytes32 _root) public onlyOwner {
        merkleRoot = _root;
    }

    function setBaseURI(string memory _uri) public onlyOwner {
        baseURI = _uri;
    }

    function setPublicMintPrice(uint256 _price) public onlyOwner {
        publicSaleMintPrice = _price;
    }

    function setPresaleMintPrice(uint256 _price) public onlyOwner {
        presaleMintPrice = _price;
    }

    function setMintState(uint8 _state) public onlyOwner {
        mintState = MintState(_state);
    }

    function setReservedQuantity(uint16 _quantity) public onlyOwner {
        reserved = _quantity;
    }

    function toggleBurnable() public onlyOwner {
        isBurnable = !isBurnable;
    }

    function setSaleRestrictions(
        uint16 _presaleMaxPerTransaction,
        uint16 _presaleMaxPerWallet, 
        uint16 _publicSaleMaxPerTransaction, 
        uint16 _publicSaleMaxPerWallet,
        uint16 _maxSupply) 
        public onlyOwner {
        presaleMaxPerTransaction = _presaleMaxPerTransaction;
        presaleMaxPerWallet = _presaleMaxPerWallet;
        publicSaleMaxPerTransaction = _publicSaleMaxPerTransaction;
        publicSaleMaxPerWallet = _publicSaleMaxPerWallet;
        maxSupply = _maxSupply;
    } 

    function claimReserved(address addr, uint256 _quantity) public onlyOwner {
        uint256 supply = totalSupply();
        require(supply < maxSupply, "Collection has sold out");
        require(_quantity + supply <= maxSupply, "Minting would exceed the max supply, please decrease quantity");
        require(_numOfReservedClaimed.current() < reserved, "Already minted all of the reserved NFTs");
        require(_quantity + _numOfReservedClaimed.current() <= reserved, "Minting would exceed the limit of reserved NFTs. Please decrease quantity.");

        for(uint256 i = 0; i < _quantity; i++) {
            _tokenIdCounter.increment();
            _mint(addr, _tokenIdCounter.current());
            _numOfReservedClaimed.increment();
        }

         if (totalSupply() == maxSupply) {
            mintState = MintState.SOLD_OUT;
        }
    }

    function contractBalance() public view onlyOwner returns(uint256) {
        return address(this).balance;
    }

    function withdrawAll() public onlyOwner {
        uint256 balance = contractBalance();
        require(balance > 0, "Balance must be more than 0");

        for(uint256 i = 0; i < _payees.length; i++) {
            address payee = _payees[i];
            uint256 numOfShares = _shares[payee];

            if (numOfShares > 0) {
                _withdraw(payee, (balance * numOfShares)/1000);
            }
        }

        require(contractBalance() == 0, "Did not withdraw all funds");
    }

    function shares(address account) public view onlyOwner returns(uint256) {
        return _shares[account];
    }

    function payees() public view onlyOwner returns(address[] memory) {
        return _payees;
    }

    function updatePayouts(
        address[] memory payees_, 
        uint256[] memory shares_) 
        public 
        onlyOwner {
        _payees = new address[](0);

        for(uint256 i = 0; i < payees_.length; i++) {
            _addPayee(payees_[i], shares_[i]);
        }
    }

    function _withdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call { value: _amount}("");
        require(success, "failed with withdraw");
    }

    function _addPayee(address account, uint256 shares_) private {
        require(account != address(0), "Account is the zero address");
        require(shares_ > 0, "Shares are 0");

        _payees.push(account);
        _shares[account] = shares_;
    }
}