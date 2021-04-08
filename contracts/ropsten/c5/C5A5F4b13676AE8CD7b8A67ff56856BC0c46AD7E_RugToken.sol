// contracts/RugToken.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RugToken is ERC721, Ownable {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(string => uint8) hashes;
 
    constructor() public ERC721("RugToken","RUG"){
        _setBaseURI("https://ipfs.io/ipfs/");
    }

    function mintRug(address to, string memory tokenURI)
        public
        onlyOwner
        returns (uint256)
    {
//        require(hashes[tokenURI] != 1);
        hashes[tokenURI] = 1;

        _tokenIds.increment();

        uint256 id = _tokenIds.current();
        _mint(to, id);
        _setTokenURI(id, tokenURI);

        return id;
    }

    function burnRug(uint256 id)
        public
        onlyOwner
    {
        _burn(id);
        _tokenIds.decrement();
    }
}