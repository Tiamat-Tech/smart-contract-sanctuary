// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ACEInternal is ERC721Enumerable, Ownable {
    using Strings for uint256;

    string private baseURI;
    string private notRevealedURI;

    string public baseExtension = ".json";
    bool public revealed = false;

    //Config setup
    uint256 constant price = 0.1 ether; 
    uint256 constant whitelistPrice = 0.05 ether;

    uint256 public maxSupply = 10; // Maximun mint ACE
    uint256 public maxPreMintSupply = 10; // Maximun mint ACE (1998 + 300)

    uint256 public maxMintAmount = 6; //How many can mint for one buyer
    uint256 public maxPreMintAmount = 3; //How many can pre mint in one times
    uint256 public maxPartnerMintAmount = 30; //How many partner pre mint in one times

    //Paused
    bool public mintPaused = true;
    bool public preMintPaused = true;

    //White List
    address[] public whitelistedAddresses;
    address[] public partnerAddresses;

    mapping(address => uint256) public addressMintedBalance;

    //White List

    constructor() ERC721("ACEInternal", "ACE") {}

    /*
        MINT FUNCTION
     */
    function mint(uint256 mintAmount) public payable {
        uint256 supply = totalSupply();

        require(!mintPaused, "Mint ACE is paused");
        require(mintAmount > 0, "need to mint at least 1 ACE");
        require(mintAmount <= maxMintAmount, "Maximun mint amount per session exceeded");
        require(supply + mintAmount <= maxSupply, "Maximun NFT limit exceeded");
        require(msg.value >= price * mintAmount, "insufficient funds");

        uint256 ownerMintedCount = addressMintedBalance[msg.sender];

        require(ownerMintedCount + mintAmount <= maxMintAmount, "Maximun mint NFT per address exceeded");

        for (uint256 i = 1; i <= mintAmount; i++) {
            addressMintedBalance[msg.sender]++;
            _safeMint(msg.sender, supply + i);
        }
    }

    function preMint(uint256 mintAmount) public payable {
        uint256 supply = totalSupply();

        require(!preMintPaused, "Pre mint ACE is paused");
        require(mintAmount > 0, "need to mint at least 1 ACE");
        require(mintAmount <= maxPreMintAmount, "Maximun mint amount per session exceeded");
        
        require(supply + mintAmount <= maxPreMintSupply, "Pre mint sold out");
        require(isWhitelisted(msg.sender), "buyer not in whitelist");
        require(msg.value >= whitelistPrice * mintAmount, "insufficient funds");

        uint256 ownerMintedCount = addressMintedBalance[msg.sender];

        require(ownerMintedCount + mintAmount <= maxMintAmount, "Maximun mint NFT per address exceeded");
 
        for (uint256 i = 1; i <= mintAmount; i++) {
            addressMintedBalance[msg.sender]++;
            _safeMint(msg.sender, supply + i);
        }
    }

    function partnerMint(uint256 mintAmount) public payable {
        uint256 supply = totalSupply();

        require(!preMintPaused, "Pre mint ACE is paused");
        require(mintAmount > 0, "need to mint at least 1 ACE");
        require(mintAmount <= maxPartnerMintAmount, "Maximun mint amount per session exceeded");
        require(supply + mintAmount <= maxSupply, "Maximun ACE limit exceeded");
        require(isPartner(msg.sender), "buyer not in whitelist");
        require(msg.value >= whitelistPrice * mintAmount, "insufficient funds");

        uint256 ownerMintedCount = addressMintedBalance[msg.sender];

        require(ownerMintedCount + mintAmount <= maxPartnerMintAmount, "Maximun mint NFT per address exceeded");
 
        for (uint256 i = 1; i <= mintAmount; i++) {
            addressMintedBalance[msg.sender]++;
            _safeMint(msg.sender, supply + i);
        }
    }

    /*
        MINT BY OWNER FUNCTION
    */
    function mintForOwner(uint256 mintAmount) external onlyOwner {
        uint256 supply = totalSupply();

        require(mintAmount > 0, "need to mint at least 1 ACE");
        require(supply + mintAmount <= maxSupply, "max ACE limit exceeded");

        for (uint256 i = 1; i <= mintAmount; i++) {
            addressMintedBalance[msg.sender]++;
            _safeMint(msg.sender, supply + i);
        }
    }

    function giveawayMint(address to, uint256 mintAmount) external onlyOwner {
        uint256 supply = totalSupply();
        
        require(mintAmount > 0, "need to mint at least 1 ACE");
        require(mintAmount <= maxMintAmount, "max mint amount per session exceeded");
        require(supply + mintAmount <= maxSupply, "max ACE limit exceeded");
        
        for (uint256 i = 1; i <= mintAmount; i++) {
            addressMintedBalance[to]++;        
            _safeMint(to, supply + i);
        }
    }

    /*
        PUBLIC FUNCTION
     */
    function checkCostAmount(uint256 mintAmount) external view returns (uint256){
        if(mintPaused){
            return whitelistPrice * mintAmount;
        }
        else{
            return price;
        }
    }

    function isMintActive() external view returns (bool) {
        if(mintPaused)
            return false;
        else
            return true;
    }  
    
    function isPreMintActive() external view returns (bool) {
        if(preMintPaused)
            return false;
        else
            return true;
    }

    //metadata routing
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory){
        require(_exists(tokenId),"ERC721Metadata: URI query for nonexistent token");

        if (revealed == false) {
            return notRevealedURI;
        }

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(abi.encodePacked(currentBaseURI,tokenId.toString(),baseExtension))
                : "";
    }

    //Check White list Customer for pre mint
    function isWhitelisted(address _user) internal view returns (bool) {
        for (uint i = 0; i < whitelistedAddresses.length; i++) {
            if (whitelistedAddresses[i] == _user) {
                return true;
            }
        }
        return false;
    }

    function CheckSenderIsWhitelisted() external view returns (bool) {
        for (uint i = 0; i < whitelistedAddresses.length; i++) {
            if (whitelistedAddresses[i] == msg.sender) {
                return true;
            }
        }
        return false;
    }

    function isPartner(address _user) internal view returns (bool) {
        for (uint i = 0; i < partnerAddresses.length; i++) {
            if (partnerAddresses[i] == _user) {
                return true;
            }
        }
        return false;
    }
    
    //Check owned Id 
    function walletOfOwner(address _owner) public view returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
        tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    /*
        INTERNAL FUNCTION
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    /*
        ADMIN FUNCTION
     */
    function setReveal() public onlyOwner {
        revealed = true;
    }
    
    function startPublicMint(bool status) public onlyOwner {
        mintPaused = !status;
        preMintPaused = status;
    }

    function stopMint() public onlyOwner {
        mintPaused = true;
        preMintPaused = true;
    }

    function addWhitelistAddress(address[] calldata users) public onlyOwner {
        delete whitelistedAddresses; //Clean 
        whitelistedAddresses = users;
    }

    //Shut up and take the money
    function withdraw() public payable onlyOwner {
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");

        require(success, "Failed to send ether");
    }

    /*
        Config SETUP
    */

    //maxSupply
    function updateMaxSupply(uint256 _value) public onlyOwner {
        maxSupply = _value;
    }
    
    //MaxMintAmount
    function updateMaxMintAmount(uint256 _value) public onlyOwner {
        maxMintAmount = _value;
    }

    //baseURI
    function updateBaseURI(string memory _value) public onlyOwner {
        baseURI = _value;
    }

    //notRevealedUri
    function updateNotRevealedURI(string memory _value) public onlyOwner {
        notRevealedURI = _value;
    }
}