// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC721.sol";
import "./ERC721Enumerable.sol";
import "./ERC721URIStorage.sol";
import "./Pausable.sol";
import "./Ownable.sol";
import "./ERC721Burnable.sol";


contract CodeTest_1 is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable, Ownable, ERC721Burnable {
    constructor() ERC721("CodeTest_1", "CT1") {}

    uint256 private tokenID = 0;
    
    struct NFTtrack{
        address nft_owner;
        uint256 nft_id;
        uint256 buy_time;
    }
    
    uint256 private revealThreeDays= 3 days;
    uint256 private revealTwelveHour = 12 hours;
    uint256 private set_token = 0;
    uint256 private randNumber = 0;
    uint256 private count = 0;
    uint256 private lastNFTBuy;
    uint256 private randTrait;
    uint256 private counterRand = 0 ;
    
    uint256 private speed_random;
    uint256 private weight_random;
    uint256 private power_random;
    
    uint256[] private mintedNFT;
    address private owner_of_token;
    
    mapping (uint256 => NFTtrack) private NFTtrackList;
    mapping (address => uint256) private listOfAdrress;
    mapping (address => bool) private ico;
    mapping (address => Listowner) private tokenIdowners;
    mapping (uint256 => traits) private idWithTraits;
    
    struct Listowner {
        address[] _tokenowners;
        uint[] _tokenownersIds;
    }
    
    struct traits {
        uint256 speed;
        uint256 weight;
        uint256 power;
    }
    
    
    modifier onlyico() {
        require(owner() == _msgSender() || ico[_msgSender()], "Ownable: caller is not the owner");
        _;
    }
  
    function add_ico(address _ico) public onlyOwner {
        ico[_ico] = true;
    }
    
    function remove_ico(address _ico) public onlyOwner {
        ico[_ico] = false;
    }
    
    function randomtraits() public returns(uint256 rand)
    {
        counterRand++;
        randTrait = uint256(keccak256(abi.encodePacked(
        block.timestamp + block.difficulty +
        ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (counterRand)) +
        block.gaslimit + 
        ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (counterRand + 20)) +
        block.number
        )));
        randTrait = randTrait % 200;
        if(randTrait > 20)
        {
            return randTrait;
        }
        else
        {
            return randTrait + 20 ;
        }
    }
    function safemint(address to, string memory metadata) public {
        require(tokenID < 666, "Strings: 666 nft is minted");
        require(listOfAdrress[to] < 31, "Strings: You can't mint");
        tokenID++;
        listOfAdrress[to] += 1; 
        mintedNFT.push(tokenID);
        traits memory traitInfo;
        speed_random = randomtraits();
        weight_random = randomtraits();
        power_random = randomtraits();
        traitInfo = traits({
              speed :  speed_random,
              weight : weight_random,
              power : power_random
        });
        idWithTraits[tokenID] = traitInfo;
        _safeMint(to, tokenID);
        _setTokenURI(tokenID, metadata);
    }
    
    function buy_nft(address to) public onlyico {
        randNumber = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
        randNumber = randNumber % (mintedNFT.length);
        _transfer(ownerOf(mintedNFT[randNumber]),  to , mintedNFT[randNumber]);
        tokenIdowners[to]._tokenownersIds.push( mintedNFT[randNumber]);
        count++;
        lastNFTBuy = block.timestamp;
        NFTtrack memory NFTtrackinfo;
        
        NFTtrackinfo = NFTtrack({
              nft_owner :  to,
              nft_id : mintedNFT[randNumber],
              buy_time : block.timestamp
        });
        
        
        NFTtrackList[mintedNFT[randNumber]] = NFTtrackinfo;
        mintedNFT[randNumber] = mintedNFT[mintedNFT.length - 1];
        delete mintedNFT[mintedNFT.length - 1];
        mintedNFT.pop();
    }
    
    
    function tokensOfOwner(address owner) public view virtual returns(uint[] memory){
        return tokenIdowners[owner]._tokenownersIds;
    }
    
    function traitOfowner(uint256 token_id) public view virtual returns(uint256 , uint256 ,uint256 ){
        return  (idWithTraits[token_id].speed , idWithTraits[token_id].weight ,idWithTraits[token_id].power);
    }
    
    
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)internal whenNotPaused override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
    
    function tokenURI(uint256 tokenId)public view override(ERC721, ERC721URIStorage) returns (string memory)
    {
        if(NFTtrackList[tokenId].buy_time + revealThreeDays <= block.timestamp ){
            return super.tokenURI(tokenId);
        }else{
            if( count >= 666 && lastNFTBuy + revealTwelveHour <= block.timestamp ){
                return super.tokenURI(tokenId); 
            }else{
                return "null";
            }
        }
    }
    
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
    function getToken(uint256 tokenId) public view virtual returns (address, string memory) {
        address owner = ownerOf(tokenId);
        string memory ipfs =  tokenURI(tokenId);
        return (owner, ipfs);
    }
}