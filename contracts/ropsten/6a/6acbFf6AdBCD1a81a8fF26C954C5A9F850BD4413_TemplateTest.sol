// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/[email protected]/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/[email protected]/access/Ownable.sol";
import "@openzeppelin/[email protected]/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.3.1/contracts/utils/math/SafeMath.sol";

contract TemplateTest is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    Counters.Counter private _tokenIdCounter;

    address tm1 = 0xeb15a39D9084584eE8E84ED61e3E3b517f9aa051;
    address tm2 = 0xAba40C3C156eE8e6A9d757c55839c1A5372D594d;
    //@todo add tm3 for founder

    string baseTokenURI;

    uint private constant maxThings = 10; //@todo live will be 10k
    uint private mintPrice = 20000000 gwei;
    bool private salePaused = true;

    constructor() ERC721("TemplateTest", "TT") {}

    function saleToggle() public onlyOwner {
        salePaused = !salePaused;
    }

    function publicMint(uint num) public payable {
        uint supply = totalSupply();
        require( !salePaused,                           "Sale paused" );
        require( num < 3,                               "You can adopt a maximum of 2 Things per txn" ); //@todo update for mainnet
        require( supply + num <= maxThings,             "Exceeds maximum Things supply" );
        require( msg.value >= mintPrice * num,          "Ether sent is not correct" );

        for(uint i; i < num; i++){
            _safeMint( msg.sender, supply + i );
        }
    }

    function reservedMint(uint num) public payable {
        uint supply = totalSupply();
        require( msg.sender == owner()
          || msg.sender == tm1
          || msg.sender == tm2
          // || msg.sender == tm3
        );
        require( supply + num <= maxThings, "Exceeds maximum Things supply");

        for(uint i; i < num; i++){
            _safeMint( msg.sender, supply + i );
        }
    }

    function walletOfTokenOwner(address _owner) public view returns(uint[] memory) {
        uint tokenCount = balanceOf(_owner);

        uint[] memory tokensId = new uint[](tokenCount);
        for(uint i; i < tokenCount; i++){
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    function setPrice(uint _newPrice) public onlyOwner() {
        mintPrice = _newPrice;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    function getPrice() public view returns (uint){
        return mintPrice;
    }

    function getMaxThings() public view returns (uint){
        return maxThings;
    }

    //Payout
    function withdraw() public payable onlyOwner {
        uint tenthCut = address(this).balance / 10;                //@todo finalize cuts, deployer will not be ultimate owner
        uint quarterCut = address(this).balance / 4;
        payable(tm1).transfer(tenthCut);
        payable(tm2).transfer(quarterCut);
        payable(msg.sender).transfer(address(this).balance);      //remainder
    }

    //Recover any ERC20 tokens sent to contract
    function withdrawTokens(IERC20 token) public onlyOwner {
        require(address(token) != address(0));
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }
}