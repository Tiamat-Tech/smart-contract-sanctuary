// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

//import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
//import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "hardhat/console.sol";
import '@0xsequence/erc-1155/contracts/tokens/ERC1155PackedBalance/ERC1155MintBurnPackedBalance.sol';

/// @custom:security-contact [email protected]
//contract BetPlacersClub is Initializable, ERC1155Upgradeable, OwnableUpgradeable, PausableUpgradeable, ERC1155SupplyUpgradeable, UUPSUpgradeable {
contract BetPlacersClub is Initializable, ERC1155MintBurnPackedBalance, ContextUpgradeable, OwnableUpgradeable, PausableUpgradeable,UUPSUpgradeable {
// , ContextUpgradeable, ERC165Upgradeable, OwnableUpgradeable, PausableUpgradeable, ERC1155SupplyUpgradeable, UUPSUpgradeable {

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        totalSupply = 0;
        maxItems = 10000;
        baseTokenURI = "https://drop.betplacers.club/BETPCLUB/unrev/";
        //__ERC1155_init(baseTokenURI);
        __Ownable_init();
        __Pausable_init();
        //__ERC1155Supply_init();
        __UUPSUpgradeable_init();
        transferOwnership(msg.sender);
    }

    string public constant name = "Bet Placers Club";
    string public constant symbol = "BETPCLUB";
    string private baseTokenURI ;

    uint256 public totalSupply;
    uint maxItems;

    // we only provide nft's
    uint8 public constant decimals = 0;

    function setBaseURI(string memory newuri) external onlyOwner {
        baseTokenURI = newuri;
    }

    function uri(uint256 tokenId) external view virtual returns (string memory) {
        return string(abi.encodePacked(baseTokenURI, Strings.toString(tokenId), ".json"));
    }

    // todo: consider duplicating this logic to mintmany so that we don't need public functions
    // (because public functions use more gas than external functions)
    function mint(address to, uint256 id, bytes memory data)
        public
        onlyOwner
    {
        console.log("minting one [to,id]", to, id);
        _mint(to, id, 1, data);
        totalSupply+=1;
        console.log("updated [totalSupply]", totalSupply);
    }

    function mintMany(address to, uint256 id, bytes memory data, uint count)
        external
        onlyOwner
    {
        console.log('mintMany: [to , from id, to id]',to, id, id+count);
        for(uint i=id;i<id+count;i++){
          mint(to, i, data);
        }
    }

    // todo: consider duplicating this logic to mintmany so that we don't need public functions
    // (because public functions use more gas than external functions)
    function mintBatch(address to, uint256[] memory ids,  bytes memory data)
        public
        onlyOwner
    {
        uint256[] memory amounts = new uint256[](ids.length);
        for(uint i=0; i<ids.length; i++) {
          console.log("preparing batch mint adding [to, id]", to, ids[i]);
          amounts[i] = 1;
        }
        console.log("minting batch [to, ids length, amounts length]", to, ids.length, amounts.length);
        _batchMint(to, ids, amounts, data);
        totalSupply+=ids.length;
        console.log("updated [totalSupply]", totalSupply);
    }

    function twoDimensionalMintBatch(address[] memory to, uint256[][] memory ids, bytes memory data)
        external
        onlyOwner
    {
        for(uint i=0;i<to.length;i++){
          console.log("array length i,length",i,ids[i].length);
          if (ids[i].length == 1){
            mint(to[i], ids[i][0], data);
          } else { 
            mintBatch(to[i], ids[i], data);
          }
        }
    }

    // For opensea auto detection of collection
    function contractURI() external view returns (string memory) {
        return "https://drop.betplacers.club/BETPCLUB/openseameta.testnet.json";
    }

    // do not copy these lines to scaffold-eth

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /* this is taken from 
       import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
       */

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;

}

// import '@0xsequence/erc-1155/contracts/tokens/ERC1155PackedBalance/ERC1155MintBurnPackedBalance.sol';
// import '@0xsequence/erc-1155/contracts/utils/Ownable.sol';

//contract BetPlacersERC1155 is ERC1155MintBurnPackedBalance,  ERC1155Metadata, Ownable  {

//    string public symbol;


//    uint256 public totalSupply = 0;
//    uint maxItems = 10000;

//    // we only provide nft's
//    uint8 public constant decimals = 0;

//    // set the initial name and base URI
//    constructor() ERC1155Metadata("Bet Placers Club","https://drop.betplacers.club/BETPCLUB/")
//    {
//      symbol = "BETPCLUB";
//    }

//    function mint(address _to, uint256 _id, bytes memory _data) public onlyOwner {
//       console.log('minting to address',_to);
//       _mint(_to, _id, 1, _data);
//      totalSupply += 1;
//    }

//    function mintMany(address _to, uint256 _id, bytes memory _data, uint _maxMint) public onlyOwner {
//       console.log('minting to address',_to);
//       for(uint i=1;i<_maxMint;i++){
//           _mint(_to, i, 1, _data);
//           totalSupply += 1;
//       }
//    }

//    function mintBatch(address _to, uint256[] memory _ids, uint256[] memory _amounts, bytes memory _data, uint _maxMint) public onlyOwner {
//       // uint256[] memory ids;
//       // uint256[] memory amounts;
//       // amounts[0] = 1;
//       // amounts[1] = 1;
//       // for (uint i=0;i<_maxMint; i+=2) {
//         //console.log("_batchMint",i);
//         // ids[i]=i;
//         // ids[i]=i+1;
//         // _batchMint(_to, _ids, _amounts, _data);
//          // _mint(_to, i, 1, "");
//       // }
//       console.log('batch minting to address',_to);
//      _batchMint(_to, _ids, _amounts, _data);
//      // todo fix this
//      totalSupply += _ids.length;
//     }

//  function setBaseTokenURI(string memory __baseTokenURI) public onlyOwner {
//      baseURI = __baseTokenURI;
//  }

//  function supportsInterface(bytes4 _interfaceID) public override(ERC1155PackedBalance, ERC1155Metadata) virtual pure returns (bool) {
//    if (_interfaceID == type(IERC1155).interfaceId) {
//      return true;
//    }
//    return super.supportsInterface(_interfaceID);
//  }
//}