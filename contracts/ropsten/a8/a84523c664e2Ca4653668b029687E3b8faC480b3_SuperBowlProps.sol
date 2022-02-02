//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Base64.sol";

contract SuperBowlProps is ERC721, Ownable {    
    using SafeMath for uint256;
    using Counters for Counters.Counter; 

    uint256 public PROPPRICE = 10000000000000000;
    uint public constant MAXPROPPURCHASE = 10;

    bool public saleIsActive = false;

    string public SUPERBOWLMETA = "https://gateway.pinata.cloud/ipfs/QmYeGGSBciV3FS3tmL6jLLBTgepr67gBTxiUc2sHKUVmyf";

    string[] private cin = [
        "0",
        "1",
        "2",
        "3",
        "4",
        "5",
        "6",
        "7",
        "8",
        "9"
    ];

    string[] private lar = [
        "0",
        "1",
        "2",
        "3",
        "4",
        "5",
        "6",
        "7",
        "8",
        "9"
    ];

    // set to my test net address for now
    address t1 = 0x70BFA29ACA546E6cFDc7a8F7Aebf07d9a545Cf52;

    Counters.Counter private _tokenIds;    
    constructor() public ERC721("Super Bowl Props", "SUPERBOWLPROPS") {}    

    function withdraw() public onlyOwner {
        require(payable(t1).send(address(this).balance));
    }

    function setPropPrice(uint256 NewPropPrice) public onlyOwner {
        PROPPRICE = NewPropPrice;
    }

    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }

    function tokensOfOwner(address _owner) external view returns(uint256[] memory ) {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 index;
            for (index = 0; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }
            return result;
        }
    }

    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input)));
    }

    function getCin(uint256 tokenId) public view returns (string memory) {
        return pluck(tokenId, "CIN", cin);
    }

    function getLar(uint256 tokenId) public view returns (string memory) {
        return pluck(tokenId, "LAR", lar);
    }

    function pluck(uint256 tokenId, string memory keyPrefix, string[] memory sourceArray) internal view returns (string memory) {
        uint256 rand = random(string(abi.encodePacked(keyPrefix, toString(tokenId))));
        string memory output = sourceArray[rand % sourceArray.length];
        output = string(abi.encodePacked(output));
        return output;
    }

    function tokenURI(uint256 tokenId) override public view returns (string memory) {
        string[17] memory parts;
        parts[0] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"> <style>.base {fill: RGB(251,79,19);font-family: san-serif;font-size: 14px;}.number {font-size: 72px;font-weight: bold;font-family: san-serif;fill: RGB(218,165,32);}</style><rect width="100%" height="100%" fill=RGB(250,100,0) /><polygon stroke=RGB(218,165,32) fill=RGB(0,0,19) /><polygon stroke=RGB(218,165,32) fill=RGB(0,53,148) points="0 0, 350 0, 350 350" /><text x="245" y="175" class="number">';

        parts[1] = getCin(tokenId);

        parts[2] = '</text><text x="50" y="250" class="base">CIN</text><text x="50" y="175" class="number">';

        parts[3] = getLar(tokenId);

        parts[4] = '</text><text x="145" y="175" class="number">-</text><image href=https://teamcolorcodes.com/wp-content/uploads/2014/05/Los-Angeles-Rams-Logo-PNG.png height="100" width="100" x="200" y="15" /><image href=https://teamcolorcodes.com/wp-content/uploads/2017/05/Cincinnati-Bengals-Logo-PNG.png height="80" width="100" x="15" y="225" /></svg>';

        string memory output = string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4]));
        
        string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "Super Bowl Squares 2022 #', toString(tokenId), '", "description": "Super Bowl Squares?!", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(output)), '"}'))));
        output = string(abi.encodePacked('data:application/json;base64,', json));

        return output;
    }

    function claim(uint numberOfTokens) public payable {
        require(saleIsActive, "Sale must be active to mint a a prop");
        require(numberOfTokens > 0 && numberOfTokens <= MAXPROPPURCHASE, "You can only mint 5 tokens at a time");
        require(msg.value >= PROPPRICE.mul(numberOfTokens), "Ether value sent is not correct");
        for(uint i = 0; i < numberOfTokens; i++) {
            _tokenIds.increment(); 
            uint256 newItemId = _tokenIds.current(); 
            _mint(msg.sender, newItemId);
        }
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
    



}