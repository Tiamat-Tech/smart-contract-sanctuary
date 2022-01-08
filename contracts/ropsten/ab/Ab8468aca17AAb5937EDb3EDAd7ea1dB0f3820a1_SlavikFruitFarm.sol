pragma solidity >=0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract SlavikFruitFarm is ERC721, Ownable {
    using SafeMath for uint256;

    uint256 public maxTokens = 10000;

    uint256 public price = 22200000000000000; // 0.0222 Ether

    uint256 public isSaleActive = 0;
    uint256 public mintStart; // Unix timestamp

    constructor() ERC721("SlavikFruitFarm", "FFARMERS") {}

    function ownerMint(address _to, uint256 _reserveAmount) public onlyOwner {
        uint256 supply = totalSupply();
        for (uint256 i = 0; i < _reserveAmount; i++) {
            _safeMint(_to, supply + i);
        }
    }

    function mint(uint256 _count) public payable {
        require(block.timestamp > mintStart && mintStart > 0, "Mint hasn't started yet");
        uint256 totalSupply = totalSupply();

        require(totalSupply + _count < maxTokens + 1, "Not enough NFTs left to fill your order");

        require(msg.value >= price.mul(_count), "Not enough ETH sent");

        for (uint256 i = 0; i < _count; i++) {
            _safeMint(msg.sender, totalSupply + i);
        }
    }

    function setBaseURI(string memory _baseURI) public onlyOwner {
        _setBaseURI(_baseURI);
    }
    
    function changeMaxTokens(uint _maxAmount) public onlyOwner {
        maxTokens = _maxAmount;
    }
    
    function changePrice(uint _newPrice) public onlyOwner {
        price = _newPrice;
    }

    function changeMintDate(uint _dateInUnix) public onlyOwner {
        mintStart = _dateInUnix;
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        msg.sender.transfer(balance);
    }

    function tokensByOwner(address _owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 index;
            for (index = 0; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }
            return result;
        }
    }
}