// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title Orangurock City ERC-721 Smart Contract
 */

 // mint index to do pfp and key starting at 10000

contract OrangurockCity is ERC721, Ownable, Pausable {

    string private baseURI;
    uint256 public mintTokenIndex = 0;
    uint256 public numTokensMinted = 0;
    uint256 public numTokensBurned = 0;

    constructor() ERC721("Orangurock Resident", "OROCK") {}

    /**
    *  @notice mint tokens
    */
    function mintTokens(uint256 numberOfTokens) public onlyOwner {
        for (uint256 i = 0; i < numberOfTokens; i++) {
            uint256 mintIndex = mintTokenIndex;  
            numTokensMinted++;
            mintTokenIndex++;
            _safeMint(msg.sender, mintIndex);
        }
    }

    /**
    *  @notice mint a token id to a wallet
    */
    function mintTokenToWallet(address toWallet, uint256 tokenId) public onlyOwner {
        require(!_exists(tokenId), "ERC721: approved query for nonexistent token");
        numTokensMinted++;
        _safeMint(toWallet, tokenId);
    }

    /**
    *  @notice get total supply
    */
    function totalSupply() external view returns (uint) { 
        return numTokensMinted - numTokensBurned;
    }

    /**
    *  @notice burn token
    */ 
    function burn(uint256 tokenId) external virtual {
	    require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721Burnable: caller is not owner nor approved");
        numTokensBurned++;
	    _burn(tokenId);
    }

    /**
    *  @notice get base url
    */
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    /**
    *  @notice set base url
    */
    function setBaseURI(string memory uri) external onlyOwner {
        baseURI = uri;
    }

    /**
    *  @notice Set current mint token index - mintTokenIndex
    */
    function setMintTokenIndex(uint256 amount) external onlyOwner {
        require(amount >= 0, "Must be greater or equal than zer0");
        mintTokenIndex = amount;
    }

    /**
    *  @notice Withdraw eth if for some stange reason this contract is sent eth
    */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        Address.sendValue(payable(owner()), balance);
    }

    /**
    *  @notice pause contract
    */
    function setPaused(bool _setPaused) external onlyOwner {
	    return (_setPaused) ? _pause() : _unpause();
    }

    // Toggle this function if pausing should suspend transfers
    function _beforeTokenTransfer(
	    address from,
	    address to,
	    uint256 tokenId
    ) internal virtual override(ERC721) {
	    require(!paused(), "Pausable: paused");

	    super._beforeTokenTransfer(from, to, tokenId);
    }
}