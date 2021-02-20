// contracts/Box721.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract Box721 is ERC721 {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // Create the token-making contract
    constructor() public ERC721("MyBox", "MBX") {}

    function newBox(address boxOwner, string memory tokenURI)
        public
        returns (uint256)
        {
            _tokenIds.increment();

            uint256 newBoxId = _tokenIds.current();
            _mint(boxOwner, newBoxId);
            _setTokenURI(newBoxId, tokenURI);

            return newBoxId;
        }


}