// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BeastNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    string public _baseURL;
    uint256 public launchDate;
    struct Beast {
        string name;
        uint256 strength;
        uint256 capacity;
        string imgUrl;
    }
    mapping (uint256 => Beast) tokenData;
    mapping (address => uint256[]) addressTokenIds;
    constructor() ERC721("Crypto Legions Beast", "BEAST") {
        setBaseURL("ipfs://");
    }

    function mint() external payable {
        require(msg.value >= 0.01 ether, "Insufficient payment");
        _safeMint(msg.sender, _tokenIds.current());
        addressTokenIds[msg.sender].push(_tokenIds.current());
        uint256 randNum = genRand(1000);
        Beast memory beast;
        if (randNum==0) {
            beast = Beast("AAA", 6, 20, "XXX");
        } else if (randNum>0&&randNum<10) {
            beast = Beast("AAA", 5, 5, "XXX");
        } else if (randNum>=10&&randNum<80) {
            beast = Beast("AAA", 4, 4, "XXX");
        } else if (randNum>=80&&randNum<220) {
            beast = Beast("AAA", 3, 3, "XXX");
        } else if (randNum>=220&&randNum<500) {
            beast = Beast("AAA", 2, 2, "XXX");
        } else {
            beast = Beast("AAA", 1, 1, "XXX");
        }
        tokenData[_tokenIds.current()] = beast;
        _tokenIds.increment();
    }

    function genRand(uint256 maxNum) private view returns (uint256) {
        require(maxNum>0, "maxNum should be bigger than zero");
        return uint256(uint256(keccak256(abi.encode(block.timestamp, block.difficulty))) % maxNum);
    }

    function getTokenIds(address _address) external view returns (uint256[] memory) {
        return addressTokenIds[_address];
    }

    function getBeastName(uint256 tokenId) external view returns(string memory) {
        return tokenData[tokenId].name;
    }
    function getBeastStrength(uint256 tokenId) external view returns(uint) {
        return tokenData[tokenId].strength;
    }
    function getBeastCapacity(uint256 tokenId) external view returns(uint) {
        return tokenData[tokenId].capacity;
    }
    function getBeastImage(uint256 tokenId) external view returns(string memory) {
        return tokenData[tokenId].imgUrl;
    }
    function setBaseURL(string memory baseURI) public onlyOwner {
        _baseURL = baseURI;
    }

    function totalSupply() public view override returns (uint256) {
        return _tokenIds.current();
    }

    function withdrawBNB(address payable _addr, uint256 amount) public onlyOwner {
        _addr.transfer(amount);
    }

    function withdrawBNBOwner(uint256 amount) public onlyOwner {
        msg.sender.transfer(amount);
    }
}