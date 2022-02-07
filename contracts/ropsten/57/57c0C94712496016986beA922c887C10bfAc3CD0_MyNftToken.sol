// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC721Checkpointable } from "./ERC721Checkpointable.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Lottery } from "./Lottery.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MyNftToken is Ownable, ERC721Checkpointable, Lottery {
    using Counters for Counters.Counter;
    string public PROVENANCE;

    address public winner;
    bool public saleIsActive = true;
    bool public presSaleIsActive = true;
    bool public isWhiteListActive = true;
    bool public LotteryIsActive = true;
    string private _baseURIextended;

    // The internal token ID tracker
    Counters.Counter private _tokenIdCounter;

    
    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MAX_PUBLIC_MINT = 5;
    uint256 public constant PRESALE_PRICE =  0.001 ether;
    uint256 public constant WHITELIST_PRICE = 0.01 ether;
    uint256 public constant PRICE = 0.1 ether;

    mapping(address => uint8) private _allowList;
    mapping(address => uint8) private LotteryAllow;

    constructor() ERC721("My NFT Token", "MNFT") {

    }

    function LotteryWinner(uint lottery) public returns (address payable) {
        winner = lotteryHistory[lottery];
        LotteryAllow[winner]=1;
        return lotteryHistory[lottery];
        
    }
    
    function setIsWhiteListActive(bool _IsWhiteListActive) external onlyOwner {
        isWhiteListActive = _IsWhiteListActive;
    }

    function setWhiteList(address[] calldata addresses, uint8 numAllowedToMint) external onlyOwner {
        uint256 shorter_time = addresses.length;
        for (uint256 i = 0; i < shorter_time; i++) {
            _allowList[addresses[i]] = numAllowedToMint;
        }
    }

    function numAvailableToMint(address addr) external view returns (uint8) {
        return _allowList[addr];
    }

    
    
    function setBaseURI(string memory baseURI_) external onlyOwner() {
        _baseURIextended = baseURI_;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }


    function mint(uint numberOfTokens) public payable {
        uint256 ts = totalSupply();
        require(saleIsActive, "Sale must be active to mint tokens");
        require(numberOfTokens <= MAX_PUBLIC_MINT, "Exceeded max token purchase");
        require(ts + numberOfTokens <= MAX_SUPPLY, "Purchase would exceed max tokens");
        require(PRICE * numberOfTokens <= msg.value, "Ether value sent is not correct");

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, ts + i);
        }
    }

    function presalemint(uint numberOfTokens) public payable {
        uint256 ts = totalSupply();
        require(presSaleIsActive, "PreSale must be active to mint tokens");
        require(numberOfTokens <= MAX_PUBLIC_MINT, "Exceeded max token purchase");
        require(ts + numberOfTokens <= MAX_SUPPLY, "Purchase would exceed max tokens");
        require(PRESALE_PRICE * numberOfTokens <= msg.value, "Ether value sent is not correct");

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, ts + i);
        }
    }
    
    function mintWhiteList(uint8 numberOfTokens) external payable {
        uint256 ts = totalSupply();
        require(isWhiteListActive, "Allow list is not active");
        require(numberOfTokens <= _allowList[msg.sender], "Exceeded max available to purchase");
        require(ts + numberOfTokens <= MAX_SUPPLY, "Purchase would exceed max tokens");
        require(WHITELIST_PRICE * numberOfTokens <= msg.value, "Ether value sent is not correct");

        _allowList[msg.sender] -= numberOfTokens;
        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, ts + i);
        }
    }
    
    function mintLottery() external payable {
        uint256 ts = totalSupply();
        require(LotteryAllow[winner]==1);
        require(LotteryIsActive, "Allow list is not active");
        require(ts + 1 <= MAX_SUPPLY, "Purchase would exceed max tokens");
        require(msg.sender == winner, "Sender must be winner of the lottery");
        
            _safeMint(msg.sender, ts + 1);
        LotteryAllow[winner]=0;
    }

    function setProvenance(string memory provenance) public onlyOwner {
        PROVENANCE = provenance;
    }

    function reserve(uint256 n) public onlyOwner {
      uint supply = totalSupply();
      uint i;
      for (i = 0; i < n; i++) {
          _safeMint(msg.sender, supply + i);
      }
    }

    function setSaleState(bool newState) public onlyOwner {
        saleIsActive = newState;
    }

    function setPreSaleState(bool newPreSale) public onlyOwner {
        presSaleIsActive = newPreSale;
    }

    
    function setLotteryState(bool newLotteryState) public onlyOwner {
        LotteryIsActive = newLotteryState;
    }
    

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}