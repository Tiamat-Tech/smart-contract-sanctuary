pragma solidity >=0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract SlavikFruitFarm is ERC721, Ownable {
    using SafeMath for uint256;

    uint256 public maxTokens = 8888; //Total supply of the NFT
    uint256 public presaleMaxTokens = 1000; //Total NFTs supplied for the presale
    uint256 public presaleTokenLimit = 1; //Maximum NFTs you can mint in the presale

    uint256 public price = 22200000000000000; // 0.0222 ETH
    uint256 public presalePrice = 22200000000000000; // 0.0222 ETH

    uint256 public mintStart; // Unix timestamp
    uint256 public presaleStart; // Unix timestamp
    uint256 public presaleEnd; // Unix timestamp
    uint256 public presaleDuration = 259200; // 3 days in seconds

    mapping(address => bool) whitelistedAddresses;

    constructor() ERC721("SlavikFruitFarm", "FFARMERS") {}

    function ownerMint(address _to, uint256 _reserveAmount) public onlyOwner {
        uint256 supply = totalSupply();
        for (uint256 i = 0; i < _reserveAmount; i++) {
            _safeMint(_to, supply + i);
        }
    }

    function mint(uint256 _count) public payable {
        require(block.timestamp > mintStart && mintStart > 0, "Mint has not started yet");
        uint256 totalSupply = totalSupply();

        require(totalSupply + _count < maxTokens + 1, "Not enough NFTs left to fill your order");

        require(msg.value >= price.mul(_count), "Not enough ETH sent");

        for (uint256 i = 0; i < _count; i++) {
            _safeMint(msg.sender, totalSupply + i);
        }
    }

    function presaleMint(uint256 _count) public payable {
        require(whitelistedAddresses[msg.sender], "You are not whitelisted or you have already minted");

        require(block.timestamp > presaleStart && presaleStart > 0, "Presale has not started yet");
        require(block.timestamp < presaleEnd && presaleStart > 0, "Presale has ended");

        require(_count < presaleMaxTokens + 1, "Not enough NFTs left to fill your order");
        uint256 totalSupply = totalSupply();

        require(_count < presaleTokenLimit + 1, "You are not allowed to mint that many NFTs in the presale");

        require(msg.value >= presalePrice.mul(_count), "Not enough ETH sent");

        for (uint256 i = 0; i < _count; i++) {
            _safeMint(msg.sender, totalSupply + i);
        }

        whitelistedAddresses[msg.sender] = false;
    }

    function changeMaxTokens(uint _maxAmount) public onlyOwner {
        maxTokens = _maxAmount;
    }

    function changePresaleMaxTokens(uint _maxAmount) public onlyOwner {
        presaleMaxTokens = _maxAmount;
    }

    function changePrice(uint _newPrice) public onlyOwner {
        price = _newPrice;
    }

    function changePresalePrice(uint _newPrice) public onlyOwner {
        presalePrice = _newPrice;
    }

    function changeMintDate(uint _dateInUnix) public onlyOwner {
        mintStart = _dateInUnix;
    }

    function changePresaleDate(uint _dateInUnix) public onlyOwner {
        presaleStart = _dateInUnix;
        presaleEnd = _dateInUnix + presaleDuration;
    }

    function addAddressesToWhitelist(address[] memory _usersToAdd) public onlyOwner {
        for (uint256 index = 0; index < _usersToAdd.length; index++) {
            whitelistedAddresses[_usersToAdd[index]] = true;
        }
    }

    function setBaseURI(string memory _baseURI) public onlyOwner {
        _setBaseURI(_baseURI);
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

    function hasWhitelist(address _whitelistedAddress) public view returns(bool) {
        bool userIsWhitelisted = whitelistedAddresses[_whitelistedAddress];
        return userIsWhitelisted;
    }

    function getUnix() external view returns (uint256) {
        return block.timestamp;
    }
}