// SPDX-License-Identifier: GPL

// NFT Labs -- https://highlight.so

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

library State {

    using EnumerableSet for EnumerableSet.UintSet;

    /// @notice Represents an address' ownership of a particular token (ERC1155 token) with a unique # mint number.
    struct Token {
        address owner;
        address creator;
        string URI;

        uint tokenID;
        uint mintNumber;  
        uint rarity;

        uint blockOfPurchase;
    }

    /// @notice Represents the total state of a particular token. 
    struct Content {
        address creator;
        string URI;
        uint tokenID;

        // Mint number => token object
        mapping(uint => Token) token;
        // Address => Mint numbers of this token owned.
        mapping(address => EnumerableSet.UintSet) mintNumbersOwned;
        
        uint nextMintNumber;
    }

    function onTokenUpload (
        Content storage self,
        uint _tokenID,
        string calldata _URI,
        address _creator
    ) public {

        self.creator = _creator;
        self.URI = _URI;
        self.tokenID = _tokenID;
    }

    function onTokenMint(
        Content storage self,
        address _creator,
        address _to,
        uint _tokenID,
        uint rarity
    ) public returns (uint mintNumber) {

        self.nextMintNumber += 1;
        mintNumber = self.nextMintNumber;

        Token memory token;

        // Immutable
        token.creator = _creator;
        token.tokenID = _tokenID;
        token.mintNumber = mintNumber;
        token.URI = self.URI;
        token.rarity = rarity;

        // Variables that can be updated
        token.owner = _to;
        token.blockOfPurchase = block.number;

        self.token[mintNumber] = token;
        EnumerableSet.add(self.mintNumbersOwned[_to], mintNumber);
    }

    function onTokenTransfer(
        Content storage self,
        address _from,
        address _to,
        uint _mintNumber
    ) public {

        EnumerableSet.remove(self.mintNumbersOwned[_from], _mintNumber);
        EnumerableSet.add(self.mintNumbersOwned[_to], _mintNumber);

        Token memory token = self.token[_mintNumber];

        token.owner = _to;
        token.blockOfPurchase = block.number;
        
        self.token[_mintNumber] = token;
    }
}