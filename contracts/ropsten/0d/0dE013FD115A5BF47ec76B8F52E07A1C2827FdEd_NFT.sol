// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;



import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


interface CupCatInterface is IERC721{
    function walletOfOwner(address _owner) external view returns (uint256[] memory);
}


contract NFT is ERC721Enumerable, Ownable, ReentrancyGuard {
  
    uint16 private _tokenIdTrackerReserve;
    uint16 private _tokenIdTrackerPublicSale;
    uint16 private _tokenIdTracker;

    using Strings for uint256;

    uint256 public constant MAXCLAIMSUPPLY = 5007;
    uint256 public constant MAX_ELEMENTS = 10000; //  reserve + claim + Mint
    uint256 public constant MAXRESERVE = 0;
    uint256 public constant MAXPUBLICSALE = MAX_ELEMENTS - MAXCLAIMSUPPLY - MAXRESERVE;
    string public baseURI;
    string public baseExtension = ".json";
    uint256 public cost = 0.02 ether;
    uint256 public nftPerAddressLimit = 1;
    bool public paused = false;
    bool public claimOpen = false;
    bool public sale = false;
    bool public onlyWhitelisted = true;
    address[] public whitelistedAddresses;
    mapping(address => uint256) public addressMintedBalance;
    mapping (uint256 => bool) private _cupCatsUsed;
    event MintCupCat(uint256 indexed id);
    CupCatInterface public cupCats;

  
  constructor(

      ) ERC721("Xkitty", "XKT") {
        setBaseURI("exampleurl");
        setCupcats(0x8Cd8155e1af6AD31dd9Eec2cEd37e04145aCFCb3);
      }

      // internal
      function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
      }

      //Modify
          modifier claimIsOpen {
            //openClaim Function
              require(!paused, "Contract Paused");
              _;
          }
          modifier saleIsOpen {
              require(sale, "Sale is Closed");
              require(!paused, "Contract Paused");
              _;
          }


      // public
        function mint(uint256 _count) public payable saleIsOpen nonReentrant{
                require(!paused, "the contract is paused");
                require(_tokenIdTrackerPublicSale + _count <= MAXPUBLICSALE, "Sold Out!");
                require(_count <= 10, "Exceeds number");
                require(msg.value >= cost * _count, "insufficient funds");

                if (msg.sender != owner()) {    
                      uint256 ownerMintedCount = addressMintedBalance[msg.sender]; 
                        if(onlyWhitelisted == true) {
                          require(isWhitelisted(msg.sender), "user is not whitelisted");
                          require(ownerMintedCount + _count <= nftPerAddressLimit, "max NFT per address exceeded");
                      }
                      require(msg.value >= cost * _count, "insufficient funds");
                          require(ownerMintedCount + _count <= nftPerAddressLimit, "max NFT per address exceeded");
                  }

                for (uint256 i = 0; i < _count; i++) {
                     addressMintedBalance[msg.sender]++;
                    _mintToken(_msgSender(), MAXCLAIMSUPPLY + MAXRESERVE + _tokenIdTrackerPublicSale);
                    _tokenIdTrackerPublicSale += 1;
                }
            }

            function claim(uint256[] memory _tokensId) public claimIsOpen {
                require(_tokensId.length <= 10, "Exceeds number");
                for (uint256 i = 0; i < _tokensId.length; i++) {
                    require(canClaim(_tokensId[i]) && cupCats.ownerOf(_tokensId[i]) == _msgSender(), "Bad owner!");
                    _cupCatsUsed[_tokensId[i]] = true;
                    _mintToken(_msgSender(), _tokensId[i]);
                }
            }

            function canClaim(uint256 _tokenId) public view returns(bool) {
                return _cupCatsUsed[_tokenId] == false;
            }
            
            function _mintToken(address _to, uint256 id) private {
                _tokenIdTracker += 1;
                _safeMint(_to, id);
                emit MintCupCat(id);
            }

            function reserve(uint256 _count) public onlyOwner {
                require(_tokenIdTrackerReserve + _count <= MAXRESERVE, "Exceeded giveaways.");
                for (uint256 i = 0; i < _count; i++) {
                    _mintToken(_msgSender(), MAXCLAIMSUPPLY + _tokenIdTrackerReserve);
                    _tokenIdTrackerReserve += 1;
                }
            }

            function isWhitelisted(address _user) public view returns (bool) {
              for (uint i = 0; i < whitelistedAddresses.length; i++) {
                if (whitelistedAddresses[i] == _user) {
                    return true;
                  }
                }
              return false;
            }



          function walletOfOwner(address _owner)
            public
            view
            returns (uint256[] memory)
          {
            uint256 ownerTokenCount = balanceOf(_owner);
            uint256[] memory tokenIds = new uint256[](ownerTokenCount);
            for (uint256 i; i < ownerTokenCount; i++) {
              tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
            }
            return tokenIds;
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
                ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
                : "";
          }

          //only owner

        function setCupcats(address _cupCats) public onlyOwner {
          cupCats = CupCatInterface(_cupCats);
          }
          
        function setNftPerAddressLimit(uint256 _limit) public onlyOwner {
            nftPerAddressLimit = _limit;
          }
          
        function setCost(uint256 _newCost) public onlyOwner {
            cost = _newCost;
          }

        function setBaseURI(string memory _newBaseURI) public onlyOwner {
            baseURI = _newBaseURI;
          }

        function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
            baseExtension = _newBaseExtension;
          }
          

        function pause(bool _state) public onlyOwner {
            paused = _state;
          }
          
        function sales(bool _state) public onlyOwner{
             sale = _state;
          }

        function flipOnlyWhitelisted() public onlyOwner {
            onlyWhitelisted = !onlyWhitelisted;
          }

        function setClaim() public onlyOwner {
             claimOpen = !claimOpen;
         }

 
        function whitelistUsers(address[] calldata _users) public onlyOwner {
            delete whitelistedAddresses;
            whitelistedAddresses = _users;
          }
        
        function withdraw() public payable onlyOwner {
            (bool os, ) = payable(owner()).call{value: address(this).balance}("");
            require(os);
          }

  
}