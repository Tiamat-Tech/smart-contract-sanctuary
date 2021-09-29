// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
    ░██████╗████████╗░█████╗░██╗░░██╗███████╗██████╗░░██████╗
    ██╔════╝╚══██╔══╝██╔══██╗██║░██╔╝██╔════╝██╔══██╗██╔════╝
    ╚█████╗░░░░██║░░░███████║█████═╝░█████╗░░██████╔╝╚█████╗░
    ░╚═══██╗░░░██║░░░██╔══██║██╔═██╗░██╔══╝░░██╔══██╗░╚═══██╗
    ██████╔╝░░░██║░░░██║░░██║██║░╚██╗███████╗██║░░██║██████╔╝
    ╚═════╝░░░░╚═╝░░░╚═╝░░╚═╝╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚═════╝░
    StakersNFT / 2021

*/
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';



contract SteakerTESTIE is ERC721Enumerable, Ownable {
    using Strings for uint256;

    uint256 public constant stakersReserve = 10;
    uint256 public constant stakersPublic = 10000;
    uint256 public constant stakersMax = stakersReserve + stakersPublic;
    uint256 public constant stakersPrice = 0.0000000000008 ether;
    uint256 public constant stakersPurchaseLimit = 1000;
    uint256 public constant presalePurchaseLimit = 2;
    
    mapping(address => bool) public presalerList;
    mapping(address => uint256) public presalerListPurchases;
    mapping (uint256 => string) private mysterySkin;
    mapping (uint256 => string) private _tokenURIs;
    
    
    uint256 public publicAmountMinted;
    uint256 public totalGiftSupply;
    bool public preSaleLive;
    bool public saleLive;
    
    string private _contractURI = '';
    string private _tokenBaseURI = '';
    string private _tokenRevealedBaseURI = '';

    constructor() ERC721("Stakers", "STKR") { 
        
      
    }
    
    function addToPresaleList(address[] calldata entries) external onlyOwner {
        for(uint256 i = 0; i < entries.length; i++) {
            address entry = entries[i];
            require(entry != address(0), "Cannot Add Null address");
            require(!presalerList[entry], "There is a Duplicate Entry");

            presalerList[entry] = true;
        }   
    }

    function removeFromPresaleList(address[] calldata entries) external onlyOwner {
        for(uint256 i = 0; i < entries.length; i++) {
            address entry = entries[i];
            require(entry != address(0), "Cannot Add Null address");
            
            presalerList[entry] = false;
        }
    }
    
    
 function mintStaker(uint256 numberOfTokens) external payable {
  //  require(saleLive, 'Contract is not active');
  //  require(!preSaleLive, 'Only allowing from Allow List');
    require(totalSupply() < stakersMax, 'All tokens have been minted');
    require(numberOfTokens <= stakersPurchaseLimit, 'Would exceed PURCHASE_LIMIT');
    require(publicAmountMinted < stakersMax, 'Purchase would exceed PUBLIC');
    require(stakersPrice * numberOfTokens <= msg.value, 'ETH amount is not sufficient');

    for (uint256 i = 0; i < numberOfTokens; i++) {
      if (publicAmountMinted < stakersPublic) {
        uint256 tokenId = stakersReserve + publicAmountMinted + 1;
        publicAmountMinted += 1;
        _safeMint(msg.sender, tokenId);
      }
    }
  }

  function purchaseAllowList(uint256 numberOfTokens) external payable {
  //  require(saleLive, 'Contract is not active');
  //  require(preSaleLive, 'Allow List is not active');
    require(presalerList[msg.sender], 'You are not on the Allow List');
    require(totalSupply() < stakersMax, 'All tokens have been minted');
    require(numberOfTokens <= presalePurchaseLimit, 'Cannot purchase this many tokens');
    require(publicAmountMinted + numberOfTokens <= stakersMax, 'Purchase would exceed PUBLIC');
    require(presalerListPurchases[msg.sender] + numberOfTokens <= presalePurchaseLimit, 'Purchase exceeds max allowed');
    require(stakersPrice * numberOfTokens <= msg.value, 'ETH amount is not sufficient');

         for (uint256 i = 0; i < numberOfTokens; i++) {
            publicAmountMinted++;
            presalerListPurchases[msg.sender]++;
            _safeMint(msg.sender, totalSupply() + 1);
        }
  }

  function gift(address[] calldata to) external onlyOwner {
    require(totalSupply() < stakersReserve, 'All tokens have been minted');
    require(totalGiftSupply + to.length <= stakersReserve, 'Not enough tokens left to gift');

    for(uint256 i = 0; i < to.length; i++) {
      uint256 tokenId = totalGiftSupply + 1;

      totalGiftSupply += 1;
      _safeMint(to[i], tokenId);
    }
  }
   
    
  function withdraw() external  onlyOwner {
    uint256 balance = address(this).balance;

    payable(msg.sender).transfer(balance);
  }
    
    function isPresaler(address addr) external view returns (bool) {
        return presalerList[addr];
    }
    
    function presalePurchasedCount(address addr) external view returns (uint256) {
        return presalerListPurchases[addr];
    }
    
    function togglePresaleStatus() external onlyOwner {
        preSaleLive = !preSaleLive;
    }
    
    function toggleSaleStatus() external onlyOwner {
        saleLive = !saleLive;
    }
    

    function activateMysterySkin(uint256 tokenId) public {
        address owner = ERC721.ownerOf(tokenId);
        require(
            _msgSender() == owner,
            "This isn't your Staker."
        );
        require (bytes(mysterySkin[tokenId]).length == 0, "Your Myster Skin is already active.");
           
        mysterySkin[tokenId] = "a";
    }
     function deActivateMysterySkin(uint256 tokenId) public {
        address owner = ERC721.ownerOf(tokenId);
        require(
            _msgSender() == owner,
            "This isn't your Staker."
        );
        require (bytes(mysterySkin[tokenId]).length > 0, "Your Myster Skin is already deactived.");

           
        mysterySkin[tokenId] = "";
    }
    

  function setContractURI(string calldata URI) external onlyOwner {
    _contractURI = URI;
  }

  function setBaseURI(string calldata URI) external onlyOwner {
    _tokenBaseURI = URI;
  }

  function setRevealedBaseURI(string calldata revealedBaseURI) external onlyOwner {
    _tokenRevealedBaseURI = revealedBaseURI;
  }

  function contractURI() public view returns (string memory) {
    return _contractURI;
  }   
    
    
    
  function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
    require(_exists(tokenId), 'ERC721Metadata: URI query for nonexistent token');

    string memory revealedBaseURI = _tokenRevealedBaseURI;
    return bytes(revealedBaseURI).length > 0 ?
      string(abi.encodePacked(revealedBaseURI, tokenId.toString(), mysterySkin[tokenId])) :
      _tokenBaseURI;
  }

    
 /*   function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
            require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

            string memory _tokenURI = _tokenURIs[tokenId];
            string memory base = _baseURI();
            

            // If there is no base URI, return the token URI.
            if (bytes(base).length == 0) {
                return _tokenURI;
            }
            // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
            if (bytes(_tokenURI).length > 0) {
                return string(abi.encodePacked(base, _tokenURI));
            }
            // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
            return string(abi.encodePacked(base, tokenId.toString(), mysterySkin[tokenId]));

            
        }*/


}