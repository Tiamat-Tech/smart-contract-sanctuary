pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Unique is ERC721URIStorage, ERC721Enumerable{

    using Counters for Counters.Counter;
    uint256 constant public priceTier1 = 0.001 ether;
    uint256 constant public priceTier2 = 0.01 ether;
    uint256 constant public capTier1 = 100;
    uint256 constant public capTier2 = 200;
    uint256 public start;
    Counters.Counter private _tokenIds;
    // tier should be 0x1 & 0x2 ( optimisation )
    mapping (uint256 => uint256) tokenTiers;
    mapping (address => Counters.Counter) addressPurchases;
    error BeforeMintingStarted(string message);
    error InvalidTierProvided(string message);
    error InsufficientBalance(string message);
    error TokensPerAddressCapReached(string message);
    event Token(uint256 tokenId);
    event TierProvided(uint256 timeUnit);
    
    constructor(uint256 _start) public ERC721("UniqueAsset", "UNA"){
        start = _start;
    }
    // tier should be 0x1 & 0x2 ( optimisation )
    function mint(address recipient, uint256 tier, string memory metadata) payable public returns (uint256){
        if(block.timestamp < start){
            revert BeforeMintingStarted({message: 'minting has not started yet'});
        }
        // if(tier !=1 || tier !=2){
        //     emit TierProvided(tier);
        //     revert InvalidTierProvided({message: 'invalid tier provided'});
        // }
        if(msg.value != getTierPrice(tier)){
            revert InsufficientBalance({message: '< price'});
        }
        if(addressPurchases[recipient].current() >= 4){
            revert TokensPerAddressCapReached({message: 'maximum 5 nfts per address'});
        }
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _safeMint(recipient, newItemId);
        _setTokenURI(newItemId, metadata);
        addressPurchases[recipient].increment();
        tokenTiers[newItemId] = tier;
        return newItemId;
    }
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override (ERC721, ERC721Enumerable){
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override (ERC721, ERC721Enumerable) returns (bool){
        return super.supportsInterface(interfaceId);
    }
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory){
        return super.tokenURI(tokenId);
    }
    function getTierPrice(uint256 tier) internal pure returns (uint256){
        if(tier == 1){
            return priceTier1;
        }
        else return priceTier2;
    }
    //
    // function get_tier_erc20_value(uint256 tier) internal pure returns (uin256){

    // }
    function calculateValue(address owner) public returns (uint256){
        uint256 value;
        uint256 limit = balanceOf(owner);
        for(uint256 index = 0; index < limit; start++){
            uint256 tokenId = tokenOfOwnerByIndex(owner, index);
            value+=getTierPrice(tokenTiers[tokenId]);
        }
        return value;
    }
    function test() public returns (uint256){
        return 1;
    }
}