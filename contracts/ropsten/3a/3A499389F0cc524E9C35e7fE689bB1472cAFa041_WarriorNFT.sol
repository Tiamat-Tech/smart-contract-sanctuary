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


contract WarriorNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    IERC20 public bloodstone;
    string public _baseURL;
    uint256 public launchDate;
    struct Warrior {
        string name;
        uint256 strength;
        uint256 attack_power;
        string imgUrl;
    }
    mapping (uint256 => Warrior) tokenData;
    mapping (address => uint256[]) addressTokenIds;
    constructor() ERC721("Crypto Legions Warrior", "WARRIOR") {
        bloodstone = IERC20(0x498b8f35F7Cd87591591AEEc172c86C1Ed29E7d1);
        setBaseURL("ipfs://");
    }

    function mint() external {
        require(bloodstone.balanceOf(msg.sender) >= 100*10**18, "Insufficient payment");
        bloodstone.transferFrom(msg.sender, address(this), 100*10**18);
        _safeMint(msg.sender, _tokenIds.current());
        addressTokenIds[msg.sender].push(_tokenIds.current());
        uint256 randNum = genRand(10000);
        Warrior memory warrior;
        if (randNum==0&&randNum<5) {
            warrior = Warrior("AAA", 6, 45000+genRand(5001), "XXX");
        } else if (randNum>=5&&randNum<100) {
            warrior = Warrior("AAA", 5, 4000+genRand(1501), "XXX");
        } else if (randNum>=100&&randNum<800) {
            warrior = Warrior("AAA", 4, 3000+genRand(1000), "XXX");
        } else if (randNum>=800&&randNum<2200) {
            warrior = Warrior("AAA", 3, 2000+genRand(1000), "XXX");
        } else if (randNum>=2200&&randNum<5000) {
            warrior = Warrior("AAA", 2, 1000+genRand(1000), "XXX");
        } else {
            warrior = Warrior("AAA", 1, 400+genRand(600), "XXX");
        }
        tokenData[_tokenIds.current()] = warrior;
        _tokenIds.increment();
    }

    function genRand(uint256 maxNum) private view returns (uint256) {
        require(maxNum>0, "maxNum should be bigger than zero");
        return uint256(uint256(keccak256(abi.encode(block.timestamp, block.difficulty))) % maxNum);
    }

    function getTokenIds(address _address) external view returns (uint256[] memory) {
        return addressTokenIds[_address];
    }

    function getWarrior(uint256 tokenId) external view returns(string memory, uint, uint, string memory) {
        return (tokenData[tokenId].name, tokenData[tokenId].strength, tokenData[tokenId].attack_power, tokenData[tokenId].imgUrl);
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