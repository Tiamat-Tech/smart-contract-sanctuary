// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC721.sol";
import "./ERC721Enumerable.sol";
import "./Ownable.sol";
import "./SafeMath.sol";
import "./Counters.sol";
import "./Strings.sol";
import "./Snail.sol";

contract BoneDucks is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    using Strings for uint256;
    
    Counters.Counter private _tokenIdTracker;

    Snail private snail;
    
    uint256 public maxFreeSupply = 500;
    uint256 public maxPublicSupply = 6555;
    uint256 public maxTotalSupply = 10555;
    uint256 public constant mintPrice = 0.07 ether;
    uint256 public constant maxPerTx = 20;
    
    address public dev1Address;
    address public dev2Address;

    bool public publicMintActive = false;
    bool public privateMintActive = false;
    bool public snailMintActive = false;
    
    mapping(address => bool) public userWhiteList; //Track free mints claimed per wallet
    
    string public baseTokenURI;

    modifier onlyWhiteList {
        require (
            userWhiteList[msg.sender] == true,
            "You're not in white list"
        );
        _;
    }

    modifier checkPublicSaleIsActive {
        require (
            publicMintActive,
            "Public Sale is not active"
        );
        _;
    }

    modifier checkPrivateSaleIsActive {
        require (
            privateMintActive,
            "Private Sale is not active"
        );
        _;
    }

    modifier checkSnailSaleIsActive {
        require (
            snailMintActive,
            "Snail Sale is not active"
        );
        _;
    }

    constructor(address dev1, address dev2) ERC721("BoneDucks", "BDS") {
        dev1Address = dev1;
        dev2Address = dev2;
    }
    
    //-----------------------------------------------------------------------------//
    //------------------------------Mint Logic-------------------------------------//
    //-----------------------------------------------------------------------------//
    /**
     * Get Tokens Of Owner
     */
    function getTokensOfOwner(address _owner) public view returns (uint256 [] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokenIdList = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokenIdList[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokenIdList;
    }

    // Update WhiteList
    function updateWhiteList(address[] memory addressList) external onlyOwner {
        for (uint256 i = 0; i < addressList.length; i += 1) {
            userWhiteList[addressList[i]] = true;
        }
    }

    // Private Mint for first 500, for whitelist users
    function privateMint() public checkPrivateSaleIsActive onlyWhiteList {
        userWhiteList[msg.sender] = false;
        _mintBoneDucks(msg.sender);
    }

    // Public Mint with ETH
    function publicMint(uint256 _count) public payable checkPublicSaleIsActive {
        uint256 total = _totalSupply();
        require(total + _count <= maxPublicSupply, "No BoneDucks left");
        require(_count <= maxPerTx, "20 max per tx");
        require(msg.value >= price(_count), "Not enough eth sent");

        for (uint256 i = 0; i < _count; i++) {
            _mintBoneDucks(msg.sender);
        }
    }

    // Public Mint with Snails
    function publicMintWithSnail() public checkSnailSaleIsActive {
        uint256 total = _totalSupply();
        require(total < maxTotalSupply, "No BoneDucks left");
        
        snail.burn(msg.sender, getSnailCost());
        _mintBoneDucks(msg.sender);
    }
    
    function getSnailCost() public view returns (uint256 cost) {
        uint256 total = _totalSupply();

        if (total < maxPublicSupply.add(1000))
            return 100;
        else if (total < maxPublicSupply.add(2000))
            return 200;
        else if (total < maxPublicSupply.add(3000))
            return 400;
        else if (total < maxPublicSupply.add(4000))
            return 800;
    }
    
    //Mint BoneDuck
    function _mintBoneDucks(address _to) internal {
        uint id = _tokenIdTracker.current();
        _tokenIdTracker.increment();
        _safeMint(_to, id);
    }

    //Function to get price of minting a Duck
    function price(uint256 _count) public pure returns (uint256) {
        return mintPrice.mul(_count);
    }
    
    //-----------------------------------------------------------------------------//
    //---------------------------Admin & Internal Logic----------------------------//
    //-----------------------------------------------------------------------------//
    // Resume/pause Public Sale
    function togglePublicMint() public onlyOwner {
        publicMintActive = !publicMintActive;
    }

    // Resume/pause Private Sale
    function togglePrivateMint() public onlyOwner {
        privateMintActive = !privateMintActive;
    }

    // Start/Stop minting Ducks for $Snail
    function toggleSnailMint() public onlyOwner {
        snailMintActive = !snailMintActive;
    }

    // Update Public & Total Supply
    function updatePublicSupply(uint256 updatedPublicSupply) public onlyOwner {
        maxPublicSupply = updatedPublicSupply;
        maxTotalSupply = updatedPublicSupply.add(4000);
    }

    // Set address for $Snail
    function setSnailAddress(address snailAddress) external onlyOwner {
        snail = Snail(snailAddress);
    }
    
    // Internal URI function
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }
    
    // Set URI for metadata
    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }
    
    //Withdraw from contract
    function withdrawAll() public onlyOwner {
        uint256 balance = address(this).balance;
        uint256 dev1Share = balance.mul(700).div(10000); // 7%
        uint256 dev2Share = balance.sub(dev1Share); // 93%

        _withdraw(dev1Address, dev1Share);
        _withdraw(dev2Address, dev2Share);
    }

    //Internal withdraw
    function _withdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{value: _amount}("");
        require(success, "Transfer failed.");
    }
    
    //Return total supply of hammies
    function _totalSupply() public view returns (uint) {
        return _tokenIdTracker.current();
    }
}