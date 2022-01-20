// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import './Base64.sol';

contract Emojis is ERC721Enumerable, Ownable {

    using Strings for uint256;

    bool public _saleActive = false;

    uint256 public _maxSupply = 50;
    uint256 public _maxPerMint = 5;
    uint256 public _totalMinted = 0;
    uint256 public _price = 0 ether;

    uint16 public _counter = 0;

    constructor() ERC721("Emojis", "Emojis"){

    }
    //-----------------------------------------------------Disgusting SVG files---------------------------------------------------------//
    string private svgBeginning = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 -0.5 64 64" shape-rendering="crispEdges">';
    string[4] private _layer1Names = ["Blue", "Green", "Orange", "White"];
    string[4] private _layer2Names = ["Angry", "Closed", "Dead", "Normal"];
    string[4] private _layer3Names = ["Neutral", "Open", "Sad", "Smile"];
    string[4] private _layer4Names = ["Baby", "Halo", "Horns", "Top Hat"];

    string[4] private _layer1SVG = [
        '',
        '',
        '',
        ''
    ];
    string[4] private _layer2SVG = [
        '<path stroke="#000000" d="M20 19h1M44 19h1M21 20h1M43 20h1M22 21h1M42 21h1M23 22h1M41 22h1M20 23h3M24 23h1M40 23h1M42 23h3M19 24h5M25 24h1M39 24h1M41 24h5M19 25h1M21 25h1M23 25h1M41 25h5M20 26h4M41 26h5M20 27h2M42 27h3" /><path stroke="#000001" d="M20 25h1M22 27h1" /><path stroke="#000100" d="M22 25h1" /><path stroke="#010000" d="M19 26h1" />',
        '<path stroke="#000000" d="M18 25h7M40 25h7M18 26h7M40 26h7" />',
        '<path stroke="#000000" d="M19 23h1M23 23h1M41 23h1M45 23h1M20 24h1M22 24h1M44 24h1M21 25h1M43 25h1M20 26h1M22 26h1M42 26h1M44 26h1M19 27h1M23 27h1M41 27h1M45 27h1" /><path stroke="#000100" d="M42 24h1" />',
        '<path stroke="#000000" d="M20 23h3M42 23h3M19 24h5M41 24h5M19 25h5M41 25h5M19 26h5M41 26h5M20 27h3M42 27h3" />'
    ];
    string[4] private _layer3SVG = [
        '<path stroke="#000000" d="M19 42h9M29 42h17" /><path stroke="#000001" d="M28 42h1" />',
        '<path stroke="#000000" d="M30 39h5M29 40h1M35 40h1M28 41h1M36 41h1M28 42h1M36 42h1M37 43h1M27 44h1M37 44h1M27 45h1M37 45h1M27 46h1M37 46h1M28 47h1M36 47h1M28 48h1M36 48h1M29 49h1M35 49h1M30 50h5" /><path stroke="#d95763" d="M30 40h5M29 41h7M29 42h7M28 43h3M32 43h1M34 43h2M28 44h9M28 45h6M36 45h1M28 46h4M33 46h4M29 47h7M29 48h5M35 48h1M30 49h5" /><path stroke="#010000" d="M27 43h1" /><path stroke="#d85763" d="M31 43h1M34 45h1M32 46h1" /><path stroke="#d95663" d="M33 43h1M35 45h1M34 48h1" /><path stroke="#d95762" d="M36 43h1" />',
        '<path stroke="#000000" d="M26 42h13M24 43h1M26 43h9M36 43h3M40 43h1M23 44h4M38 44h4M24 45h1M40 45h2" /><path stroke="#000001" d="M25 43h1M23 45h1" /><path stroke="#000100" d="M35 43h1M39 43h1" />',
        '<path stroke="#000000" d="M20 42h2M43 42h2M20 43h2M42 43h2M21 44h3M41 44h3M22 45h2M39 45h4M23 46h19M26 47h13" /><path stroke="#000100" d="M22 43h1" /><path stroke="#000001" d="M44 43h1M24 45h2" />'
    ];
    string[4] private _layer4SVG = [
        '<path stroke="#000000" d="M31 1h3M30 2h1M34 2h1M29 3h1M32 3h1M34 3h1M29 4h1M33 4h1M29 5h1M30 6h2M31 7h2" /><path stroke="#010000" d="M30 5h1" />',
        '<path stroke="#fbf236" d="M24 1h1M26 1h14M20 2h13M34 2h10M17 3h4M22 3h3M39 3h3M43 3h4M15 4h2M19 4h2M43 4h6M14 5h4M46 5h4M13 6h3M48 6h1M50 6h1M13 7h2M49 7h2M13 8h2M49 8h2M13 9h3M48 9h3M14 10h4M46 10h4M15 11h3M19 11h2M43 11h6M17 12h8M39 12h8M20 13h15M36 13h8M24 14h16" /><path stroke="#fbf336" d="M25 1h1M33 2h1M21 3h1M17 4h1" /><path stroke="#faf236" d="M42 3h1M49 6h1M35 13h1" /><path stroke="#fbf237" d="M18 4h1M18 11h1" />',
        '<path stroke="#222034" d="M13 4h1M50 4h1M12 5h2M50 5h2M11 6h1M13 6h1M50 6h1M52 6h1M10 7h1M13 7h1M50 7h1M9 8h1M13 8h1M50 8h1M54 8h1M9 9h1M13 9h1M50 9h1M54 9h1M9 10h1M13 10h2M49 10h2M54 10h1M14 11h2M48 11h2M54 11h1M9 12h1M15 12h2M47 12h2M54 12h1M9 13h1M16 13h1M47 13h1M54 13h1M9 14h1M54 14h1M9 15h2M53 15h2M10 16h1M53 16h1M10 17h1M11 18h1M52 18h1M11 19h1M52 19h1" /><path stroke="#ac3232" d="M12 6h1M51 6h1M11 7h2M52 7h1M10 8h1M51 8h2M10 9h3M51 9h2M10 10h3M52 10h2M10 11h4M50 11h4M11 12h4M49 12h5M10 13h5M49 13h5M10 14h1M12 14h4M48 14h4M53 14h1M11 15h4M49 15h4M11 16h3M50 16h3M11 17h2M51 17h2M12 18h1M51 18h1" /><path stroke="#ac3233" d="M51 7h1M53 8h1M48 13h1" /><path stroke="#232034" d="M53 7h1M53 17h1" /><path stroke="#ad3232" d="M11 8h2M51 10h1M10 12h1M15 13h1M52 14h1" /><path stroke="#ac3332" d="M53 9h1M11 14h1" /><path stroke="#222134" d="M9 11h1" />',
        '<path stroke="#222034" d="M19 0h16M36 0h3M40 0h5M19 1h14M34 1h3M38 1h7M19 2h16M36 2h3M40 2h5M19 3h26M19 4h7M27 4h18M19 5h9M29 5h16M19 6h1M21 6h2M24 6h11M36 6h9M19 7h17M37 7h8M11 10h4M16 10h18M35 10h10M46 10h8M11 11h21M33 11h4M38 11h16M11 12h43M11 13h43M11 14h43" /><path stroke="#222035" d="M35 0h1M28 5h1M20 6h1M23 6h1M35 6h1M34 10h1M45 10h1M32 11h1M37 11h1" /><path stroke="#222134" d="M39 0h1M33 1h1M37 1h1M39 2h1M26 4h1M36 7h1" /><path stroke="#232034" d="M35 2h1" /><path stroke="#ac3232" d="M19 8h3M23 8h22M19 9h9M29 9h16" /><path stroke="#ac3332" d="M22 8h1M28 9h1" /><path stroke="#232134" d="M15 10h1" />'
    ];
    //-----------------------------------------------------Disgusting SVG files---------------------------------------------------------//
    
    //This is going to be our NFT 
    struct EmojiObject {
        uint256 Layer1;
        uint256 Layer2;
        uint256 Layer3;
        uint256 Layer4;
    }

    EmojiObject _emoObj;

    //This will create an emojiObject and return it
    function createEmoji()internal returns (EmojiObject memory){
        EmojiObject memory _emo;
        _emo.Layer1 = getRandom(5);
        _emo.Layer2 = getRandom(5);
        _emo.Layer3 = getRandom(5);
        _emo.Layer4 = getRandom(5);
        return _emo;
    }

    //This will get the SVG based on the emojiObject
    function createSVG()internal view returns (string memory){
        string memory _svgOutput = string(abi.encodePacked(
            svgBeginning, 
            _layer1SVG[_emoObj.Layer1],
            _layer2SVG[_emoObj.Layer2],
            _layer3SVG[_emoObj.Layer3],
            _layer4SVG[_emoObj.Layer4],
            '</svg>'
            ));
        return _svgOutput;
    }

    function createTraitsJSON()internal view returns (string memory){
        string memory _traitsOutput = string(abi.encodePacked(
            '"attributes":',
            '[',
            '{"trait_type":"Face"','"value":',_layer1Names[_emoObj.Layer1],'}',
            '{"trait_type":"Eyes"','"value":',_layer2Names[_emoObj.Layer2],'}',
            '{"trait_type":"Mouth"','"value":',_layer3Names[_emoObj.Layer3],'}',
            '{"trait_type":"Accessories"','"value":',_layer4Names[_emoObj.Layer4],'}',
            ']'
        ));

        return _traitsOutput;
    }
    //Overrides the tokenURI
    function tokenURI(uint256 tokenId) override public view returns (string memory) {
        string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "On-Chain Emojis #', toString(tokenId), '", "description": "What emoji ya got?"', createTraitsJSON(), '"image": "data:image/svg+xml;base64,', Base64.encode(bytes(createSVG())), '"}'))));
        json = string(abi.encodePacked('data:application/json;base64', json));

        return json;
    }

    //Minting functions for emojis
    function mint(address wallet, uint256 num) public payable{
        //Requires sale to be active
        require(_saleActive, "Sale is not Active");
        //Makes sure it doesn't go over max supply!
        require((_totalMinted + num) <= _maxSupply, "Sales ended or you tried to mint over the supply");
        //Makes sure that max mint per transcation is limited
        require(num <= _maxPerMint, "Do not go over the max mint limit please");
        //Makes sure there has to be at least one token _totalMinted
        require(num > 0, "Please put proper value");
        //Need to be enough ether
        require(msg.value >= _price*num, "Not enough ether!");

        for (uint256 i = 0; i < num; i++){
            _totalMinted += 1;
            _emoObj = createEmoji();
            _safeMint(wallet, _totalMinted);
        }
        
    }

    //Gets random num within the range of 0 to range-1
    function getRandom (uint256 range) public returns (uint256){
        _counter += 1;
        return uint256(keccak256(abi.encodePacked(_totalMinted,block.timestamp,block.difficulty, msg.sender, _counter))) % range;
    }

    //Changes the sale state
    function changeSale(bool val)public onlyOwner {
        _saleActive = val;
    }

    //Changes the max per mint
    function changeMaxTrans(uint256 num)public onlyOwner{
        _maxPerMint = num;
    }

    //Changes the max supply
    function changeMaxSupply(uint256 num)public onlyOwner{
        _maxSupply = num;
    }

    //Changes price of mint
    function changeMintPrice(uint256 newPrice)public onlyOwner{
        _price = newPrice;
    }

    //Withdraw
    function withdrawAll() public payable onlyOwner {
        require(payable(_msgSender()).send(address(this).balance));
    }

    //Converts to string
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