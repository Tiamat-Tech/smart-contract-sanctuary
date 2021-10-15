// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/interfaces/IERC721.sol';
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract APATHYV2 is ERC721Enumerable, Ownable {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint public MAX_TOKENS = 500;
    using SafeMath for uint256;
    using Strings for uint256;

    constructor() ERC721("APATHYV2", "MEH"){}
    

    function mint(address recipient) public payable returns (uint256){
        require(msg.value >= 0.08 ether, "Wrong Amount");
        require(SafeMath.add(totalSupply(), 1) <= MAX_TOKENS , "Exceeds maximum token supply.");
        
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        return newItemId;
        
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), 'ERC721Metadata: URI query for nonexistent token');
        return string(abi.encodePacked(_baseURI(), tokenId.toString()));
    }
}