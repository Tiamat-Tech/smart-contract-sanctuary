// SPDX-License-Identifier: GPL-3.0

import "@openzeppelin/contracts/access/AccessControl.sol";

pragma solidity >=0.7.0 <0.9.0;

/**
 * @title NIL CTF: Endgame
 * @notice only 0bi WAN Kenobi can save you now!
 */
contract NILCTF is AccessControl {
    bytes32 public constant PLAYER_ROLE = keccak256("PLAYER_ROLE");
    
    uint256  wtf = 29836915074519068104088936947794877181446157905180232883246809992121215122387;
    
    event LastSeed(bytes32 theLastSeed);
    event claim(string playerAddress, string twitterHandle, string discordUsername);
    
    constructor(address flagAddress) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PLAYER_ROLE, flagAddress);
    }

    /**
     * You're soooo close, don't give up yet!
     * @param firstLetterOfSeed10 The first letter of seed word 10
     * @param firstLetterOfSeed11 The first letter of seed word 11
     */
    // function retrieveLastWord(string memory firstLetterOfSeed10, string memory firstLetterOfSeed11) public {
    function retrieveLastWord(string memory firstLetterOfSeed10, string memory firstLetterOfSeed11) public {
        bytes32 theLastSeed = bytes32(uint256(keccak256(abi.encodePacked(firstLetterOfSeed10, firstLetterOfSeed11))) - wtf);
        emit LastSeed(theLastSeed);
    }
    
    /**
     * @notice Congrats, you finished!
     * @param playerAddress The player's mainnet address (mandatory)
     * @param twitterHandle Twitter handle so you can be contacted (optional)
     * @param discordUsername  Discord username (including #) so you can be contacted (optional)
     */
     // Write null for Twitter or Discord if you do not have an account
    function claimTreasure(string memory playerAddress, string memory twitterHandle, string memory discordUsername) public onlyRole(PLAYER_ROLE) {
        emit claim(playerAddress, twitterHandle, discordUsername);
    }
    
}