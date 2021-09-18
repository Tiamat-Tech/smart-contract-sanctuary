// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import { ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


/*
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
*/
import {Base64} from "./Base64.sol";
import {AConstants} from "./AConstants.sol";


/**
 * @title ArbiLoot
 * @author hermitthekrab

 * @notice ArbiLoot. Loot on Arbitrum.
 */
contract ArbiLoot is ERC721Enumerable, Ownable {
    uint public mintPrice = 27000000000000000;
    uint private publicMintedAmount = 0;
    uint private ownerMintedAmount = 0;

    constructor(string memory name, string memory symbol) ERC721("ArbiLoot", "ALOOT") Ownable() {}

  function random(
    string memory input
  )
    internal
    pure
    returns (uint256)
  {
    return uint256(keccak256(abi.encodePacked(input)));
  }

  function getWeapon(
    uint256 tokenId
  )
    public
    view
    returns (string memory)
  {
    return pluck(tokenId, AConstants.ListName.WEAPON);
  }

  function getChest(
    uint256 tokenId
  )
    public
    view
    returns (string memory)
  {
    return pluck(tokenId, AConstants.ListName.CHEST);
  }

  function getHead(
    uint256 tokenId
  )
    public
    view
    returns (string memory)
  {
    return pluck(tokenId, AConstants.ListName.HEAD);
  }

  function getWaist(
    uint256 tokenId
  )
    public
    view
    returns (string memory)
  {
    return pluck(tokenId, AConstants.ListName.WAIST);
  }

  function getFoot(
    uint256 tokenId
  )
    public
    view
    returns (string memory)
  {
    return pluck(tokenId, AConstants.ListName.FOOT);
  }

  function getHand(
    uint256 tokenId
  )
    public
    view
    returns (string memory)
  {
    return pluck(tokenId, AConstants.ListName.HAND);
  }

  function getNeck(
    uint256 tokenId
  )
    public
    view
    returns (string memory)
  {
    return pluck(tokenId, AConstants.ListName.NECK);
  }

  function getRing(
    uint256 tokenId
  )
    public
    view
    returns (string memory)
  {
    return pluck(tokenId, AConstants.ListName.RING);
  }

  function pluck(
    uint256 tokenId,
    AConstants.ListName keyPrefix
  )
    internal
    view
    returns (string memory)
  {

    // On-chain randomness.
    string memory inputForRandomness = string(abi.encodePacked(
      keyPrefix,
      tokenId, // Note: No need to use toString() here.
      "0xLOOT"
    ));
    uint256 rand = random(inputForRandomness);

    // Determine the item name based on the randomly generated number.
    string memory output = AConstants.getItem(rand, keyPrefix);
    uint256 greatness = rand % 21;
    if (greatness > 14) {
      output = string(abi.encodePacked(output, " ", AConstants.getItem(rand, AConstants.ListName.SUFFIX)));
    }
    if (greatness >= 19) {
      string[2] memory name;
      name[0] = AConstants.getItem(rand, AConstants.ListName.NAME_PREFIX);
      name[1] = AConstants.getItem(rand, AConstants.ListName.NAME_SUFFIX);
      if (greatness == 19) {
        output = string(abi.encodePacked('"', name[0], ' ', name[1], '" ', output));
      } else {
        output = string(abi.encodePacked('"', name[0], ' ', name[1], '" ', output, " +1"));
      }
    }
    return output;
  }

    function publicMinted() public view returns (uint256 ) {
        return publicMintedAmount;

    }
    function tokenURI(uint256 tokenId) override public view returns (string memory) {
        string[17] memory parts;
        parts[0] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="20" class="base">';

        parts[1] = getWeapon(tokenId);

        parts[2] = '</text><text x="10" y="40" class="base">';

        parts[3] = getChest(tokenId);

        parts[4] = '</text><text x="10" y="60" class="base">';

        parts[5] = getHead(tokenId);

        parts[6] = '</text><text x="10" y="80" class="base">';

        parts[7] = getWaist(tokenId);

        parts[8] = '</text><text x="10" y="100" class="base">';

        parts[9] = getFoot(tokenId);

        parts[10] = '</text><text x="10" y="120" class="base">';

        parts[11] = getHand(tokenId);

        parts[12] = '</text><text x="10" y="140" class="base">';

        parts[13] = getNeck(tokenId);

        parts[14] = '</text><text x="10" y="160" class="base">';

        parts[15] = getRing(tokenId);

        parts[16] = '</text></svg>';

        string memory output = string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7], parts[8]));
        output = string(abi.encodePacked(output, parts[9], parts[10], parts[11], parts[12], parts[13], parts[14], parts[15], parts[16]));

        string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "Bag #', toString(tokenId), '", "description": "Loot is randomized adventurer gear generated and stored on chain. Stats, images, and other functionality are intentionally omitted for others to interpret. Feel free to use Loot in any way you want.", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(output)), '"}'))));
        output = string(abi.encodePacked('data:application/json;base64,', json));

        return output;
    }

    function setMintPrice(uint mintPrice_) external onlyOwner {
        mintPrice = mintPrice_;
    }

    function claim(uint tokenAmount) public payable {
        require(msg.value >= mintPrice * tokenAmount, "msg.value incorrect");
        require(tokenAmount <= 10, "max 10");

        for (uint i = 0; i < tokenAmount; i++) {
            uint tokenId = totalSupply() + 1;
            require(tokenId > 0 && tokenId < 7001, "invalid token");

            publicMintedAmount += 1;
            require(publicMintedAmount < 7000, "no more mint");

            _safeMint(_msgSender(), tokenId);
        }
    }

    // Only for giveaways
    function ownerClaim(uint tokenAmount) public onlyOwner {
        for (uint i = 0; i < tokenAmount; i++) {
            uint tokenId = totalSupply() + 1;
            require(tokenId > 7000 && tokenId < 7778, "ID invalid");

            ownerMintedAmount += 1;
            require(ownerMintedAmount < 777, "no more mint");

            _safeMint(owner(), tokenId);
        }
    }

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;

        payable(msg.sender).transfer(balance);
    }

    function toString(uint256 value) internal pure returns (string memory) {

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
}