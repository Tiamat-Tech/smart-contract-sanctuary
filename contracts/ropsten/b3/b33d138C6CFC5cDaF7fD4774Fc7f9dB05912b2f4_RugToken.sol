// contracts/RugToken.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract RugToken is ERC721, Ownable {
    uint256 private _cap = 0;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(string => uint8) hashes;
    event CapChanged(uint256 newCap);
    constructor() public ERC721("RugToken","RUG"){
        _setBaseURI("https://ipfs.io/ipfs/");
    }
    function setCap(uint256 newCap)
    public
    onlyOwner
    returns (uint256)
    {
    require(newCap<=3);
    _cap = newCap;
    emit CapChanged(newCap);
    return newCap;
    }
    function getCap() public view returns (uint256){
    return _cap;
    }
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override
        {
            super._beforeTokenTransfer(from, to, tokenId);
            require(totalSupply() < _cap, "ERC721 Capped: cap exceeded");
        }
    function mintRug(address to, string memory tokenURI)
        public
        onlyOwner
        returns (uint256)
    {
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