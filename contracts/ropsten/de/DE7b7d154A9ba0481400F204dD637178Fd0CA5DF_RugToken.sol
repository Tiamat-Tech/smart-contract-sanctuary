// contracts/RugToken.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RugToken is ERC721, Ownable {
    uint256 private _cap = 5;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(string => uint8) hashes;
    constructor() public ERC721("RugToken","RUG"){
        _setBaseURI("https://ipfs.io/ipfs/");
    }

    function getCap() public view returns (uint256){
        return _cap;
    }

    function mintRug(address to, string memory tokenURI)
        public
        onlyOwner
        returns(string memory)
    {
        require(hashes[tokenURI] != 1, "This token has already been minted.");
        require(totalSupply() <= _cap, "The supply is capped.");

        hashes[tokenURI] = 1;
        _tokenIds.increment();

        uint256 id = _tokenIds.current();
        _mint(to, id);
        _setTokenURI(id, tokenURI);
        return("The transaction went through! Rug minted!");
    }

    function burnRug(uint256 id, string memory tokenURI)
        public
        onlyOwner
    {
        _burn(id);
        hashes[tokenURI] = 0;
        _tokenIds.decrement();
    }
}