/**
 *Submitted for verification at Etherscan.io on 2022-01-27
*/

// File: contracts/ITraits.sol


pragma solidity ^0.8.2;

interface ITraits {
  function tokenURI(uint256 tokenId) external view returns (string memory);
}

// File: contracts/IArtist.sol


pragma solidity ^0.8.2;

interface IArtist {

  struct Person {
    uint8 background;
    uint8 body;
    uint8 eyes;
    uint8 teeth;
    uint8 garment;
    uint8 chain;
    uint8 face;
    uint8 ear;
    uint8 head;
  }

  function addMinter(address[] memory _minters) external;
  function getTokenTraits(uint256 tokenId) external view returns (Person memory);
}

// File: @openzeppelin/contracts/utils/Strings.sol


// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}

// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: contracts/Traits.sol


pragma solidity ^0.8.2;





contract Traits is ITraits, Ownable {
  using Strings for uint256;

  struct Trait {
    string name;
    string cid;
  }

  IArtist public artist;
  uint16 dimensions;

  constructor() {
    dimensions = 1024;
  }

  string[9] _traitTypes = [
    "background",
    "body",
    "eyes",
    "teeth",
    "garment",
    "chain",
    "face",
    "ear",
    "head"
  ];

  mapping(uint8 => mapping(uint8 => Trait)) public traitData;

  function initialize(address _nftContract) external onlyOwner {
    artist = IArtist(_nftContract);
  }

  /* contract owner to upload names and images of each trait as base64 encoded PNGs */
  function uploadTraits(uint8 traitType, uint8[] calldata traitIds, Trait[] calldata traits) external onlyOwner {
    require(traitIds.length == traits.length, "Ids should match the number of traits");
    for (uint x = 0; x < traits.length; x++) {
      traitData[traitType][traitIds[x]] = Trait(
        traits[x].name,
        traits[x].cid
      );
    }
  }

  /* generates a data uri for the source of an image element */
  function drawTrait(Trait memory trait) internal view returns (string memory) {
    return string(abi.encodePacked(
      '<image x="0" y="0" width="',
      Strings.toString(dimensions),
      '" height="',
      Strings.toString(dimensions),
      '" image-rendering="pixelated" preserveAspectRatio="xMidyMid" xlink:href="https://ipfs.io/ipfs/', 
      trait.cid,
      '" />'  
    ));
  }

  /* generates a SVG file from the layered PNGs */
  function drawSVG(uint256 tokenId) public view returns (string memory) {
    IArtist.Person memory a = artist.getTokenTraits(tokenId);
    string memory svgString = string(abi.encodePacked(
      drawTrait(traitData[0][a.background]),
      drawTrait(traitData[1][a.body]),
      drawTrait(traitData[2][a.eyes]),
      drawTrait(traitData[3][a.teeth]),
      drawTrait(traitData[4][a.garment]),
      drawTrait(traitData[5][a.chain]),
      drawTrait(traitData[6][a.face]),
      drawTrait(traitData[7][a.ear]),
      drawTrait(traitData[8][a.head])
    ));

    return string(abi.encodePacked(
      '<svg id="artist" width="100%" height="100%" version="1.1" viewBox="0 0 ',
      Strings.toString(dimensions),
      ' ',
      Strings.toString(dimensions),
      '" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">',
      svgString,
      "</svg>"
    ));
  }

  /* generates an attribute according to the OpenSea Metadata standard */
  function attributeForTypeAndValue(string memory traitType, string memory value) internal pure returns (string memory) {
    return string(abi.encodePacked(
      '{"trait_type":"',
      traitType,
      '","value":"',
      value,
      '"}'
    ));
  }

  /* compiles a collection of attributes for according to the OpenSea Metadata standard */
  function compileAttributes(uint256 tokenId) public view returns (string memory) {
    IArtist.Person memory a = artist.getTokenTraits(tokenId);
    string memory traits = string(abi.encodePacked(
      '[',
      attributeForTypeAndValue(_traitTypes[0], traitData[0][a.background].name),
      attributeForTypeAndValue(_traitTypes[1], traitData[1][a.body].name), ',',
      attributeForTypeAndValue(_traitTypes[2], traitData[2][a.eyes].name), ',',
      attributeForTypeAndValue(_traitTypes[3], traitData[3][a.teeth].name), ',',
      attributeForTypeAndValue(_traitTypes[4], traitData[4][a.garment].name), ',',
      attributeForTypeAndValue(_traitTypes[5], traitData[5][a.chain].name), ',',
      attributeForTypeAndValue(_traitTypes[6], traitData[6][a.face].name), ',',
      attributeForTypeAndValue(_traitTypes[7], traitData[7][a.ear].name), ',',
      attributeForTypeAndValue(_traitTypes[8], traitData[8][a.head].name), ','
    ));

    return traits;
  }

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    string memory metadata = string(abi.encodePacked(
      '{"name": "',
      'Artist #',
      tokenId.toString(),
      '", "description": "Blah Blah Blah.", "image": "data:image/svg+xml;base64,',
      base64(bytes(drawSVG(tokenId))),
      '", "attributes":',
      compileAttributes(tokenId),
      "}"
    ));

    return string(abi.encodePacked(
      "data:application/json;base64,",
      base64(bytes(metadata))
    ));
  }

  /** BASE 64 - Written by Brech Devos */
  
  string internal constant TABLE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

  function base64(bytes memory data) internal pure returns (string memory) {
    if (data.length == 0) return '';
    
    // load the table into memory
    string memory table = TABLE;

    // multiply by 4/3 rounded up
    uint256 encodedLen = 4 * ((data.length + 2) / 3);

    // add some extra buffer at the end required for the writing
    string memory result = new string(encodedLen + 32);

    assembly {
      // set the actual output length
      mstore(result, encodedLen)
      
      // prepare the lookup table
      let tablePtr := add(table, 1)
      
      // input ptr
      let dataPtr := data
      let endPtr := add(dataPtr, mload(data))
      
      // result ptr, jump over length
      let resultPtr := add(result, 32)
      
      // run over the input, 3 bytes at a time
      for {} lt(dataPtr, endPtr) {}
      {
          dataPtr := add(dataPtr, 3)
          
          // read 3 bytes
          let input := mload(dataPtr)
          
          // write 4 characters
          mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(18, input), 0x3F)))))
          resultPtr := add(resultPtr, 1)
          mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(12, input), 0x3F)))))
          resultPtr := add(resultPtr, 1)
          mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr( 6, input), 0x3F)))))
          resultPtr := add(resultPtr, 1)
          mstore(resultPtr, shl(248, mload(add(tablePtr, and(        input,  0x3F)))))
          resultPtr := add(resultPtr, 1)
      }
      
      // padding with '='
      switch mod(mload(data), 3)
      case 1 { mstore(sub(resultPtr, 2), shl(240, 0x3d3d)) }
      case 2 { mstore(sub(resultPtr, 1), shl(248, 0x3d)) }
    }
    
    return result;
  }
}