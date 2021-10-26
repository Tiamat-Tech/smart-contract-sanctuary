// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
//import "@openzeppelin/contracts/utils/Counters.sol";

/// [MIT License]
/// @title Base64
/// @notice Provides a function for encoding some bytes in base64
/// @author Brecht Devos <[email protected]>
library Base64 {
    bytes internal constant TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /// @notice Encodes some bytes to the base64 representation
    function encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return "";

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((len + 2) / 3);

        // Add some extra buffer at the end
        bytes memory result = new bytes(encodedLen + 32);

        bytes memory table = TABLE;

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let i := 0
            } lt(i, len) {

            } {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)

                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(input, 0x3F))), 0xFF))
                out := shl(224, out)

                mstore(resultPtr, out)

                resultPtr := add(resultPtr, 4)
            }

            switch mod(len, 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }

            mstore(result, encodedLen)
        }

        return string(result);
    }
}

contract WhatTheCommit is
    Ownable,
    ERC721Enumerable,
    ERC721Burnable,
    ERC721Pausable
{
    uint private _tokenIds;
    uint private _tokenIdsOwner;
    
    address public constant DEVELOPER_ADDRESS = 0xC006562812F7Adf75FA0aDCE5f02C33E070e0ada;
    
    uint public MAX_TOKENS = 10000;
    uint public TOKENS_PRESERVED_FOR_OWNER = 2;
    
    uint public MIN_PRICE = 0.01 ether;
    uint public MAX_PRICE = 0.03 ether;
    
    uint public TOKEN_LOCK_TIMESTAMP = 1666610114;
    
    bool public SALE_STARTED = false;

    mapping (uint => uint) public tokenLockedFromTimestamp;
    
    string[] private commitMessages = [
        "- Temporary commit.",
        "Get that shit outta my master.",
        "[skip ci] I'll fix the build monday",
        "A fix I believe, not like I tested or anything",
        "A full commitment's what I'm thinking of",
        "A long time ago, in a galaxy far far away..."
    ];

    constructor() ERC721("WhatTheCommit", "WTC") {
        _tokenIdsOwner = MAX_TOKENS - TOKENS_PRESERVED_FOR_OWNER; // counter for public should start before owner count
    }
    
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
        require(from != owner() || tokenLockedFromTimestamp[tokenId] <= block.timestamp, "WhatTheCommit: Token locked");
        
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function ownerMint(uint256 numTokens) public onlyOwner {
        require(_tokenIdsOwner + numTokens < TOKENS_PRESERVED_FOR_OWNER, "Owner has not enough supply left");
        
        for (uint i = 0; i < numTokens; i++){
            tokenLockedFromTimestamp[_tokenIds] = TOKEN_LOCK_TIMESTAMP;
            
            _mint(msg.sender, _tokenIdsOwner);
            _tokenIdsOwner += 1;
        }
    }

    function mint(uint256 numTokens) public payable {
        require(SALE_STARTED == true, "Sale hasn't started yet");
        require(totalSupply() < MAX_TOKENS, "Sale has already ended");
      
        require(_tokenIds + numTokens <= MAX_TOKENS, "Not enough tokens left");
        
        require(MIN_PRICE * numTokens <= msg.value && MAX_PRICE * numTokens >= msg.value, "Ether value sent is not correct");
        
        for (uint i = 0; i < numTokens; i++){
            _mint(msg.sender, _tokenIds);
            _tokenIds += 1;
        }
    }
    
    function startSale() public onlyOwner {
        SALE_STARTED = true;
    }
    
    function pauseSale() public onlyOwner {
        SALE_STARTED = false;
    }
    
    function getCommitMessage(uint256 tokenId) public view returns (string memory) {
        return pluck(tokenId, "Commit Message", commitMessages);
    }
    
    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input)));
    }
    
    function pluck(uint256 tokenId, string memory keyPrefix, string[] memory sourceArray) internal pure returns (string memory) {
        uint256 rand = random(string(abi.encodePacked(keyPrefix, toString(tokenId))));

        return sourceArray[rand % sourceArray.length];
    }

    function tokenURI(uint256 tokenId) override public view returns (string memory) {
        string[3] memory parts;
        parts[0] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="20" class="base">';

        parts[1] = getCommitMessage(tokenId);

        parts[2] = '</text></svg>';

        string memory output = string(abi.encodePacked(parts[0], parts[1], parts[2]));
        
        string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "What the commit #', toString(tokenId), '", "description": "What the commit is a NFT project about random, sometimes hilarious, commit messages on the blockchain.", "attributes": [{"trait_type":"Commit Message","value":"', parts[1], '"}],"image": "data:image/svg+xml;base64,', Base64.encode(bytes(output)), '"}'))));
        output = string(abi.encodePacked('data:application/json;base64,', json));

        return output;
    }
    
    function toString(uint256 value) internal pure returns (string memory) {
    // Inspired by OraclizeAPI's implementation - MIT license
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
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}