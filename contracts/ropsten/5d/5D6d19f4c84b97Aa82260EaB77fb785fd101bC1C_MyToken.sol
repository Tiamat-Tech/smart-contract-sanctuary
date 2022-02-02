// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC721A.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MyToken is Ownable, ERC721A, ReentrancyGuard {
    using Address for address payable; 

    uint256 public maxSupply;
    uint256 public saleStartTime;
    uint256 public saleEndTime;
    uint256 public basePrice;
    bool public mintState;
    string public baseURI_;

    constructor(
      uint256 maxBatchSize_,
      uint256 collectionSize_) ERC721A("MyToken", "MTK", maxBatchSize_, collectionSize_){
      baseURI_ = " https://ikzttp.mypinata.cloud/ipfs/QmQFkLSQysj94s5GvTHPyzTxrawwtjgiiYS2TBLgrvw8CW/";
      maxSupply = 1980;
      mintState = true;
      basePrice = 0.04 ether;
      saleStartTime = block.timestamp;
      saleEndTime = saleStartTime + 7 days;
    }

    receive() external payable {}

    function _baseURI() internal view override returns (string memory) {
        return baseURI_;
    }

    function setBaseUri(string memory newURI) public onlyOwner {
        baseURI_ = newURI;
    }

    function setMaxBatchSize(uint256 quantity) public onlyOwner {
        maxBatchSizeUpdate(quantity);
    }

    function setCollectionSize(uint256 quantity) public onlyOwner {
        collectionSizeUpdate(quantity);
    }

    function setBasePrice(uint256 amount) public onlyOwner {
        basePrice = amount;
    }

    function setSaleTime(uint256 _startTime) public onlyOwner {
        saleStartTime = _startTime;
        saleEndTime = saleStartTime + 7 days;
    }

    function setMaxSupply(uint256 _maxSupply) public onlyOwner {
        maxSupply = _maxSupply;
    }

    function setMintState(bool status) public onlyOwner {
        mintState = status;
    }

    function recoverOtherFund(address token,address to) public onlyOwner {
        if(token == address(0)){
            payable(to).sendValue(address(this).balance);
        }else {
            IERC20(token).transfer(to,IERC20(token).balanceOf(address(this)));
        }
    }

    function adminMint(address to,uint256 supply) public onlyOwner {
        require(saleStartTime < block.timestamp && saleEndTime > block.timestamp, "Sale Ended");
        require(mintState, "Mint option is paused");
        require ((totalSupply() + (supply)) <= maxSupply, "Supply Exceed");
        
        _safeMint(to, supply); 
    }

    function setOwnersExplicit(uint256 quantity) external onlyOwner nonReentrant {
        _setOwnersExplicit(quantity);
    }

    function safeMint(address to,uint256 supply) external payable {
        require(saleStartTime < block.timestamp && saleEndTime > block.timestamp, "Sale Ended");
        require(mintState, "Mint option is paused");
        require ((totalSupply() + (supply)) <= maxSupply, "Supply Exceed");
        require(msg.value >= (basePrice * supply), "Amount is invalid");

        payable(owner()).sendValue(msg.value);
        _safeMint(to, supply);   
    }

    function numberMinted(address owner) public view returns (uint256) {
       return _numberMinted(owner);
    }

    function getOwnershipData(uint256 tokenId)
      external
      view
      returns (TokenOwnership memory)
    {
      return ownershipOf(tokenId);
    }

}