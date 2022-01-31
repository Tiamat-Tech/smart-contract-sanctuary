pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./utils/VerifyIPFS.sol";

contract ERC721Minter is ERC721URIStorage, ERC721Enumerable, Ownable{

    using Counters for Counters.Counter;
    uint256 constant public priceTier1 = 0.001 ether;
    uint256 constant public erc20PriceTier1 = 1 ether;
    uint256 constant public capTier1 = 100;
    bytes metadata = "f310cf8976389b801ebd20aa8a818c375fee831d8f5b10f07e2cacd6db87e4b0";
    string currentMetadata = "https://ipfs.io/ipfs/QmehUeWdGzgn3vdb5fdCye2C1jtNsxhe7gHW94PKrJBGkP";
    event Result(string result);
    uint256 public start;
    // string[100] public metadata = ["https://ipfs.io/ipfs/QmehUeWdGzgn3vdb5fdCye2C1jtNsxhe7gHW94PKrJBGkP", "https://ipfs.io/ipfs/QmehUeWdGzgn3vdb5fdCye2C1jtNsxhe7gHW94PKrJBGkP", "https://ipfs.io/ipfs/QmehUeWdGzgn3vdb5fdCye2C1jtNsxhe7gHW94PKrJBGkP", "https://ipfs.io/ipfs/QmehUeWdGzgn3vdb5fdCye2C1jtNsxhe7gHW94PKrJBGkP", "https://ipfs.io/ipfs/QmehUeWdGzgn3vdb5fdCye2C1jtNsxhe7gHW94PKrJBGkP"];
    Counters.Counter private _tokenIds;
    // tier should be 0x1 & 0x2 ( optimisation )
    mapping (address => Counters.Counter) addressPurchases;
    error OwnerOnly(string message);
    error BeforeMintingStarted(string message);
    error InsufficientBalance(string message, uint256 price, uint256 provided);
    error TokensPerAddressCapReached(string message);
    event MetadataUpdated(uint256 index, string previous, string current);
    event Value(uint256 value);
    
    constructor(uint256 _start) public ERC721("UniqueAsset", "UNA"){
        start = _start;
    }
    // tier should be 0x1 & 0x2 ( optimisation )
    function mint(address recipient) payable public returns (uint256){
        if(block.timestamp < start){
            revert BeforeMintingStarted({message: '!started'});
        }
        // tier check
        // decrease capTier;
        if(msg.value < priceTier1){
            revert InsufficientBalance({message: '<price', price: priceTier1, provided: msg.value});
        }
        if(addressPurchases[recipient].current() >= 5){
            revert TokensPerAddressCapReached({message: 'maximum 5 nfts per address'});
        }
        emit Value(_tokenIds.current());
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        // should be ( at least something like this)
        // _setTokenURI(newItemId, metadata[newItemId-1]);
        _setTokenURI(newItemId, currentMetadata);
        addressPurchases[recipient].increment();
        return newItemId;
    }
    function mint(address recipient, uint256 amount) payable public returns (uint256){
        if(amount > 5){
            revert TokensPerAddressCapReached({message: 'maximum 5 nfts per address'});
        }
        if(msg.value < priceTier1 * amount){
            revert InsufficientBalance({message: '<price', price: priceTier1 * amount, provided: msg.value});
        }
        for(uint256 i = 0; i < amount; i++){
            mint(recipient);
        }
    }
    function fromBytesToString() public {
        bytes memory prefix = "0x1220";
        bytes memory withMultiHash = abi.encodePacked(prefix, metadata);
        string memory encoded = string(VerifyIPFS.toBase58(withMultiHash));
        emit Result(encoded);
    }
    // function editMetadata(uint256 index, string memory metadata) public {
    //     if(msg.sender != address(owner())){
    //         revert OwnerOnly({message: '!owner'});
    //     }
    //     string calldata previous = metadata[index];
    //     metadata[index] = metadata;
    //     emit MetadataUpdated(index, previous, metadata);
    // }
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
    function calculateERC20Value(address owner) public returns (uint256){
        uint256 limit = balanceOf(owner);
        uint256 value = limit * erc20PriceTier1;
        emit Value(value);
        return value;
    }
}