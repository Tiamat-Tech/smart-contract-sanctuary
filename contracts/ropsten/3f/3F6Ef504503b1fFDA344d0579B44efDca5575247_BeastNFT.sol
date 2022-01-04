// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


contract BeastNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    IERC20 public bloodstone;
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
        bloodstone = IERC20(0x498b8f35F7Cd87591591AEEc172c86C1Ed29E7d1);
        setBaseURL("ipfs://");
    }

    function mint() external {
        require(bloodstone.balanceOf(msg.sender) >= 100*10**18, "Insufficient payment");
        bloodstone.approve(address(this),100*10**18);
        bloodstone.transferFrom(msg.sender, address(this), 100*10**18);
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

    function getBeast(uint256 tokenId) external view returns(string memory, uint, uint, string memory) {
        return (tokenData[tokenId].name, tokenData[tokenId].strength, tokenData[tokenId].capacity, tokenData[tokenId].imgUrl);
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