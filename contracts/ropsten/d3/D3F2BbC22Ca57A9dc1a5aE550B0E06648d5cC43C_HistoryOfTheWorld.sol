// SPDX-License-Identifier: GPL-3.0
/*


*/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./Base64.sol";


contract HistoryOfTheWorld is ERC721, ERC721URIStorage, Ownable {

    
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
    
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    
    struct HistoryInfo {
        uint256 tokenId;
        string text;
        uint year;
        uint month;
        uint date;
    }
    
    
    mapping (uint256 => HistoryInfo) history;

    constructor() ERC721("History of the world", "HOW") {}

    function sliceStringBytes(uint start, uint end, bytes memory text, uint height) 
        private pure 
        returns (string memory) 
    {
        bytes memory slice = new bytes(end - start);
        for (uint i = start; i < end; i++) {
            slice[i - start] = text[i];
        }
        return string(
            abi.encodePacked(
                '<text x="10" y="',
                Strings.toString(height), 
                '" class="base">',
                string(slice),
                '</text>'
            )
        );
    }

    function turnIntoMultiLineText(string memory line) 
        private pure 
        returns (string memory)
    {

        string memory output;
        bytes memory input = bytes(line);
        uint maxWidth = 19;
        uint maxLines = 7;
        uint sol = 0;
        while (maxLines > 0) {
            for (uint i = sol + maxWidth; i >= sol; i--) {
                if (i >= input.length) {
                    continue;
                }
                if (input[i] == ' ' || i == input.length - 1) {
                    // sol to i is the latest line
                    string memory current = sliceStringBytes(sol, i + 1, input, 20 + (7 - maxLines) * 14);
                    output = string(abi.encodePacked(output, current));
                    sol = i + 1; 
                    break;
                }
            }
            if (sol >= input.length) {
                break;
            }
            maxLines -= 1;
        }
        return output;

    }
    
    
    function getTokenURI(HistoryInfo memory historyInfo) 
        private pure
        returns (string memory) 
    {
        
        string memory textColor = 'white';
        string memory bg = 'black';

        string[11] memory parts;
        parts[0] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 140 180"><style>.base { fill: ';
        
        parts[1] = string(abi.encodePacked(textColor));
        
        parts[2] = '; font-family: "Helvetica Neue"; font-size: 14px; font-weight="bold"; } .footer { fill: ';

        parts[3] = string(abi.encodePacked(textColor));

        parts[4] = '; font-family: "Helvetica Neue"; font-size: 6px; }</style><rect width="100%" height="100%" fill="';
        
        parts[5] = string(abi.encodePacked(bg));
        
        parts[6] = '" />';

        parts[7] = turnIntoMultiLineText(historyInfo.text);

        parts[8] = '<text x="10" y="170" class="footer">';

        parts[9] = string(abi.encodePacked(historyInfo.year,"/", historyInfo.month,"/", historyInfo.date));
        
        parts[10] = '</text></svg>';

        string memory output = string(
            abi.encodePacked(
                parts[0],
                parts[1],
                parts[2],
                parts[3],
                parts[4],
                parts[5],
                parts[6],
                parts[7],
                parts[8],
                parts[9],
                parts[10]
            )
        );
        
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "History #',
                        Strings.toString(historyInfo.tokenId),
                        '", "description": "', historyInfo.text, '", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(output)),
                        '"}'
                    )
                )
            )
        );
        output = string(
            abi.encodePacked('data:application/json;base64,', json)
        );
        return output;
    }
    
    function mintDateWithEvent(uint year, uint month, uint date, string memory text) public returns(uint)
    {
        uint256 tokenId = year * 10000 + month*100 + date;
        _mint(msg.sender, tokenId);
        HistoryInfo memory historyInfo = HistoryInfo(tokenId, text, year, month, date);
        history[tokenId] = historyInfo;
        _setTokenURI(tokenId, getTokenURI(historyInfo));
        return tokenId;
    }
    
    function setHistoryEvent(uint year, uint month, uint date, string memory text) public{
        uint256 tokenId = year * 10000 + month*100 + date;
        require(super.ownerOf(tokenId) == msg.sender, "Only the owner of the date can change the event");
        history[tokenId].text = text;
    }
    
    function getHistoryInfo(uint year, uint month, uint date) 
        public view
        returns(HistoryInfo memory)
    {
        uint256 tokenId = year * 10000 + month*100 + date;
        return history[tokenId];

    }

}