//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// .-'''-.                                                                                                             .-'''-.                          //
// '   _    \                                                                                   _______                '   _    \                       //
// /|                 /   /` '.   \     .           __.....__        _..._                   __.....__               \  ___ `'.           /   /` '.   \ //
// ||                .   |     \  '   .'|       .-''         '.    .'     '.             .-''         '.              ' |--.\  \         .   |     \  ' //
// ||        .-,.--. |   '      |  '.'  |      /     .-''"'-.  `. .   .-.   .           /     .-''"'-.  `.            | |    \  '        |   '      |  '//
// ||  __    |  .-. |\    \     / /<    |     /     /________\   \|  '   '  |          /     /________\   \    __     | |     |  '    __ \    \     / / //
// ||/'__ '. | |  | | `.   ` ..' /  |   | ____|                  ||  |   |  |       _  |                  | .:--.'.   | |     |  | .:--.'.`.   ` ..' /  //
// |:/`  '. '| |  | |    '-...-'`   |   | \ .'\    .-------------'|  |   |  |     .' | \    .-------------'/ |   \ |  | |     ' .'/ |   \ |  '-...-'`   //
// ||     | || |  '-                |   |/  .  \    '-.____...---.|  |   |  |    .   | /\    '-.____...---.`" __ | |  | |___.' /' `" __ | |             //
// ||\    / '| |                    |    /\  \  `.             .' |  |   |  |  .'.'| |// `.             .'  .'.''| | /_______.'/   .'.''| |             //
// |/\'..' / | |                    |   |  \  \   `''-...... -'   |  |   |  |.'.'.-'  /    `''-...... -'   / /   | |_\_______|/   / /   | |_            //
// '  `'-'`  |_|                    '    \  \  \                  |  |   |  |.'   \_.'                     \ \._,\ '/             \ \._,\ '/            //
//            '------'  '---'                '--'   '--'                               `--'  `"               `--'  `"                                  //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract BrokenSeaDAO is ERC721Enumerable, Ownable {
    using Strings for uint256;

    uint256 private PRICE = 0.03 ether;
    uint256 private MAX_TOKENS_PER_TRANSACTION = 999;
    uint256 private MAX_SUPPLY = 10000;
    uint256 private freeLimit = 11;
    bool public revealed = false;

    string private notRevealedUri =
        "https://gateway.pinata.cloud/ipfs/QmZsfR4yFNW3e6EVu8RGEDcQQzDQ2TpTkvdv6e6AoH5xeW/1.gif";

    string public _baseTokenURI =
        "ipfs://QmVZrpfVzrc5Ci5UWg8mT3Go4CaQCSD2tZTHaxMFFQxjEh/";
    string private _baseTokenSuffix = ".json";

    address art = 0x5Ab0787A16E66A57dDa644201b253D214fA5193a;

    constructor() ERC721("BrokenSeaDAO", "BRKN") {
    }

    function reveal() public onlyOwner {
        revealed = true;
    }

    function mint(uint256 _count) external payable {
        require(
            _count <= MAX_TOKENS_PER_TRANSACTION,
            "Count exceeded max tokens per transaction."
        );

        uint256 supply = totalSupply();
        require(
            supply + _count < MAX_SUPPLY,
            "Exceeds max BRKN token supply."
        );
        if (supply < freeLimit) {
            for (uint256 i = 1; i <= _count; ++i) {
                _safeMint(msg.sender, supply + i, "");
            }
        } else {
            require(msg.value >= PRICE * _count, "Ether sent is not correct.");
            for (uint256 i = 1; i <= _count; ++i) {
                _safeMint(msg.sender, supply + i, "");
            }
        }
    }

    function setPrice(uint256 _newPrice) external {
        PRICE = _newPrice;
    }

    function setBaseURI(string calldata _newBaseURI)
        external
    {
        _baseTokenURI = _newBaseURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (!revealed) {
            return notRevealedUri;
        }
        string memory baseURI = _baseTokenURI;
        return
            bytes(baseURI).length > 0
                ? string(
                    abi.encodePacked(
                        baseURI,
                        tokenId.toString(),
                        _baseTokenSuffix
                    )
                )
                : "";
    }
}