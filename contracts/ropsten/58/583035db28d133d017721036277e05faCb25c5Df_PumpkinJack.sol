// contracts/PumpkinJack.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

interface IPrize {
    function getPrize(address winner, uint8 amount, uint8 class) external;
}

interface IBrainz {
    function balanceOf(address tokenOwner) external view returns (uint balance);
}

contract PumpkinJack is ERC721Enumerable 
{
    mapping(bytes32 => uint8[2]) magicWords;
    mapping(uint => uint8[2]) tokenIdToData;

    address constant burnAddress=0x000000000000000000000000000000000D15ea5E;
    address public _owner;
    address prizeAddress;
    address brainzAddress;

    string[2] pumpkinSVG;
    
    constructor() ERC721 ("PumpkinJack", "PUMPJCK") {
        _owner=msg.sender;
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId));
        bool broken = ownerOf(_tokenId)==burnAddress;
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    encode(
                        bytes(
                            string(
                                abi.encodePacked(
                                    '{"name": "Pumpkin #',
                                    _toString(_tokenId),
                                    '", "description":"',
                                    broken?"Nothing inside":"Sounds like there is something inside... Ask Jack to break it to get the prize.",
                                    '","image": "data:image/svg+xml;base64,',
                                    encode(bytes(broken?pumpkinSVG[1]:pumpkinSVG[0])),
                                    '","attributes":[{"trait_type":"gifts","value":',
                                    _toString(tokenIdToData[_tokenId][0]), 
                                    '},{"trait_type":"broken","value":"',
                                    broken?"Yes":"No",
                                    '"}]}'
                                )
                            )
                        )
                    )
                )
            );
    }

    function brainsSacrificed() external view returns(uint256){
        return IBrainz(brainzAddress).balanceOf(address(this));
    }

    function breakPumpkin(uint tokenId) external {
        require(msg.sender==ownerOf(tokenId), "You're not the owner");
        _transfer(msg.sender, burnAddress, tokenId);
        IPrize(prizeAddress).getPrize(msg.sender, tokenIdToData[tokenId][0], tokenIdToData[tokenId][1]);
    }

    function whispWords(string memory _secret) external view returns(string memory) {
        return magicWords[sha256(bytes(_secret))][0] > 0 ? "You feel someone is watching you" : "Nothing happens";
    }

    function sayWords(string memory _secret) external {
        bytes32 secretHash=sha256(bytes(_secret));
        uint8[2] memory data = magicWords[secretHash];
        require(data[0] > 0,"Nothing happened");

        delete magicWords[secretHash];

        uint mintId = totalSupply();
        tokenIdToData[mintId]=data;
        _mint(msg.sender, mintId);
    }

    function removeMagicWords(bytes32 _hash) external onlyOwner {
        delete magicWords[_hash];
    }

    function addMagicWords(bytes32 _hash, uint8 _prize, uint8 _class) external onlyOwner {
        magicWords[_hash]=[_prize, _class];
    }

    function setAddress(address _brainsAddress, address _prizeAddress) external onlyOwner {
        brainzAddress=_brainsAddress;
        prizeAddress=_prizeAddress;
    }

    function setSVG(string memory _svg, bool broken) external onlyOwner {
        broken?pumpkinSVG[1]=_svg:pumpkinSVG[0]=_svg;
    }

    // Modifier to allow action to be performed by contract owner only
    modifier onlyOwner() {
        require(_owner == msg.sender);
        _;
    }

    // Utility functions

    string internal constant TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    function encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return "";

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
            for {

            } lt(dataPtr, endPtr) {

            } {
                dataPtr := add(dataPtr, 3)

                // read 3 bytes
                let input := mload(dataPtr)

                // write 4 characters
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(input, 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
            }

            // padding with '='
            switch mod(mload(data), 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }
        }

        return result;
    }

    function _toString(uint256 value) internal pure returns (string memory) 
    {
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