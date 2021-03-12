/**
 *Submitted for verification at Etherscan.io on 2021-03-12
*/

// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.8.0;

contract Emoji {
    string[] private emojilist = [unicode"🤠", unicode"🚀", unicode"🐭",
                                  unicode"🐹", unicode"🐰", unicode"🦊",
                                  unicode"🐻", unicode"🐥", unicode"🐝",
                                  unicode"🐌", unicode"🍪", unicode"🔥",
                                  unicode"🌟", unicode"🍟", unicode"🌮",
                                  unicode"🍖", unicode"🍕", unicode"🥑",
                                  unicode"🍌", unicode"🍊", unicode"🍉"];

    function getEmoji() public view returns (string memory) {
        uint randomNumber = getRandomNumber(emojilist.length);
        return emojilist[randomNumber];
    }

    function getRandomNumber(uint max) private view returns (uint) {
        uint randomHash = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
        return randomHash % (max - 1);
    } 
}