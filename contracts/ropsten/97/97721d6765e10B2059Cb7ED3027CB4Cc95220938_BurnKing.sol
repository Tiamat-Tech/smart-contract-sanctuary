// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";



contract BurnKing is ERC721Enumerable, Ownable {
    uint256 public constant SECONDS_IN_DAY = 86400;

    // Base URI
    string private _nftBaseURI;

    // pools limits
    uint256 public constant commonLimit = 10000000;
    uint256 public constant uncommonLimit = 2000000;
    uint256 public constant rareLimit = 100000;
    uint256 public constant epicLimit = 10000;
    uint256 public constant legendaryLimit = 300;
    uint256 public constant ultimateLimit = 20;
    uint256 public constant kingLimit = 1;

    // Royalty info
    address public royaltyAddress;
    uint256 public ROYALTY_SIZE = 2500; // 25%
    uint256 public ROYALTY_DEMONINATOR = 10000;

    mapping(uint256 => address) private _royaltyReceivers;

    mapping (address => uint256) private _lastBurnedByUser;

    mapping(uint256 => Pools) private _nftIdTypes;
    mapping(Pools => uint256) private _nftTypesCount;

   enum Pools {
       Common,
       UnCommon,
       Rare,
       Epic,
       Legendary,
       Ultimate,
       King
   }

   event BurnedEther(
       address indexed user,
       uint256 indexed amount,
       Pools indexed tokenType
   );
   
    event baseUriUpdated(
      string oldBaseUri,
      string newBaseUri
    );

     event tokenMintedFor(
      address mintedFor,
      uint256 tokenId
    );


    // Royalty public roaltyContract;



   constructor()ERC721("Burn Spot", "BSP"){
        
   }
    
    function getUserPool(uint256 amount) internal pure returns (Pools) {
    Pools pool;
    if (amount >= 10 && amount <= 1000) { pool = Pools.Common;}
    if (amount >= 1000 && amount <= 10000) { pool = Pools.UnCommon; }
    if (amount >= 10000 && amount<= 100000) { pool = Pools.Rare; }
    if (amount >= 100000 && amount <= 1000000) { pool = Pools.Epic; }
    if (amount >= 1000000 && amount <= 100000000) { pool = Pools.Legendary; }
    if (amount >= 100000000 && amount <= 1000000000) { pool = Pools.Ultimate; }
    if (amount > 1000000000) { pool = Pools.King; }
    return pool;
  }
    

    function burnTokens(uint256 burningAmount) external payable returns(bool){
       require(block.timestamp - _lastBurnedByUser[msg.sender] >= SECONDS_IN_DAY, "You can burn ethers once per day");
       require(msg.sender != address(0),'Can not be zero address');
       (bool sent, ) = address(0).call{value: msg.value}("");
       require(sent, "Failed to burn Tokens");
       Pools pool = getUserPool(burningAmount);
       emit BurnedEther(msg.sender, burningAmount, pool);
  
       if(burningAmount >= 10){
        mintFor(pool,msg.sender);
      }
      return sent;
    }

    function mintFor(Pools tokenType, address receiver) internal {
      require(
        tokenType == Pools.Common
        || tokenType == Pools.UnCommon
        || tokenType == Pools.Rare
        || tokenType == Pools.Epic
        || tokenType == Pools.Legendary
        || tokenType == Pools.Ultimate,
        "Unknown token type"
      );

      if (Pools(tokenType) == Pools.Common) require(_nftTypesCount[tokenType] + 1 <= commonLimit, "You tried to mint more than the max allowed");
      if (Pools(tokenType) == Pools.UnCommon) require(_nftTypesCount[tokenType] + 1 <= uncommonLimit, "You tried to mint more than the max allowed");
      if (Pools(tokenType) == Pools.Rare) require(_nftTypesCount[tokenType] + 1 <= rareLimit, "You tried to mint more than the max allowed");
      if (Pools(tokenType) == Pools.Epic) require(_nftTypesCount[tokenType] + 1 <= epicLimit, "You tried to mint more than the max allowed");
      if (Pools(tokenType) == Pools.Legendary) require(_nftTypesCount[tokenType] + 1 <= legendaryLimit, "You tried to mint more than the max allowed");
      if (Pools(tokenType) == Pools.Ultimate) require(_nftTypesCount[tokenType] + 1 <= ultimateLimit, "You tried to mint more than the max allowed");
      
      uint256 mintIndex = totalSupply();

      _nftIdTypes[mintIndex] = Pools(tokenType);
      _nftTypesCount[tokenType]++;

      _safeMint(receiver, mintIndex);

      emit tokenMintedFor(receiver, mintIndex);
    }



    function getTokenType(uint256 tokenId) external view returns (uint256) {
      require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
      return uint256(_nftIdTypes[tokenId]);
    }

    function etherLastBurned(address userAddress) external view returns (uint256) {
        return _lastBurnedByUser[userAddress];
    }

    function setBaseURI(string memory newBaseURI) public onlyOwner {
      string memory currentURI = _nftBaseURI;
      _nftBaseURI = newBaseURI;
      emit baseUriUpdated(currentURI, newBaseURI);
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
      require(_exists(_tokenId), "Token does not exist.");
      return string(abi.encodePacked(_baseURI(), Strings.toString(_tokenId)));
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return _nftBaseURI;
    }


    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view returns (address receiver, uint256 royaltyAmount) {
      uint256 amount = _salePrice * ROYALTY_SIZE / ROYALTY_DEMONINATOR;
      address royaltyReceiver = _royaltyReceivers[_tokenId] != address(0) ? _royaltyReceivers[_tokenId] : royaltyAddress;
      return (royaltyReceiver, amount);
    }


    function addRoyaltyReceiverForTokenId(address receiver, uint256 tokenId) public onlyOwner {
      _royaltyReceivers[tokenId] = receiver;
    }

}