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

    string[] private winner = [
        "Los Angeles Rams",
        "Cincinatti Bengals"
    ];

    string[] private mvp = [
        "Matthew Stafford",
        "Cooper Kupp",
        "Odell Beckham Jr",
        "Cam Akers",
        "Tyler Higbee",
        "Tyler Boyd",
        "Kendall Blanton",
        "CJ Uzomah",
        "Trey Hendrickson",
        "Evan Mcpherson",
        "Drew Sample",
        "Mike Hilton",
        "Greg Gaines",
        "Samaje Perine",
        "A'Shawn Robinson",
        "Trenton Irwin",
        "Mike Thomas",
        "Dj Reader",
        "Cameron Sample",
        "Ben Skowronek",
        "Brycen Hopkins",
        "Trent Taylor",
        "Vonn Bell",
        "Logan Wilson",
        "Chidobe Awuzie",
        "Trae Waynes",
        "Taylor Rapp",
        "Travin Howard",
        "Bobby Brown",
        "Joe Burrow",
        "Aaron Donald",
        "Ja'Marr Chase",
        "Joe Mixon",
        "Tee Higgins",
        "Von Miller",
        "Jalen Ramsey",
        "Van Jefferson",
        "Sony Michel",
        "Leonard Floyd",
        "Sam Hubbard",
        "Darrell Henderson",
        "Matt Gay",
        "Jalen Davis",
        "Eric Weddle",
        "Stanley Morgan Jr",
        "Mitchell Wilcox",
        "BJ Hill",
        "Brandon Powell",
        "Jake Funk",
        "Chris Evans",
        "Trayveon Williams",
        "Eli Apple",
        "Germaine Pratt",
        "Tre Flowers",
        "Troy Reeder",
        "Nick Scott",
        "Michael Hoecht",
        "Jessie Bates III"
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

    function getWinner(uint256 tokenId) public view returns (string memory) {
        return pluck(tokenId, "WINNER", winner);
    }

    function getMvp(uint256 tokenId) public view returns (string memory) {
        return pluck(tokenId, "MVP", mvp);
    }

    function pluck(uint256 tokenId, string memory keyPrefix, string[] memory sourceArray) internal view returns (string memory) {
        uint256 rand = random(string(abi.encodePacked(keyPrefix, toString(tokenId))));
        string memory output = sourceArray[rand % sourceArray.length];
        output = string(abi.encodePacked(keyPrefix, ": ", output));
        return output;
    }

    function tokenURI(uint256 tokenId) override public view returns (string memory) {
        string[17] memory parts;
        parts[0] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="20" class="base">';

        parts[1] = getWinner(tokenId);

        parts[2] = '</text><text x="10" y="40" class="base">';

        parts[3] = getMvp(tokenId);

        parts[4] = '</text></svg>';

        string memory output = string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4]));
        
        string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "Prop Sheet #', toString(tokenId), '", "description": "Prop Sheets are super bowl prop NFTs! Any winning sheets will be sent treasury funds upon completion of the game.", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(output)), '"}'))));
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