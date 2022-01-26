// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@imtbl/imx-contracts/contracts/Mintable.sol";

contract MyToken is ERC721, Ownable,Mintable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("MyToken", "MTK")  Mintable(0xbe5475C0BBC2F06Be89C1bceFE16CD488C5Bd70f, 0x68e6217A0989c5e2CBa95142Ada69bA1cE2cdCA9) {}

    function _baseURI() internal pure override returns (string memory) {
        return "https://ikzttp.mypinata.cloud/ipfs/QmeBWSnYPEnUimvpPfNHuvgcK9wFH9Sa6cZ4KDfgkfJJis/";
    }

    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

       function _mintFor(
        address to,
        uint256 id,
        bytes calldata blueprint
    ) internal override {
        safeMint(to);
    }
}