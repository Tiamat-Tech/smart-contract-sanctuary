// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Dinovers is ERC721, ERC721Enumerable, Ownable {

    uint256 private _tokenIdCounter = 1;

    uint256 public constant SALE_PRICE_INCREMENT_PER_THOUSAND = 0.03 ether; // It will increase for every 1000 sales.
    uint256 public TOKEN_PRICE = 0.07 ether; // Mint dino price.
    uint256 public constant PRE_SALE_TOKEN_PRICE = 0.03 ether; // Pre-sale dino price.
    uint256 public constant MAX_TOKENS = 10000; // Mintable maximum dino count.
    uint256 public constant MAX_PURCHASE_PER_DINO_LOVER = 10; // Mintable maximum dino count per dino lover.
    uint256 public constant MAX_PURCHASE_PER_DINO_LOVER_AT_PRESALE = 2; // Mintable maximum dino count per dino lover at pre-sale.

    uint256 public claimedGiftCount = 0;

    uint256 public devReserve = 30; // Let us to mint dino. :)

    bool public isSaleActive = false; // We will active after.
    bool public isPreSaleActive = false; // It will active before pre-sale period.
    bool public isGiftActive = false; // It will active after pre-sale period.
    bool public isRevealed = false; // We will set visible after sold out all dinos.

    string public baseURI = ""; // We will set it after sold out all dinos.
    
    mapping(address => bool) private _presaleList; // We will grow up together but more love for first dino lovers.
    mapping(address => uint256) private _presaleListClaimed;
    mapping(address => bool) private _giftList; // If you are in here, so lucky... :)
    mapping(address => bool) private _claimedGiftList;

    event DinoMinted(uint256 tokenId, address owner);
    event DinoMintedAsGift(uint256 tokenId, address owner);
    event DinoMintedAsTeam(uint256 tokenId, address owner);
    event DinoTransfer(uint256 tokenId, address owner);

    constructor() ERC721("Dinovers", "DS") {}

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }
    
    function mintDino(uint256 amountOfTokens) external payable {
        require(isSaleActive, "Sale is not open.");
        require(amountOfTokens > 0, "Amount should bigger than zero.");
        require(
            (countOfDinos(msg.sender) + amountOfTokens) <= MAX_PURCHASE_PER_DINO_LOVER,
            string(abi.encodePacked("Amount should smaller than or equal to ", MAX_PURCHASE_PER_DINO_LOVER, "."))
        );
        require(totalSupply() + amountOfTokens + devReserve <= MAX_TOKENS, "No enough token for mint.");
        require(msg.value >= TOKEN_PRICE * amountOfTokens, "Not enough ether has been sent.");

        for (uint256 i = 0; i < amountOfTokens; i++) {
            uint256 id = _tokenIdCounter;
            if (totalSupply() < MAX_TOKENS) {
                _safeMint(msg.sender, id);
                _tokenIdCounter += 1;
                if(totalSupply() != 0 && (totalSupply() % 1000) == 0) {
                    TOKEN_PRICE += SALE_PRICE_INCREMENT_PER_THOUSAND;
                }
                emit DinoMinted(id, msg.sender);
            }
        }
    }

    function preSaleMintDino(uint256 amountOfTokens) external payable {
        require(isPreSaleActive, "Pre-sale is not open.");
        require(_presaleList[msg.sender], "You are not on the Presale List");
        require(amountOfTokens > 0, "Amount should bigger than zero.");
        require(
            (_presaleListClaimed[msg.sender] + amountOfTokens) <= MAX_PURCHASE_PER_DINO_LOVER_AT_PRESALE,
            string(abi.encodePacked("Amount should smaller than or equal to ", MAX_PURCHASE_PER_DINO_LOVER_AT_PRESALE, "."))
        );
        require(msg.value >= PRE_SALE_TOKEN_PRICE * amountOfTokens, "Not enough ether has been sent.");

        for (uint256 i = 0; i < amountOfTokens; i++) {
            uint256 id = _tokenIdCounter;
            if (totalSupply() < MAX_TOKENS) {
                _safeMint(msg.sender, id);
                _presaleListClaimed[msg.sender] += 1;
                _tokenIdCounter += 1;
                if(totalSupply() != 0 && totalSupply() != MAX_TOKENS && (totalSupply() % 1000) == 0) {
                    TOKEN_PRICE += SALE_PRICE_INCREMENT_PER_THOUSAND;
                }
                emit DinoMinted(id, msg.sender);
            }
        }
    }
    
    function reserveDinos(address _to, uint256 _reserveAmount) external onlyOwner {
        require(_reserveAmount > 0, "Amount should bigger than zero.");
        require(_reserveAmount <= devReserve,"Amount should smaller than or equal to developer team reserve amount.");
        for (uint256 i = 0; i < _reserveAmount; i++) {
            uint256 tokenId = _tokenIdCounter;
            _safeMint(_to, tokenId);
            _tokenIdCounter += 1;
        }
        devReserve = devReserve - _reserveAmount;
    }

    function transferFromOwner(address _to, uint256 amount) external onlyOwner{
        require(totalSupply() + amount + devReserve <= MAX_TOKENS, "Allowed amount exceeded.");
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _tokenIdCounter;
            _safeMint(_to, tokenId);
            _tokenIdCounter += 1;
            emit DinoTransfer(tokenId, _to);
        }
    }

    function claimGift() external {
        require(isGiftActive, "Pre-sale is not open.");
        require(_giftList[msg.sender], "You are not on the Gift List");
        require(_claimedGiftList[msg.sender] == false, "You are already claim your gift nft.");

        uint256 id = _tokenIdCounter;
        if (totalSupply() < MAX_TOKENS) {
            _safeMint(msg.sender, id);
            _claimedGiftList[msg.sender] = true;
            _tokenIdCounter += 1;
            emit DinoMintedAsGift(id, msg.sender);
        }
    }

    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    function toggleSaleState() external onlyOwner {
        isSaleActive = !isSaleActive;
    }

    function togglePreSaleState() external onlyOwner {
        isPreSaleActive = !isPreSaleActive;
    }

    function toggleGiftState() external onlyOwner {
        isGiftActive = !isGiftActive;
    }

    function toggleReveal() external onlyOwner {
        isRevealed = !isRevealed;
    }

    function dinosOfOwner(address _owner) public view returns (uint256[] memory)
    {
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

    function countOfDinos(address _owner) public view returns (uint256){
        uint256 tokenCount =  balanceOf(_owner);
        return tokenCount;
    }

    function addToPresaleList(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Address can not be null");
    
            _presaleList[addresses[i]] = true;
        }
    }
    
    function removeFromPresaleList(address[] calldata addresses) external onlyOwner
    {
        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Address can not be null");
    
            _presaleList[addresses[i]] = false;
        }
    }
    
    function addToGiftList(address[] calldata addresses) external onlyOwner {
        if(addresses.length <= 222) {
            for (uint256 i = 0; i < addresses.length; i++) {
                require(addresses[i] != address(0), "Address can not be null");
        
                _giftList[addresses[i]] = true;
            }
        }
    }
    
    function removeFromGiftList(address[] calldata addresses) external onlyOwner
    {
        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Address can not be null");
    
            _giftList[addresses[i]] = false;
        }
    }

    function onPreSaleList(address addr) external view returns (bool) {
        return _presaleList[addr];
    }
    
    function onGiftList(address addr) external view returns (bool) {
        return _giftList[addr];
    }

    function isGiftClaimed(address addr) external view returns (bool) {
        if (_giftList[addr]) {
            return _claimedGiftList[addr];
        }

        return false;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory)
    {
        require(_exists(tokenId),"ERC721Metadata: URI query for nonexistent token");
    
        string memory currentBaseURI = _baseURI();
    
        if (isRevealed == false) {
          return "ipfs://QmYGAp3Gz1m5UmFhV4PVRRPYE3HL1AmCwEKFPxng498vfb/hidden.json";
        }
    
        return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI, tokenId, ".json")) : "";
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}