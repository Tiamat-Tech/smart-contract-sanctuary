// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

 contract LizardLab is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Address for address;
    
    //provenance
    string public PROOF_OF_ANCESTORY;

    //location
    string public baseURI;
    
    //fives are good numbers... lets go with 5s
    uint256 public maxSupply = 5000;
    uint256 public price = 0.05 ether;

    //don't get any ideas too soon, you see?
    bool public freesaleActive = false;
    bool public presaleActive = false;
    bool public saleActive = false;

    //has [REDACTED] populated the war chest?
    bool public redactedClaimed = false;

    //somebody gets paid for this i guess
    address redLizard = 0x23E49659AB96337feBEBDe9De48279190383aDF6;
    address blueLizard = 0x87E9Ab2D6f4f744f36aad379f0157da30d3E2670;
    address greenLizard = 0x23E49659AB96337feBEBDe9De48279190383aDF6;
    address warChest = 0x23E49659AB96337feBEBDe9De48279190383aDF6;

    //i guess some lizards are...more privileged than others
    mapping (address => uint256) public presaleWhitelist;
    mapping (address => uint256) public freesaleWhitelist;

    //there is a lot to unpack here
    constructor() ERC721("The Lizard Lab", "LIZRD") {      
    }
    
    //before they all escape.. some for us.. some for you
    function capture() public onlyOwner {
        uint256 supply = totalSupply();
        require(!redactedClaimed, "Only once, even for you [REDACTED]");
        for (uint256 i = 0; i < 50; i++) {
            _safeMint(warChest, supply + i);
        }

        redactedClaimed = true;
    }

    //a freebie for you, thank you for your support
    function claim(uint256 numberOfMints) public {
        uint256 supply = totalSupply();
        uint256 reserved = freesaleWhitelist[msg.sender];
        require(freesaleActive,                              "Claim period must be active to claim");
        require(reserved > 0,                               "No tokens reserved for this address");
        require(numberOfMints <= reserved,                  "Can't mint more than reserved");
        require(supply.add(numberOfMints) <= maxSupply,     "Purchase would exceed max supply of tokens");
        freesaleWhitelist[msg.sender] = reserved - numberOfMints;

        for(uint256 i; i < numberOfMints; i++){
            _safeMint( msg.sender, supply + i );
        }
    }
    
    //thanks for hanging out..
    function mintPresale(uint256 numberOfMints) public payable {
        uint256 supply = totalSupply();
        uint256 reserved = presaleWhitelist[msg.sender];
        require(presaleActive,                              "Presale must be active to mint");
        require(reserved > 0,                               "No tokens reserved for this address");
        require(numberOfMints <= reserved,                  "Can't mint more than reserved");
        require(supply.add(numberOfMints) <= maxSupply,     "Purchase would exceed max supply of tokens");
        require(price.mul(numberOfMints) == msg.value,      "Ether value sent is not correct");
        presaleWhitelist[msg.sender] = reserved - numberOfMints;

        for(uint256 i; i < numberOfMints; i++){
            _safeMint( msg.sender, supply + i );
        }
    }
    
    //..and now for the rest of you
    function mint(uint256 numberOfMints) public payable {
        uint256 supply = totalSupply();
        require(saleActive,                                 "Sale must be active to mint");
        require(numberOfMints > 0 && numberOfMints < 6,    "Invalid purchase amount");  //only 5 at a time you greedy greedy lizard
        require(supply.add(numberOfMints) <= maxSupply,     "Purchase would exceed max supply of tokens");
        require(price.mul(numberOfMints) == msg.value,      "Ether value sent is not correct");
        
        for(uint256 i; i < numberOfMints; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }

    //somebody has to keep track of all of this
    function editPresale(address[] calldata presaleAddresses, uint256[] calldata amount) public onlyOwner {
        for(uint256 i; i < presaleAddresses.length; i++){
            presaleWhitelist[presaleAddresses[i]] = amount[i];
        }
    }
    
    //should we ever need to peek
    function walletOfOwner(address owner) external view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for(uint256 i; i < tokenCount; i++){
            tokensId[i] = tokenOfOwnerByIndex(owner, i);
        }
        return tokensId;
    }

    //coins for the creat0rz
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(redLizard).transfer((balance * 400) / 1000);
        payable(greenLizard).transfer((balance * 400) / 1000);
        payable(blueLizard).transfer((balance * 200) / 1000);
    }

    //and a flip of the (small) switch
    function togglePresale() public onlyOwner {
        presaleActive = !presaleActive;
    }

    //on my signal, unleash hell
    function toggleSale() public onlyOwner {
        saleActive = !saleActive;
    }

    //the lab runner made me put this here..as to not..tinker with anything
    function setAncestory(string memory provenance) public onlyOwner {
        require(bytes(PROOF_OF_ANCESTORY).length > 0, "Provenance hash can only be set once.");

        PROOF_OF_ANCESTORY = provenance;
    }
    
    //for the grand reveal and where things are now.. where things will forever be.. lizards willing
    function setBaseURI(string memory uri) public onlyOwner {
        baseURI = uri;
    }
    
    //come have a looksy
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
}