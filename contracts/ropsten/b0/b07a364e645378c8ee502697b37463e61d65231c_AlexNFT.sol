pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract AlexNFT is ERC721Enumerable, Ownable {
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

    //pre-sale (stage=1)
    mapping(address => bool) public presale_whitelisted;

    uint256 public presalePrice = 0.004 ether;
    uint256 public presaleSupply;  //2400
    uint256 public presaleMintMax = 1;

    //public sale (stage=2)
    uint256 public salePrice = 0.005 ether;
    uint256 public totalSaleSupply; //3000
    uint256 public saleMintMax = 3;

    //others
    bool public paused = false;

    //sale holders
    address[1] public fundRecipients = [
    0xc8Ad1e038c0E6c76297432CFC1a1aDB982e5546e
    ];
    uint256[] public receivePercentagePt = [10000];   //distribution in basis points

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI,
        string memory _defaultURI,
        uint256 _presaleSupply,
        uint256 _totalSaleSupply
    ) ERC721(_name, _symbol) {
        require(_totalSaleSupply > _presaleSupply, "_totalSaleSupply must more than _presaleSupply");

        setBaseURI(_initBaseURI);
        defaultURI = _defaultURI;
        presaleSupply = _presaleSupply;
        totalSaleSupply = _totalSaleSupply;
    }

    // internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    // public
    function mint(uint8 _mintAmount) public payable {
        uint256 supply = totalSupply();
        require(!paused, "sale paused");
        require(stage > 0, "sale stage is 0");
        require(_mintAmount > 0, "mintAmount must more than 0");

        if (stage == 1) {
            // pre-sale
            require(presale_whitelisted[msg.sender], "msg.sender not in presale_whitelisted");
            require(supply + _mintAmount <= presaleSupply, "totalSupply + mintAmount exceed the presaleSupply limit");
            require(_mintAmount <= presaleMintMax, "mintAmount must less than or equal presaleMintMax");
            require(msg.value >= presalePrice * _mintAmount, "msg.value must be greater than presalePrice * mintAmount");
        } else {
            //public sale
            require(supply + _mintAmount <= totalSaleSupply, "totalSupply + mintAmount exceed the totalSaleSupply limit");
            require(_mintAmount <= saleMintMax, "mintAmount must less than or equal saleMintMax");
            require(msg.value >= salePrice * _mintAmount, "msg.value must be greater than salePrice * mintAmount");
        }
        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }

    function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString()))
        : defaultURI;
    }

    //only owner functions ---
    function nextStage() public onlyOwner() {
        require(stage < 2, "stage is already 2");
        stage++;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        require(!finalizeBaseUri);
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

    //fund withdraw functions ---
    function withdrawFund() public onlyOwner {
        uint256 currentBal = address(this).balance;
        require(currentBal > 0, "current balance is 0");
        for (uint256 i = 0; i < fundRecipients.length - 1; i++) {
            _withdraw(fundRecipients[i], currentBal.mul(receivePercentagePt[i]).div(10000));
        }
        //final address receives remainder to prevent ether dust
        _withdraw(fundRecipients[fundRecipients.length - 1], address(this).balance);
    }

    function _withdraw(address _addr, uint256 _amt) private {
        (bool success,) = _addr.call{value : _amt}("");
        require(success, "Transfer failed");
    }
}