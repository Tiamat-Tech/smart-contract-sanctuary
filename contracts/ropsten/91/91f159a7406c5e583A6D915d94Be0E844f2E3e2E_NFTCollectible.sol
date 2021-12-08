pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract NFTCollectible is ERC721Enumerable, Ownable{
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;
    uint public constant Max_Supply = 100;
    uint public constant PRICE = 0.01 ether;
    uint public constant MAX_PER_MINT=5;

    string public baseTokenURI;
    
    //nft json data
    //ipfs://QmZbWNKJPAjxXuNFSEaksCJVd1M6DaKQViJBYPK2BdpDEP/

    //each nft's data will be att <base>/1...

    function _baseURI() internal
                        view
                        virtual
                        override
                        returns (string memory){
                            return baseTokenURI;
                        }

    function setBaseURI(string memory _baseTokenURI) public onlyOwner{
        baseTokenURI = _baseTokenURI;
    }

    constructor(string memory baseURI) ERC721("NFT Collectible","NFTC"){
        setBaseURI(baseURI);
    }


    function reserveNFTs() public onlyOwner{
        uint totalMinted = _tokenIds.current();
        require(totalMinted.add(10)< Max_Supply,"Not enough left in supply");

        for(uint i=0; i< 10;i++){
            _mintSingleNFT();

        }
    }


    function _mintSingleNFT() private{
        uint newTokenID = _tokenIds.current();
        _safeMint(msg.sender,newTokenID);
        _tokenIds.increment();

    }


    function mintNFTs(uint _count) public payable{
        uint totalMinted = _tokenIds.current();
        require(totalMinted.add(_count) <= Max_Supply,"Not enough NFTs");
        require(_count > 0 && _count <= MAX_PER_MINT,"Can't mint specific number of NFTs");
        require(msg.value >= PRICE.mul(_count),"Not enough ether to purchase NFT.");

        for(uint i=0; i < _count; i++){
            _mintSingleNFT();
        }
    }


    function tokensOfOwner(address _owner) external view returns(uint[] memory){
        uint tokenCount = balanceOf(_owner);
        uint[] memory tokenId = new uint256[](tokenCount);
        for(uint i=0; i < tokenCount; i++){
            tokenId[i] = tokenOfOwnerByIndex(_owner,i);
        }

        return tokenId;
    }


    function withdraw() public payable onlyOwner{
        uint balance = address(this).balance;
        require(balance > 0,"No ether to withdraw");
        (bool success,) = (msg.sender).call{value: balance}("");
        require(success,"Transfer failed");
    }

}