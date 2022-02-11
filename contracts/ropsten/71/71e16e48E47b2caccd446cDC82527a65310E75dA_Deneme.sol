// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Deneme is ERC721, ERC721Enumerable, Ownable {
    string public baseURI = "";

    uint256 public constant  tokenPrice = 0.02 ether;
    uint256 public constant MAX_TOKENS = 10;
    uint256 public constant maxTokenPurchase = 5;
    uint256 public devReserve = 64;
    uint256 public presaleMaxMint = 2;

    bool public saleIsActive = false;
    bool public presaleIsActive = false;
    bool public isRevealed = false;

    mapping(address => bool) private _presaleList;
    mapping(address => uint256) private _presaleListClaimed;

    event EmojiMinted(uint256 tokenId, address owner);

    constructor() ERC721("Deneme", "DEN") {}

    function safeMint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function reveal() public onlyOwner {
        isRevealed = true;
    }
    
    function reserveTokens(address _to, uint256 _reserveAmount)
        external
        onlyOwner
    {
        require(
            _reserveAmount > 0 && _reserveAmount <= devReserve,"Not enough reserve left for team");
        for (uint256 i = 0; i < _reserveAmount; i++) {
            uint256 id = totalSupply();
            _safeMint(_to, id);
        }
        devReserve = devReserve - _reserveAmount;
    }
    
    function toggleSaleState() external onlyOwner {
        saleIsActive = !saleIsActive;
    }
    
    function togglePresaleState() external onlyOwner {
        presaleIsActive = !presaleIsActive;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }
    function tokensOfOwner(address _owner)
        external
        view
        returns (uint256[] memory)
      {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
          // Return an empty array
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
    
      function mintEmoji(uint256 numberOfTokens) external payable {
        require(saleIsActive, "Sale must be active to mint Token");
        require(
          numberOfTokens > 0 && numberOfTokens <= maxTokenPurchase,
          "Can only mint one or more tokens at a time"
        );
        require(
          totalSupply() + numberOfTokens <= MAX_TOKENS,
          "Purchase would exceed max supply of tokens"
        );
        require(
          msg.value >= tokenPrice * numberOfTokens,
          "Ether value sent is not correct"
        );
    
        for (uint256 i = 0; i < numberOfTokens; i++) {
          uint256 id = totalSupply() + 1;
          if (totalSupply() < MAX_TOKENS) {
            _safeMint(msg.sender, id);
            emit EmojiMinted(id, msg.sender);
          }
        }
      }
    
      function presaleEmoji(uint256 numberOfTokens) external payable {
        require(presaleIsActive, "Presale is not active");
        require(_presaleList[msg.sender], "You are not on the Presale List");
        require(
          totalSupply() + numberOfTokens <= MAX_TOKENS,
          "Purchase would exceed max supply of token"
        );
        require(
          numberOfTokens > 0 && numberOfTokens <= presaleMaxMint,
          "Cannot purchase this many tokens"
        );
        require(
          _presaleListClaimed[msg.sender] + numberOfTokens <= presaleMaxMint,
          "Purchase exceeds max allowed"
        );
        require(
          msg.value >= tokenPrice * numberOfTokens,
          "Ether value sent is not correct"
        );
    
        for (uint256 i = 0; i < numberOfTokens; i++) {
          uint256 id = totalSupply() + 1;
          if (totalSupply() < MAX_TOKENS) {
            _presaleListClaimed[msg.sender] += 1;
            _safeMint(msg.sender, id);
            emit EmojiMinted(id, msg.sender);
          }
        }
      }
    
      function addToPresaleList(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
          require(addresses[i] != address(0), "Can't add the null address");
    
          _presaleList[addresses[i]] = true;
        }
      }
    
    function removeFromPresaleList(address[] calldata addresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Can't add the null address");
    
            _presaleList[addresses[i]] = false;
        }
    }
    
    
    function onPreSaleList(address addr) external view returns (bool) {
        return _presaleList[addr];
    }
    
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(tokenId),"ERC721Metadata: URI query for nonexistent token");
    
        string memory currentBaseURI = _baseURI();
    
        if (isRevealed == false) {
          return "ipfs://QmYGAp3Gz1m5UmFhV4PVRRPYE3HL1AmCwEKFPxng498vfb/hidden.json";
        }
    
        return
          bytes(currentBaseURI).length > 0
            ? string(abi.encodePacked(currentBaseURI, tokenId, ".json"))
            : "";
            
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}