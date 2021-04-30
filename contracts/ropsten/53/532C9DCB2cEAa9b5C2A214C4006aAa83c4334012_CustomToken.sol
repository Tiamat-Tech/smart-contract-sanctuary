pragma solidity ^0.8.0;

import "./presets/ERC721PresetMinterPauserAutoId.sol";

contract CustomToken is ERC721PresetMinterPauserAutoId {
    string constant private NAME = "TestTokenContract";
    string constant private SYMBOL = "TTC";
    string constant private BASE_URI = "";

    constructor() ERC721PresetMinterPauserAutoId(NAME, SYMBOL, BASE_URI) {}
    
    /**
     * @dev Function to transfer token recipient
     * @param to The address that will receive the minted tokens.
     * @param tokenId The token id.
     * @return A boolean that indicates if the operation was successful.
     */
    function transfer(address to, uint256 tokenId) public returns(bool){
        super._transfer(_msgSender(), to, tokenId);
        return true;
    }
}