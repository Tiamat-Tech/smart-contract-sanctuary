// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

library Base64 {
    string internal constant TABLE_ENCODE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    bytes  internal constant TABLE_DECODE = hex"0000000000000000000000000000000000000000000000000000000000000000"
                                            hex"00000000000000000000003e0000003f3435363738393a3b3c3d000000000000"
                                            hex"00000102030405060708090a0b0c0d0e0f101112131415161718190000000000"
                                            hex"001a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132330000000000";

    function encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return '';

        // load the table into memory
        string memory table = TABLE_ENCODE;

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
                // read 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // write 4 characters
                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr( 6, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(        input,  0x3F))))
                resultPtr := add(resultPtr, 1)
            }

            // padding with '='
            switch mod(mload(data), 3)
            case 1 { mstore(sub(resultPtr, 2), shl(240, 0x3d3d)) }
            case 2 { mstore(sub(resultPtr, 1), shl(248, 0x3d)) }
        }

        return result;
    }

    function decode(string memory _data) internal pure returns (bytes memory) {
        bytes memory data = bytes(_data);

        if (data.length == 0) return new bytes(0);
        require(data.length % 4 == 0, "invalid base64 decoder input");

        // load the table into memory
        bytes memory table = TABLE_DECODE;

        // every 4 characters represent 3 bytes
        uint256 decodedLen = (data.length / 4) * 3;

        // add some extra buffer at the end required for the writing
        bytes memory result = new bytes(decodedLen + 32);

        assembly {
            // padding with '='
            let lastBytes := mload(add(data, mload(data)))
            if eq(and(lastBytes, 0xFF), 0x3d) {
                decodedLen := sub(decodedLen, 1)
                if eq(and(lastBytes, 0xFFFF), 0x3d3d) {
                    decodedLen := sub(decodedLen, 1)
                }
            }

            // set the actual output length
            mstore(result, decodedLen)

            // prepare the lookup table
            let tablePtr := add(table, 1)

            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            // result ptr, jump over length
            let resultPtr := add(result, 32)

            // run over the input, 4 characters at a time
            for {} lt(dataPtr, endPtr) {}
            {
               // read 4 characters
               dataPtr := add(dataPtr, 4)
               let input := mload(dataPtr)

               // write 3 bytes
               let output := add(
                   add(
                       shl(18, and(mload(add(tablePtr, and(shr(24, input), 0xFF))), 0xFF)),
                       shl(12, and(mload(add(tablePtr, and(shr(16, input), 0xFF))), 0xFF))),
                   add(
                       shl( 6, and(mload(add(tablePtr, and(shr( 8, input), 0xFF))), 0xFF)),
                               and(mload(add(tablePtr, and(        input , 0xFF))), 0xFF)
                    )
                )
                mstore(resultPtr, shl(232, output))
                resultPtr := add(resultPtr, 3)
            }
        }

        return result;
    }
}

contract GNG is ERC721, ERC721Enumerable, Ownable { //0x05894A3b1ab7a3C0448ba714fE2FAb6580eC8B26
    mapping(string => bool) private usedNames;
    mapping(uint256 => Parameters) public parameters;

    constructor() ERC721("GNGFARM", "GNGFARM") {}

    struct Parameters {
        string name;
        uint8 rarity;
        uint8 coefficient;
        /**
            In 2022 the biggest farm is 9,105,426 ha
        */
        uint32 size;
        uint16 emission;
        uint16 garbage;
        string product;
    }
    //replace
    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
    return string(bstr);
}
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
            internal
            override(ERC721, ERC721Enumerable)
        {
            super._beforeTokenTransfer(from, to, tokenId);
        }

        function _burn(uint256 tokenId) internal override(ERC721) {
            super._burn(tokenId);
        }
  function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function mint(
        address to,
        uint256 tokenId,
        string memory _name,
        string memory _product,
        uint8 _rarity,
        uint8 _coefficient,
        uint32 _size,
        uint16 _emission,
        uint16 _garbage
    ) public onlyOwner {
        _safeMint(to, tokenId);
        parameters[tokenId] = Parameters(_name, _rarity, _coefficient, _size, _emission, _garbage, _product);
    }

     function getSvg(uint tokenId) private view returns (string memory) {
        string memory svg;
        svg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 350 350' style='enable-background:new 0 0 32 32' xml:space='preserve' width='350' height='350'><path d='M127.313 306.25h7.875v21.875h-7.875V306.25zm7.875-32.813v-21.875h-7.875v21.875h7.875zm0-76.563h-7.875v21.875h7.875v-21.875zm43.75 54.688h-7.875v21.875h7.875v-21.875zm160.125 83.563v7.886H10.938v-7.886h7v-14h-7v-7.875h72.625v-28.875c0-.634.186-1.214.448-1.75l-.033-.022c10.566-21.131 15.881-55.77 18.561-84.273l-58.789 58.8-27.442-27.442 89.13-89.13v-20.245c0-5.873 1.258-11.517 3.314-16.92l-70.569-70.58L65.625 5.37l70.58 70.58a47.261 47.261 0 0 1 16.92-3.325c16.822 0 32.266 8.969 40.819 23.177L262.5 27.245l27.442 27.443-89.108 89.119c.044 4.933.317 21.623 1.859 42.383l28.623 28.623h42.122c1.313 0 2.538.667 3.281 1.761l43.75 65.625-.055.033a3.85 3.85 0 0 1 .722 2.144v50.75h17.927zm-61.688 0h13.989v-17.937a7 7 0 0 0-14 0l.011 17.938zm21.875 0h13.989v-46.813h-90.551v46.802h46.802v-17.926c0-8.203 6.672-14.875 14.875-14.875s14.875 6.672 14.875 14.875l.011 17.938zm-131.25 0h14v-17.937a7 7 0 0 0-14 0v17.938zm21.875 0h24.927v-46.813H91.438v46.802h68.688v-17.926c0-8.203 6.672-14.875 14.875-14.875s14.875 6.672 14.875 14.875v17.938zm49.317-112.438 28.875 28.875-27.442 27.443-29.159-29.159c2.811 12.403 6.125 22.586 9.866 30.592h88.495l-38.5-57.739-32.134-.011zm-80.5-36.749 81.933 81.932 16.308-16.307L175 169.63l-16.308 16.308zm35.525-8.225a689.664 689.664 0 0 1-1.236-31.587h-30.352L175 158.495l19.217 19.217zm-62.967-19.218 12.37-12.37h-24.741l12.371 12.37zM175 125.879l-12.37 12.37h24.741L175 125.88zm87.5-87.5-81.933 81.934 16.308 16.307 81.933-81.932L262.5 38.38zM142.406 82.152l16.286 16.286-21.875 21.875 16.308 16.307 16.308-16.307 18.725-18.725A39.878 39.878 0 0 0 153.125 80.5c-3.686 0-7.241.667-10.719 1.652zM49.317 32.813l81.933 81.932 16.308-16.307-81.933-81.933-16.308 16.308zm65.647 76.781a39.638 39.638 0 0 0-1.652 10.719v17.938h30.308l-12.37-12.371-16.286-16.286zM43.75 245.995l81.933-81.932-16.308-16.308-81.933 81.933 16.308 16.307zm67.452-56.317c-2.242 28.383-7.175 65.811-17.719 90.748h119.263c-4.484-10.598-8.323-24.15-11.386-40.698l-53.802-53.79 21.875-21.875-16.308-16.308-16.308 16.308-25.616 25.616zM83.563 321.125H58.625v13.989h24.937v-13.989zm-57.75 14H50.75v-14H25.813v14z'/><path style='fill:none' d='M0 0h350v350H0z'/></svg>";
        return svg;
    }    

      function tokenURI(uint256 tokenId) override(ERC721) public view returns (string memory) {
        string memory json = Base64.encode(
            bytes(string(
                abi.encodePacked(
                    '{"name": "', parameters[tokenId].name, '",','"image_data": "', getSvg(tokenId), '",',
                    '"attributes": [{"trait_type": "Product", "value": "', parameters[tokenId].product, '"},',
                    '{"trait_type": "Rarity", "value": ', uint2str(parameters[tokenId].rarity), '},',
                    '{"trait_type": "Coefficient", "value": ', uint2str(parameters[tokenId].coefficient), '},',
                    '{"trait_type": "Size", "value": ', uint2str(parameters[tokenId].size), '},',
                    '{"trait_type": "Emission", "value": ', uint2str(parameters[tokenId].emission), '},',
                    '{"trait_type": "Garbage", "value": ', uint2str(parameters[tokenId].garbage), '},',
                    ']}'
                )
            ))
        );
        return string(abi.encodePacked('data:application/json;base64,', json));
    }    


}