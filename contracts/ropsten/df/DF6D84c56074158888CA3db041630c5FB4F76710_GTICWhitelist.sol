// SPDX-License-Identifier: MIT
// Developer: @Brougkr
pragma solidity ^0.8.9;
import '@openzeppelin/contracts/interfaces/IERC721.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';

contract GTICWhitelist is Ownable, Pausable
{   
    mapping (uint256 => address) private mintingWhitelist;
    address private immutable _GTICAddress = 0xB1A899C82b5C9FDf81dF87c4a02c02A08Ab0E4B2; //CHANGE TO SPEC                                                      
    address private immutable _BRTMULTISIG = 0xB96E81f80b3AEEf65CB6d0E280b15FD5DBE71937;

    //Sends GTIC & Whitelists Address to receive ICC
    function whitelistICC(uint256 tokenID, address to) public
    {
        require(IERC721(_GTICAddress).ownerOf(tokenID) == msg.sender);
        IERC721(_GTICAddress).safeTransferFrom(msg.sender, _BRTMULTISIG, tokenID);
        mintingWhitelist[tokenID] = to;
    }

    //Reads Whitelisted Address Corresponding to GTIC TokenID
    function readWhitelist(uint256 tokenID) public view returns(address) { return mintingWhitelist[tokenID]; }

    //Optional: Withdraws Extra Tokens / Ether
    function withdraw() public onlyOwner { payable(msg.sender).transfer(address(this).balance); }
}