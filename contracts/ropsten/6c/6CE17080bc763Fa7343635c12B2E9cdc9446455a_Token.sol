//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";




    //                                                                     @@@@
    //                                                                   @@@@
    //                                                                 @@@@
    //                                                               @@@
    //                                                             @@@
    //                                                          @@@@
    //       @@@                                              @@@
    //     @@@@@@@@                                         @@@
    //     @@@@@@@@                                       @@@
    //        @@                                       @@@@
    //                                               @@@@
    //                                             @@@
    //                                           @@@
    //                                         @@@
    //                                      @@@@
    //                                    @@@
    //                                  @@@
    //                                @@@
    //                             @@@@
    //    @@@@@@@@@              @@@@
    //   @@@@@@@@@@@@@@       @@@@@
    //  @@@@@@@@@@@@@@@@@@  @@@@@
    //   @@@@@@@@@@@@@@@@@@@@@&
    //      @@@@@@@@@@@@@@@@


contract Token is ERC721, Ownable {
    using Strings for uint;
    uint _mintPrice = 100 ether;
    uint numTokens = 100;
    mapping(uint => address) public tokenToOwner;

    constructor() ERC721("Zero Gravity Country Club", "0gcc") {}

    function mint(uint _tokenId) public payable {
        require(tokenToOwner[_tokenId] == address(0), "Token is already owned");
        require(msg.value == _mintPrice, "Incorrect minting amount");
        require(_tokenId < numTokens, "Invalid token id");
        _mint(msg.sender, _tokenId);
    }

   function _baseURI() internal pure override returns (string memory) {
        return "ipfs://QmZ2YdeEwaB2uYk6XRVnJJELZU4gZqfKJiQmsLA2WgxnHS/";
    }

}