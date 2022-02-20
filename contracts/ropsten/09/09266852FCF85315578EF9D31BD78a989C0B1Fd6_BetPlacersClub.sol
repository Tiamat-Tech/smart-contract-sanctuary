// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "hardhat/console.sol";

/// @custom:security-contact [email protected]
contract BetPlacersClub is Initializable, ERC1155Upgradeable, OwnableUpgradeable, PausableUpgradeable, ERC1155SupplyUpgradeable, UUPSUpgradeable {
    string public constant name = "Bet Placers Club";
    string public constant symbol = "BETPCLUB";
    string private baseTokenURI ;

    uint256 public totalSupply;
    uint maxItems;

    // we only provide nft's
    uint8 public constant decimals = 0;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        //setOwner(msg.sender);
        totalSupply = 0;
        maxItems =10000;
        baseTokenURI = "https://drop.betplacers.club/BETPCLUB/";
        __ERC1155_init(baseTokenURI);
        __Ownable_init();
        __Pausable_init();
        __ERC1155Supply_init();
        __UUPSUpgradeable_init();
        transferOwnership(msg.sender);
    }

  function setBaseURI(string memory newuri) public onlyOwner {
      baseTokenURI = newuri;
  }

    /**
   * @dev See {IERC1155MetadataURI-uri}.
   *
   * This implementation returns the same URI for *all* token types. It relies
   * on the token type ID substitution mechanism
   * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
   *
   * Clients calling this function must replace the `\{id\}` substring with the
   * actual token type ID.
   */
  function uri(uint256 tokenId) public view virtual override returns (string memory) {
      return string(abi.encodePacked(baseTokenURI, Strings.toString(tokenId), ".json"));
  }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address account, uint256 id, bytes memory data)
        public
        onlyOwner
    {
        _mint(account, id, 1, data);
        totalSupply+=1;
    }

    function mintMany(address account, uint256 id, bytes memory data, uint count)
        public
        onlyOwner
    {
      console.log('minting to address starting from id',account, id);
        for(uint i=id;i<count;i++){
            _mint(account, i, 1, data);
        totalSupply+=1;
        }
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data, uint count)
        public
        onlyOwner
    {
        _mintBatch(to, ids, amounts, data);
        totalSupply+=ids.length;
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override(ERC1155Upgradeable, ERC1155SupplyUpgradeable)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
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