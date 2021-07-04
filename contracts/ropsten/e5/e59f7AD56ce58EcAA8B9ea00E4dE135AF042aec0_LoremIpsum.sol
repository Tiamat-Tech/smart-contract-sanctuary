// Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract LoremIpsum is ERC721, Ownable {
    
    using SafeMath for uint256;

    uint public constant MAX_TOKENS = 100;

    string public constant NAME = "Lorem Ipsum";

    string public constant SYMBOL = "LIP";
    
    uint public constant MAX_TOKENS_PURCHASE = 5;

    uint256 public constant TOKEN_PRICE = 10000000000000000; //0.01 ETH

	uint saleTime = 1625401145; // 2021-JUL-05 12:00:00

    bool public isSaleActive = false;

    constructor() ERC721(NAME, SYMBOL) {
    }
    
    modifier saleIsOpen {
        require(totalSupply() < MAX_TOKENS, "Lorem Ipsum sale has ended");
        _;
    }
    
    function mint(address _to, uint _count) public payable saleIsOpen {
        require(isSaleActive, "Sale is not active");
        require(totalSupply() + _count <= MAX_TOKENS, "Insufficient tokens left to mint");
        require(totalSupply() < MAX_TOKENS, "All tokens have been minted");
        require(_count <= MAX_TOKENS_PURCHASE, "Exceeds the max tokens you can mint");
        require(msg.value >= price(_count), "Value below price");
        require(block.timestamp >= saleTime, "Sale has not yet commenced");
        
        for(uint x = 0; x < _count; x++){
            _safeMint(_to, totalSupply());
        }
    }

    function price(uint _count) public pure returns (uint256) {
        return TOKEN_PRICE * _count;
    }

     function setBaseURI(string memory _baseURI) public onlyOwner {
        _setBaseURI(_baseURI);
    }
    
    function setTokenURI(uint256 _tokenId, string memory _tokenURI) public onlyOwner {
        _setTokenURI(_tokenId, _tokenURI);
    }

    function saleStartTime() public view returns (uint) {
        return saleTime;
    }

    function setSaleStartTime(uint _time) public onlyOwner {
        saleTime = _time;
    }

    function saleStatus() public view returns (bool) {
        return isSaleActive;
    }

    function setSaleStatus(bool _isActive) public onlyOwner {
        isSaleActive = _isActive;
    }
    
    function walletOfOwner(address _owner) external view returns(uint256[] memory) {
        uint tokenCount = balanceOf(_owner);
        uint256[] memory tokensId = new uint256[](tokenCount);
        for(uint i = 0; i < tokenCount; i++){
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        msg.sender.transfer(balance);
    }
}