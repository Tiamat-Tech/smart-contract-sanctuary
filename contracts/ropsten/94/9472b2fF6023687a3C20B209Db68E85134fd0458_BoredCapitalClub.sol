// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 *      ____  ____  ____  __________     _________    ____  _____________    __       ________    __  ______ 
 *     / __ )/ __ \/ __ \/ ____/ __ \   / ____/   |  / __ \/  _/_  __/   |  / /      / ____/ /   / / / / __ )
 *    / __  / / / / /_/ / __/ / / / /  / /   / /| | / /_/ // /  / / / /| | / /      / /   / /   / / / / __  |
 *   / /_/ / /_/ / _, _/ /___/ /_/ /  / /___/ ___ |/ ____// /  / / / ___ |/ /___   / /___/ /___/ /_/ / /_/ / 
 *  /_____/\____/_/ |_/_____/_____/   \____/_/  |_/_/   /___/ /_/ /_/  |_/_____/   \____/_____/\____/_____/  
 *                                                                                                         
 */

/**
 * @title Bored Capital Club ERC-721 Smart Contract
 */

contract BoredCapitalClub is ERC721, Ownable, Pausable {

    string private baseURI;
    uint256 public mintTokenIndex = 1;
    uint256 public numTokensMinted = 0;
    uint256 public numTokensBurned = 0;

    constructor() ERC721("Bored Capital Club", "BCC") {}

    /**
    *  @notice mint n numbers of tokens sequentially
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
    *  @notice mint n numbers of tokens to wallet sequentially
    */
    function mintTokensToWallet(address toWallet, uint256 numberOfTokens) public onlyOwner {
        for (uint256 i = 0; i < numberOfTokens; i++) {
            uint256 mintIndex = mintTokenIndex;
            numTokensMinted++;
            mintTokenIndex++;
            _safeMint(toWallet, mintIndex);
        }
    }

    /**
    *  @notice mint a token id to a wallet
    */
    function mintTokenIdToWallet(address toWallet, uint256 tokenId) public onlyOwner {
        numTokensMinted++;
        _safeMint(toWallet, tokenId);
    }

    /**
    *  @notice mint batch tokens ids to wallet
    */
    function mintTokensIdsToWallet(address toWallet, uint256[] calldata tokens) public onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            require(!_exists(tokens[i]), "ERC721: approved query for nonexistent token");
            numTokensMinted++;
            _safeMint(toWallet, tokens[i]);
        }
    }

    /**
    *  @notice get total supply
    */
    function totalSupply() external view returns (uint) { 
        return numTokensMinted - numTokensBurned;
    }

    // BURN IT 
    function burn(uint256 tokenId) external virtual {
	    require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721Burnable: caller is not owner nor approved");
        numTokensBurned++;
	    _burn(tokenId);
    }

    // Set BaseURI
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory uri) external onlyOwner {
        baseURI = uri;
    }

    // Withdraw eth if for some stange reason this contract is sent eth
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        Address.sendValue(payable(owner()), balance);
    }

    /**
    *  @notice Set current mint token index - mintTokenIndex
    */
    function setMintTokenIndex(uint256 tokenIndex) external onlyOwner {
        require(tokenIndex >= 0, "Must be greater or equal than zer0");
        require(!_exists(tokenIndex), "The token already exists");       
        mintTokenIndex = tokenIndex;
    }

    // Pause Contract
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