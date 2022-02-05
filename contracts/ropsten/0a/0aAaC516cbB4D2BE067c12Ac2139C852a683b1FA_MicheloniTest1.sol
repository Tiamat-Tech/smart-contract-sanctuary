pragma solidity ^0.8.0;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract MicheloniTest1 is ERC721A, Ownable {

    using SafeMath for uint256;

    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant RESERVED = 100;
    uint256 public constant MAX_MINT = 20;

    uint256 public constant MAX_PER_WALLET = 20;

    uint256 public MAX_EARLY_BIRD = 250; // first 250 mint
    uint256 public MAX_SECOND_BATCH_NR = 500; // up to 500 mint
    uint256 public MAX_THIRD_BATCH_NR = 1000; // up to 500 mint

    uint256 public constant PRICE_EARLY_BIRD = 0.003 ether; // first 1000 mint
    uint256 public constant PRICE_SECOND_BATCH = 0.004 ether; // up to 5000 mint
    uint256 public constant PRICE_THIRD_BATCH = 0.005 ether; //
    uint256 public constant PRICE_LAST = 0.008 ether; // more than 5000 up to 10000

    // 0: presale up to 250
    // 1: presale up to 500
    // 2: presale up to 1000
    // 3: public sale
    // 4: CEO game
    uint8 public stageNr = 0;

    string public baseTokenURI;

    mapping(address => uint256) private _allowList;

    constructor(string memory _baseTokenURI, uint256 _MAX_EARLY_BIRD, uint256 _MAX_SECOND_BATCH_NR, uint256 _MAX_THIRD_BATCH_NR) ERC721A("MicheloniTest1", "MT1", MAX_MINT) {
        console.log("MicheloniTest1: creating smart contract with URI [%s]", _baseTokenURI);
        baseTokenURI = _baseTokenURI;
        MAX_EARLY_BIRD = _MAX_EARLY_BIRD;
        MAX_SECOND_BATCH_NR = _MAX_SECOND_BATCH_NR;
        MAX_THIRD_BATCH_NR = _MAX_THIRD_BATCH_NR;
    }

    // ------------------------------------------------------------------------
    // MINT
    // ------------------------------------------------------------------------

    function mint(uint256 quantity) external payable {
        // check allow list
        if (stageNr <= 2) {
            require(numAvailableToMint(msg.sender) >= quantity, "MicheloniTest1: ");
        }

        // check enough eth for buying
        require(totalSupply().add(quantity) < MAX_SUPPLY.sub(RESERVED), "MicheloniTest1: not enough NFTs available");

        // check max token owned
        uint256 ownedTokens = balanceOf(msg.sender);
        require(ownedTokens.add(quantity) <= MAX_PER_WALLET, "MicheloniTest1: max quantity per wallet exceeded");

        // mint nfts
        uint256 startTokenId = totalSupply();
        uint256 currentPrice = _currentPrice(startTokenId);
        require(msg.value >= currentPrice.mul(quantity), "MicheloniTest1: not enough ETH to purchase");

        console.log("MicheloniTest1: minting [%s] NFTs with price [%d]", quantity, currentPrice);

        _safeMint(msg.sender, quantity);

        // update allow list
        if (stageNr <= 2) {
            _allowList[msg.sender] = _allowList[msg.sender] - quantity;
        }
    }

    // return the current price which depends on the quantity of minted NFTs
    function _currentPrice(uint256 currentMintedIndex) private view returns (uint256) {
        if (currentMintedIndex < MAX_EARLY_BIRD) {
            return PRICE_EARLY_BIRD;
        } else if (currentMintedIndex < MAX_SECOND_BATCH_NR) {
            return PRICE_SECOND_BATCH;
        } else if (currentMintedIndex < MAX_THIRD_BATCH_NR) {
            return PRICE_THIRD_BATCH;
        } else {
            return PRICE_LAST;
        }
    }

    // ------------------------------------------------------------------------
    // ALLOW LIST
    // ------------------------------------------------------------------------

    function setAllowList(address[] calldata addresses, uint256[] calldata numAllowedToMint) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            _allowList[addresses[i]] = numAllowedToMint[i];
        }
    }

    function numAvailableToMint(address addr) public view returns (uint256) {
        return _allowList[addr];
    }

    // ------------------------------------------------------------------------
    // RESERVE
    // ------------------------------------------------------------------------

    // reserve a specific quantity of NFTs for the team
    function reserveNFTs() public onlyOwner {
        uint256 startTokenId = totalSupply();
        require(startTokenId.add(RESERVED) < MAX_SUPPLY, "MicheloniTest1: not enough NFTs available");
        for (uint256 i = 0; i < RESERVED; i++) {
            _safeMint(msg.sender, RESERVED);
        }
    }

    // ------------------------------------------------------------------------
    // TOKEN URI
    // ------------------------------------------------------------------------

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    // allow to change the token URI whenever needed
    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    // ------------------------------------------------------------------------
    // WITHDRAW
    // ------------------------------------------------------------------------

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        require(balance > 0, "MicheloniTest1: No ether left to withdraw");
        payable(msg.sender).transfer(balance);
    }

    // ------------------------------------------------------------------------
    // STAGE NUMBER
    // ------------------------------------------------------------------------

    // allow to change the token URI whenever needed
    function setStageNr(uint8 _stageNr) public onlyOwner {
        stageNr = _stageNr;
    }

    function getStageNr() public view returns (uint) {
        return stageNr;
    }

    // ------------------------------------------------------------------------
    // CEO GAME
    // ------------------------------------------------------------------------

    function sendMoneyToWinners(address[] calldata addresses, uint256[] calldata quantity) public onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            payable(addresses[i]).transfer(quantity[i]);
        }
    }

}