pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WSChamps is ERC721Enumerable, Ownable {
    uint256 private basePrice = 0; //0.08 ETH
    
    uint256 private reserveAtATime = 10;
    uint256 private reservedCount = 0;
    uint256 private maxReserveCount = 1000;
    
    string _baseTokenURI = 'https://gateway.pinata.cloud/ipfs/Qmane2Agh4aD5PGvHDEdRb33iyVKeJmQnSA3gVccoD3DBD/'; //unrevealed
    
    uint256 public constant MAX_TOKENS = 5000;
    bool public active = true;
    uint256 public maximumAllowedTokensPerPurchase = 10;
    mapping(address => uint256) purchased;

    event AssetMinted(uint256 tokenId, address sender);
    event SaleActivation(bool active);

    constructor() ERC721("WS Champs Free 2 Play 2021", "WSF2P") {}

    modifier saleIsOpen {
        require(totalSupply() <= MAX_TOKENS, "Sale has ended.");
        _;
    }

    function setMaximumAllowedTokens(uint256 _count) public onlyOwner {
        maximumAllowedTokensPerPurchase = _count;
    }

    function setActive(bool val) public onlyOwner {
        active = val;
        emit SaleActivation(val);
    }
    
    function setReserveCount(uint256 val) public onlyOwner {
        reserveAtATime = val;
    }
    
    function setPrice(uint256 _price) public onlyOwner {
        basePrice = _price;
    }
    
    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    function getMaximumAllowedTokens() public view onlyOwner returns (uint256) {
        return maximumAllowedTokensPerPurchase;
    }

    function getPrice() external view returns (uint256) {
        return basePrice; // Free
    }

    function getTotalSupply() external view returns (uint256) {
        return totalSupply();
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }
    
    function airdropToHolder(uint256[] memory tokenids, uint256 amount) public payable onlyOwner{
        require((tokenids.length*amount)<address(this).balance, "Not enough ETH in contract.");

        for(uint256 i=0; i<tokenids.length; i++){
            address holder = ownerOf(tokenids[i]);
            (bool success, ) = payable(holder).call{
                value: amount
            }("");
            require(success, "Failed to send Ether");
        }
    }
    
    function reserveBeans() public onlyOwner {
        require(reservedCount <= maxReserveCount, "BEAN: Max Reserves taken already!");
        uint256 supply = totalSupply();
        uint256 i;
        for (i = 0; i < reserveAtATime; i++) {
            emit AssetMinted(supply + i, msg.sender);
            _safeMint(msg.sender, supply + i);
            reservedCount++;
        }  
    }

    function mintMyBean(uint256 _count) public payable saleIsOpen {
        if (msg.sender != owner()) {
            require(active, "Sale is not active currently.");
        }
        require(purchased[msg.sender] + _count <= maximumAllowedTokensPerPurchase, "Only 10 WS Champs mints per wallet allowed");
        require(totalSupply() + _count < MAX_TOKENS, "Total supply exceeded.");
        require(totalSupply() < MAX_TOKENS, "Total supply spent.");
        require(_count <= maximumAllowedTokensPerPurchase, "Exceeds maximum allowed tokens");
        require(msg.value >= basePrice * _count, "Insuffient amount sent.");
        
        purchased[msg.sender] = purchased[msg.sender] + _count;
        for (uint256 i = 0; i < _count; i++) {
            emit AssetMinted(totalSupply(), msg.sender);
            _safeMint(msg.sender, totalSupply());
        }
    }

    function walletOfOwner(address _owner) external view returns(uint256[] memory) {
        uint tokenCount = balanceOf(_owner);
        uint256[] memory tokensId = new uint256[](tokenCount);
        for(uint i = 0; i < tokenCount; i++){
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }
    
    function withdrawAll() public payable onlyOwner {
        (bool success, ) = payable(_msgSender()).call{
            value: address(this).balance
        }("");
        require(success, "Failed to send Ether");
    }
}