// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "base64-sol/base64.sol";

struct Sunrise {
    string skyType;
    string gridType;
    string sunType;
    string sunColor;
    string haloColor;
    string horizonColor;
    string backgroundColor;
    string groundColor;
    string gridColor;
}

contract MetaverseSunrise is ERC721, ERC721Enumerable, Ownable, ReentrancyGuard {
    // Global Constants
    uint256 public immutable MAX_SUPPLY = 1024;

    // Token Hash Storage
    mapping(uint256 => bytes32) public tokenIdToHash;
    mapping(address => uint256) public numAuthorized;
    mapping(address => uint256) public numMinted;
    
    // Token ID Counter
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    
    // Constructor
    constructor() ERC721("Metaverse Sunrise", "MVS") {}
    
    // Calculates a series of random bytes
    function _randomBytes(uint256 nonce) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(
            nonce,
            block.number,
            blockhash(block.number - 1),
            msg.sender
        ));
    }
    
    function _hex256(uint256 value) internal pure returns (string memory) {
        bytes16 _HEX_SYMBOLS = "0123456789abcdef";
        bytes memory buffer = new bytes(2);
        buffer[1] = _HEX_SYMBOLS[value & 0xf];
        value >>= 4;
        buffer[0] = _HEX_SYMBOLS[value & 0xf];
        value >>= 4;
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
    
    function _byteToHex(bytes1 b) internal pure returns (string memory) {
        return _hex256(uint8(b));
    }
    
    function _byteToHex(bytes1 b, uint256 floor, uint256 ceiling) internal pure returns (string memory) {
        uint256 charIndex = uint8(b) % ceiling + uint8(floor);
        return _hex256(charIndex);
    }

    function _parseAddr(string memory _a) internal pure returns (address _parsedAddress) {
        bytes memory tmp = bytes(_a);
        uint160 iaddr = 0;
        uint160 b1;
        uint160 b2;
        for (uint i = 2; i < 2 + 2 * 20; i += 2) {
            iaddr *= 256;
            b1 = uint160(uint8(tmp[i]));
            b2 = uint160(uint8(tmp[i + 1]));
            if ((b1 >= 97) && (b1 <= 102)) {
                b1 -= 87;
            } else if ((b1 >= 65) && (b1 <= 70)) {
                b1 -= 55;
            } else if ((b1 >= 48) && (b1 <= 57)) {
                b1 -= 48;
            }
            if ((b2 >= 97) && (b2 <= 102)) {
                b2 -= 87;
            } else if ((b2 >= 65) && (b2 <= 70)) {
                b2 -= 55;
            } else if ((b2 >= 48) && (b2 <= 57)) {
                b2 -= 48;
            }
            iaddr += (b1 * 16 + b2);
        }
        return address(iaddr);
    }
    
    // Internal mint function
    function _mint(address to) internal {
        require(_tokenIdCounter.current() < MAX_SUPPLY, "There are no more tokens left to mint");
        uint256 tokenId = _tokenIdCounter.current();
        tokenIdToHash[tokenId] = _randomBytes(tokenId);
        _safeMint(to, tokenId);
        _tokenIdCounter.increment();
    }
    
    // Public mint function
    function mint() external payable nonReentrant {
        require(numAuthorized[_msgSender()] > 0, "Your address is not authorized to mint");
        _mint(_msgSender());
        numAuthorized[_msgSender()] -= 1;
        numMinted[_msgSender()] += 1;
    }
    
    // Owner mint function
    function ownerMint(uint256 numberOfTokens) external onlyOwner nonReentrant {
        for (uint i = 0; i < numberOfTokens; i++) {
            _mint(_msgSender());
        }
        numMinted[_msgSender()] += numberOfTokens;
    }
    
    // Owner whitelist function
    function whitelist(string[] memory addresses) external onlyOwner {
        for (uint i = 0; i < addresses.length; i++) {
            address parsedAddress = _parseAddr(addresses[i]);
            numAuthorized[parsedAddress] += 1;
        }
    }
    
    // Allows the owner to withdraw all Ether that has been sent to the contract
    function withdraw() external onlyOwner {
        uint balance = address(this).balance;
        (bool sent, ) = payable(msg.sender).call{value: balance}("");
        require(sent, "Failed to withdraw Ether");
    }
    
    // Hook that is called before any transfer of tokens; required for ERC721Enumerable
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // Function that indicates which interfaces are supported ; required for ERC721Enumerable
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    
    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        /*
        Byte guide:
            0 = selects the ground and grid color type
            1-3 = selects the grid color hex for neon grids
            
            4 = selects the sun palette type
            
            5 = selects the background palette type
            6-8 = selects the halo color 
            9 = selects the horizon color
            12 = selects the sky color
        */
        require(_exists(tokenId), 'Token does not exist');
        
        bytes32 b = tokenIdToHash[tokenId];

        Sunrise memory sunrise;
        
        // Set Ground -- 87.5% dark ground, 12.5% white ground
        sunrise.groundColor = (uint8(b[0]) % 8 == 0) ? 'eeeeee' : '1d2121';
        
        // Set Grid -- // 87.5% white or neon lines, 12.5% dark lines
        if (uint8(b[0]) % 8 == 0) { // 12.5% Black
            sunrise.gridColor = '1d2121';
            sunrise.gridType = 'Black';
        } else if (uint8(b[0]) % 8 < 4) { // 37.5% White
            sunrise.gridColor = 'eeeeee';
            sunrise.gridType = 'White';
        } else if (uint8(b[0]) % 8 == 4) { // 12.5% Neon Cyan
            sunrise.gridColor = string(abi.encodePacked(_byteToHex(b[1]), _byteToHex(b[2], 192, 64), _byteToHex(b[3], 192, 64)));
            sunrise.gridType = 'Cyan';
        } else if (uint8(b[0]) % 8 == 5) { // 12.5% Neon
            sunrise.gridColor = string(abi.encodePacked(_byteToHex(b[1], 192, 64), _byteToHex(b[2]), _byteToHex(b[3], 192, 64)));
            sunrise.gridType = 'Magenta';
        } else if (uint8(b[0]) % 8 == 6) { // 12.5% Neon
            sunrise.gridColor = string(abi.encodePacked(_byteToHex(b[1], 192, 64), _byteToHex(b[2], 192, 64), _byteToHex(b[3])));
            sunrise.gridType = 'Yellow';
        } else { // 12.5% Neon Green
            sunrise.gridColor = string(abi.encodePacked(_byteToHex(b[1]), _byteToHex(b[2], 192, 64), _byteToHex(b[3], 0, 64)));
            sunrise.gridType = 'Green';
        }

        // Set Sun -- 87.5% white, 12.5% black
        sunrise.sunColor = (uint8(b[4]) % 8 == 0) ? '000000' : 'ffffff';
        sunrise.sunType = (uint8(b[4]) % 8 == 0) ? 'Black' : 'White';
        
        // Set background color palette type
        if (uint8(b[5]) % 8 == 0) { // 12.5%
            sunrise.haloColor = 'ffffff';
            sunrise.horizonColor = string(abi.encodePacked(_byteToHex(b[9], 0, 128), _byteToHex(b[9], 0, 128), _byteToHex(b[9], 0, 128)));
            sunrise.backgroundColor = string(abi.encodePacked(_byteToHex(b[12], 128, 128), _byteToHex(b[12], 128, 128), _byteToHex(b[12], 128, 128)));
            sunrise.skyType = 'Grayscale';
        } else { // 87.5%
            sunrise.haloColor = string(abi.encodePacked(_byteToHex(b[6], 192, 64), _byteToHex(b[7], 192, 64), _byteToHex(b[8])));
            sunrise.horizonColor = string(abi.encodePacked(_byteToHex(b[9], 192, 64), _byteToHex(b[10], 88, 128), _byteToHex(b[11], 0, 128)));
            sunrise.backgroundColor = string(abi.encodePacked(_byteToHex(b[12]), _byteToHex(b[13]), _byteToHex(b[14], 128, 128)));
            sunrise.skyType = 'Colorful';
        }
        
        string memory svg_1 = string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>line { stroke: #',
            sunrise.gridColor, //'1743ff';
            '; } text { font-family: Tahoma; font-weight: bold; fill: #eeeeee; } </style><defs><filter id="glowSun" x="-5000%" y="-5000%" width="10000%" height="10000%"><feFlood result="flood" flood-color="#',
            sunrise.sunColor,
            '" flood-opacity="1"></feFlood><feComposite in="flood" result="mask" in2="SourceGraphic" operator="in"></feComposite><feMorphology in="mask" result="dilated" operator="dilate" radius="7"></feMorphology><feGaussianBlur in="dilated" result="blurred" stdDeviation="7"></feGaussianBlur><feMerge><feMergeNode in="coloredBlur"></feMergeNode><feMergeNode in="SourceGraphic"></feMergeNode></feMerge></filter><filter id="glowHalo" x="-5000%" y="-5000%" width="10000%" height="10000%"><feFlood result="flood" flood-color="#',
            sunrise.haloColor,
            '" flood-opacity="1"></feFlood><feComposite in="flood" result="mask" in2="SourceGraphic" operator="in"></feComposite><feMorphology in="mask" result="dilated" operator="dilate" radius="15"></feMorphology><feGaussianBlur in="dilated" result="blurred" stdDeviation="15"></feGaussianBlur><feMerge><feMergeNode in="coloredBlur"></feMergeNode><feMergeNode in="SourceGraphic"></feMergeNode></feMerge></filter></defs><linearGradient id="gradient1" x1="0" x2="0" y1="0" y2="1"><stop offset="0%" stop-color="#',
            sunrise.backgroundColor,
            '"></stop><stop offset="50%" stop-color="#'
        ));
        string memory svg_2 = string(abi.encodePacked(
            sunrise.horizonColor,
            '"></stop></linearGradient><rect width="100%" height="100%" fill="url(#gradient1)"></rect><circle r="30" cx="175" cy="163" fill="#',
            sunrise.sunColor,
            '" style="filter:url(#glowHalo);"></circle><circle r="30" cx="175" cy="163" fill="#',
            sunrise.sunColor,
            '" style="filter:url(#glowSun);"></circle><text x="161.5" y="167.5">Gm</text><rect width="100%" height="50%" y="175" fill="#',
            sunrise.groundColor,
            '"></rect><line x1="0%" y1="50.000%" x2="100%" y2="50.000%"></line><line x1="0%" y1="50.500%" x2="100%" y2="50.500%"></line><line x1="0%" y1="51.200%" x2="100%" y2="51.200%"></line><line x1="0%" y1="52.180%" x2="100%" y2="52.180%"></line><line x1="0%" y1="53.552%" x2="100%" y2="53.552%"></line><line x1="0%" y1="55.473%" x2="100%" y2="55.473%"></line><line x1="0%" y1="58.162%" x2="100%" y2="58.162%"></line><line x1="0%" y1="61.927%" x2="100%" y2="61.927%"></line><line x1="0%" y1="67.197%" x2="100%" y2="67.197%"></line><line x1="0%" y1="74.576%" x2="100%" y2="74.576%"></line><line x1="0%" y1="84.907%" x2="100%" y2="84.907%"></line></svg>'
        ));
        string memory svg = string(abi.encodePacked(svg_1, svg_2));
        
        string memory attributes1 = string(abi.encodePacked(
            '[{ "trait_type": "Grid Type", "value": "',
            sunrise.gridType,
            '" },{ "trait_type": "Sky Type", "value": "',
            sunrise.skyType,
            '" },{ "trait_type": "Sun Type", "value": "',
            sunrise.sunType
        ));
        string memory attributes2 = string(abi.encodePacked(
            '" },{ "trait_type": "Halo Color", "value": "#',
            sunrise.haloColor,
            '" },{ "trait_type": "Grid Color", "value": "#',
            sunrise.gridColor,
            '" },{ "trait_type": "Background Color", "value": "#',
            sunrise.backgroundColor,
            '" },{ "trait_type": "Horizon Color", "value": "#',
            sunrise.horizonColor,
            '" }]'
        ));
        
        string memory json = Base64.encode(bytes(string(abi.encodePacked(
            '{"name": "Metaverse Sunrise #',
            Strings.toString(tokenId),
            '", "description": "Metaverse Sunrise is a randomized SVG that is 100% generated & stored on chain. It depicts a morning sun rising over a metaverse expanse, greeting everyone with a warm gm.", "image": "data:image/svg+xml;base64,',
            Base64.encode(bytes(svg)),
            '", "attributes": ',
            attributes1,
            attributes2,
            '}'
        ))));
        
        return string(abi.encodePacked('data:application/json;base64,', json));
    }
}