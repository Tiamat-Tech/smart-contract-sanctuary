// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/PullPayment.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract CONVO is ERC721, ERC721Holder, PullPayment, Ownable, Pausable {
    using Counters for Counters.Counter;
    Counters.Counter private currentTokenId;

    // Constants
    uint256 public constant TOTAL_SUPPLY = 1444;
    uint256 public constant MINT_PRICE = 0.05 ether;
    
    constructor() ERC721("CONVO Tutorial", "CONVO") {} 
    
    // public 

    function mintTo(address recipient) public payable whenNotPaused returns (uint256)
    {
        uint256 tokenId = currentTokenId.current();
        require(tokenId < TOTAL_SUPPLY, "Max supply reached");
        require(msg.value == MINT_PRICE, "Transaction value did not equal the mint price");

        currentTokenId.increment();
        uint256 newItemId = currentTokenId.current();
        _safeMint(recipient, newItemId);
        return newItemId;
    }

    function contractURI() public pure returns (string memory) {
        return "https://arweave.net/yzIOS2TSMMugARZXQssxFZtlIE4iwFezm_xkkU2vIqc/conversation-cats-metadata";
    }

    function isApprovedForAll(address _owner, address _operator)
        public
        view
        override
        returns (bool isOperator)
    {
        // if OpenSea's ERC721 Proxy Address is detected, auto-return true
        if (_operator == address(0x58807baD0B376efc12F5AD86aAc70E78ed67deaE)) {
            return true;
        }

        // otherwise, use the default ERC721.isApprovedForAll()
        return ERC721.isApprovedForAll(_owner, _operator);
    }
    
    // owner
    
    function mintReserves(uint256 _count) public onlyOwner 
    {   
        uint256 tokenId = currentTokenId.current();
        require(tokenId + _count < TOTAL_SUPPLY, "Max supply reached");

        uint256 i;
        for (i = 0; i < _count; i++) {
            currentTokenId.increment();
            uint256 newItemId = currentTokenId.current();
            _safeMint(msg.sender, newItemId);
        }
    }

    function withdrawPayments(address payable payee) public override onlyOwner virtual {
        super.withdrawPayments(payee);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
    // internals

    function _baseURI() internal view virtual override returns (string memory) {
        return "https://arweave.net/93nTEsTTXw4JXVw2QI1yKjCwZLcVpJyojcfeoWQLMlM/";
    }
}