// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./Lottery.sol";
import "./ERC721A.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract NFT is Ownable, ERC721A, Lottery {
    using Counters for Counters.Counter;
    string private PROVENANCE;
    using Strings for uint256;
    address public winner;
    address public _owner;
    bool public saleIsActive = true;
    bool public PreSaleIsActive = false;
    bool public isAllowListActive = true;
    bool public LotteryIsActive = true;
    string private _baseURIextended;
    // The internal token ID tracker
    Counters.Counter private _tokenIdCounter;
    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MAX_PUBLIC_MINT = 5;
    uint256  constant PRESALE_PRICE =  0.001 ether;
    uint256  constant WHITELIST_PRICE = 0.01 ether;
    uint256  constant Lottery_PRICE = 0 ether;
    uint256  constant PRICE = 0.1 ether;
   
    mapping(address => uint8) private _allowList;
    mapping(address=>uint8)private LotteryAllow;
    mapping(address => uint256) private _mintWhitelist;
    constructor() ERC721A("WL NFT Token", "WLFT") {
        _owner=msg.sender;
    }
    
     function LotteryWinner(uint lottery) public returns (address payable) {
        winner = lotteryHistory[lottery];
        LotteryAllow[winner]=1;
        return lotteryHistory[lottery];
        
    }
    

    
    function setIsAllowListActive(bool _isAllowListActive) external _onlyOwner {
        isAllowListActive = _isAllowListActive;
    }
    function setAllowList(address[] calldata addresses, uint8 numAllowedToMint) external _onlyOwner {
        require(numAllowedToMint<=3,"Maximum amount of whiteList NFT-s are 3");
        uint256 shorter_time = addresses.length;
        for (uint256 i = 0; i < shorter_time; i++) {
            _allowList[addresses[i]] = numAllowedToMint;
        }
    }
    function numAvailableToMint(address addr) external view returns (uint8) {
        return _allowList[addr];
    }
    function _mintAllowList(uint8 numberOfTokens) private {
         uint256 ts=totalSupply();
         uint256 br=0;
        require(isAllowListActive, "Allow list is not active");
        require(numberOfTokens <= 3, "Exceeded max available to purchase");
        require(ts + numberOfTokens <= MAX_SUPPLY, "Purchase would exceed max tokens");
        require(WHITELIST_PRICE * numberOfTokens == msg.value, "Ether value sent is not correct");
        _allowList[msg.sender] -= numberOfTokens;
        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, ts + i);
             br=i+1;
        }
        _mintWhitelist[msg.sender]=br;
    }
    function mintLottery() external payable {
        uint256 ts=totalSupply();
        require(LotteryAllow[winner]==1);
        require(LotteryIsActive, "Allow list is not active");
        require(ts + 1 <= MAX_SUPPLY, "Purchase would exceed max tokens");
        require(msg.sender == winner, "Sender must be winner of the lottery");
        for (uint256 i = 0; i < 1; i++) {
            _safeMint(msg.sender, ts + i);
        }
           
        LotteryAllow[winner]=0;
    }
    function setBaseURI(string memory baseURI_) external _onlyOwner() {
        _baseURIextended = baseURI_;
    }
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }
    function setProvenance(string memory provenance) public _onlyOwner {
        PROVENANCE = provenance;
    }
    function reserve(uint256 n) public _onlyOwner {
      uint supply = totalSupply();
      uint i;
      for (i = 0; i < n; i++) {
          _safeMint(msg.sender, supply + i);
      }
    }
    function setSaleState(bool newState) public _onlyOwner {
        saleIsActive = newState;
    }
     function setPreSale(bool newPreSale) public _onlyOwner {
        PreSaleIsActive = newPreSale;
    }
    function setLotteryState(bool newLotteryState) public _onlyOwner {
        LotteryIsActive = newLotteryState;
    }


    function mintNft(uint8 numberOfTokens )public payable{
    uint8 br=_allowList[msg.sender];
    uint256 brNft=balanceOf(msg.sender);
     require(brNft+numberOfTokens<=5,"Maximum amount of Nft-s per account is 5");
     if(PreSaleIsActive){
         _presalemint(numberOfTokens);
     }
     else if((br!=0 &&  _mintWhitelist[msg.sender]+numberOfTokens<=3)){
   
    _mintAllowList(numberOfTokens);

    } else{
        _mint(numberOfTokens);
        
    }
     
            
}

    function _mint(uint numberOfTokens) private {
        uint256 ts = totalSupply();
        require(saleIsActive, "Sale must be active to mint tokens");
        require(numberOfTokens <= MAX_PUBLIC_MINT, "Exceeded max token purchase");
        require(ts + numberOfTokens <= MAX_SUPPLY, "Purchase would exceed max tokens");
        require(PRICE * numberOfTokens == msg.value, "Ether value sent is not correct");
        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, ts + i);
        }
    }


    function _presalemint(uint numberOfTokens)private {
        uint256 ts = totalSupply();
        require(PreSaleIsActive, "Pre sale must be active to pre sale mint tokens");
        require(numberOfTokens <= MAX_PUBLIC_MINT, "Exceeded max token purchase");
        require(ts + numberOfTokens <= MAX_SUPPLY, "Purchase would exceed max tokens");
        require(PRESALE_PRICE * numberOfTokens == msg.value, "Ether value sent is not correct");
        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, ts + i);
        }
    }

   
      modifier _onlyOwner() {
      require(msg.sender == _owner);
      _;
    }
    function withdraw() public _onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}