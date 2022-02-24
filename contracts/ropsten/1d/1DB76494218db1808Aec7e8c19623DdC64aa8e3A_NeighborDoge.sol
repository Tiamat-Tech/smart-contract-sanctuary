pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./RandomlyAssigned.sol";

contract NeighborDoge is ERC721Enumerable, Ownable, RandomlyAssigned {
    using Strings for uint256;
    using SafeMath for uint256;

    //NFT params
    string public baseURI;
    string public defaultURI;
    bool public finalizeBaseUri = false;

    //sale stages:
    //stage 0: init(no minting)
    //stage 1: pre sale
    //stage 2: public sale
    uint8 public stage = 0;

    // presale
    mapping(address => bool) public presale_whitelisted;
    uint256 public presalePrice = 0.004 ether;
    uint256 public presaleSupply;
    uint256 public presaleMintMax = 1;

    //public sale (stage=2)
    uint256 public salePrice = 0.005 ether;
    uint256 public totalSaleSupply;
    uint256 public saleMintMax = 1;

    //others
    bool public paused = false;
    mapping(uint256 => bool) public mintTokenIDs;
    mapping(address => bool) public mintAddress;

    //sale holders
    address public fundRecipients = 0xfb8D481fA85B8c36A4851c68a56f8A4e308428E4;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI,
        string memory _defaultURI,
        uint256 _presaleSupply,
        uint256 _totalSaleSupply
    )
    ERC721(_name, _symbol)
    RandomlyAssigned(_totalSaleSupply, 0)
    {
        require(_totalSaleSupply > _presaleSupply, "_totalSaleSupply must more than _presaleSupply");

        setBaseURI(_initBaseURI);
        defaultURI = _defaultURI;
        presaleSupply = _presaleSupply;
        totalSaleSupply = _totalSaleSupply;
    }

    // internal
    function random(uint number) public view returns (uint){
        return uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty,
            msg.sender))) % number;
    }

    function _getRandomTokenID() internal view returns (uint256) {
        uint256 _tokenID = 0;
        uint256 leftSupply = totalSaleSupply - totalSupply();
        uint256[] memory leftTokenIDs = new uint256[](leftSupply);
        uint256 leftIndex = 0;

        for (uint256 i = 1; i <= totalSaleSupply; i++) {
            if (mintTokenIDs[i] == false) {
                leftTokenIDs[leftIndex] = i;
                leftIndex += 1;
            }
        }
        if (leftTokenIDs.length == 1) {
            _tokenID = leftTokenIDs[0];
        } else {
            uint256 randomID = random(leftIndex);
            _tokenID = leftTokenIDs[randomID];
        }

        return _tokenID;
    }

    function _getNextTokenID() internal view returns (uint256) {
        uint256 _tokenID = 0;
        uint256 leftSupply = totalSaleSupply - totalSupply();
        uint256[] memory leftTokenIDs = new uint256[](leftSupply);
        uint256 leftIndex = 0;

        for (uint256 i = 1; i <= totalSaleSupply; i++) {
            if (mintTokenIDs[i] == false) {
                leftTokenIDs[leftIndex] = i;
                leftIndex += 1;
            }
        }
        if (leftTokenIDs.length > 0) {
            _tokenID = leftTokenIDs[0];
        }

        return _tokenID;
    }

    // public
    function mint(uint8 _mintType) public payable {
        uint256 supply = totalSupply();
        require(!paused, "sale paused");
        require(stage > 0, "sale stage is 0");
        require(mintAddress[msg.sender] == false, "msg.sender already mint");
        require(_mintType >= 0, "_mintType must more than or equal 0");

        uint256 _mintAmount;
        if (stage == 1) {
            // pre-sale
            require(presale_whitelisted[msg.sender], "msg.sender not in presale_whitelisted");
            require(supply + presaleMintMax <= presaleSupply, "totalSupply + presaleMintMax exceed the presaleSupply limit");
            require(msg.value >= presalePrice * presaleMintMax, "msg.value must be greater than presalePrice * presaleMintMax");
            _mintAmount = presaleMintMax;
        } else {
            //public sale
            require(supply + saleMintMax <= totalSaleSupply, "totalSupply + saleMintMax exceed the totalSaleSupply limit");
            require(msg.value >= salePrice * saleMintMax, "msg.value must be greater than salePrice * saleMintMax");
            _mintAmount = saleMintMax;
        }


        if (_mintType == 0) {
            // Random mint
            for (uint256 i = 1; i <= _mintAmount; i++) {
                //                uint256 _tonenID = _getRandomTokenID();
                uint256 _tokenID = nextToken();
                _safeMint(msg.sender, _tokenID);
                mintTokenIDs[_tokenID] = true;
            }
        } else {
            // Sequential mint
            for (uint256 i = 1; i <= _mintAmount; i++) {
                uint256 _tokenID = _getNextTokenID();
                _safeMint(msg.sender, _tokenID);
                mintTokenIDs[_tokenID] = true;
                setValue(_tokenID);
            }
        }

        mintAddress[msg.sender] = true;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory){
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        return bytes(baseURI).length > 0
        ? string(abi.encodePacked(baseURI, tokenId.toString()))
        : defaultURI;
    }

    //only owner functions ---
    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        require(!finalizeBaseUri, "finalizeBaseUri must be false");
        baseURI = _newBaseURI;
    }

    function finalizeBaseURI() public onlyOwner {
        finalizeBaseUri = true;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function whitelistPresaleUsers(address[] memory _users) public onlyOwner {
        for (uint i = 0; i < _users.length; i++)
            presale_whitelisted[_users[i]] = true;
    }

    function removePresaleWhitelistUser(address _user) public onlyOwner {
        presale_whitelisted[_user] = false;
    }

    function nextStage() public onlyOwner() {
        require(stage < 2, "stage is already 2");
        stage++;
    }

    function giveAway(uint256 _tokenID, address _toAddress) public onlyOwner {
        require(totalSaleSupply > totalSupply(), "totalSupply exceed the totalSaleSupply limit");
        require(_tokenID >= 0, "_tokenID must more than or equal 0");
        if (_tokenID == 0) {
            // random mint
            //            uint256 _randomTokenID = _getRandomTokenID();
            uint256 _randomTokenID = nextToken();
            _safeMint(_toAddress, _randomTokenID);
            mintTokenIDs[_randomTokenID] = true;
        } else {
            // special mint
            require(_tokenID <= totalSaleSupply, "_tokenID exceed the totalSaleSupply limit");
            require(mintTokenIDs[_tokenID] == false, "_tokenID has been mint");
            _safeMint(_toAddress, _tokenID);
            mintTokenIDs[_tokenID] = true;
            setValue(_tokenID);
        }
    }

    //fund withdraw functions ---
    function withdrawFund() public onlyOwner {
        uint256 currentBal = address(this).balance;
        require(currentBal > 0, "current balance is 0");
        _withdraw(fundRecipients, address(this).balance);
    }

    function _withdraw(address _addr, uint256 _amt) private {
        (bool success,) = _addr.call{value : _amt}("");
        require(success, "Transfer failed");
    }

}