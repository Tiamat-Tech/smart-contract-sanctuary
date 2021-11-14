// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract RareBears is ERC721, ERC721Enumerable, AccessControlEnumerable {
    using Counters for Counters.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    Counters.Counter private _tokenIdCounter;
    

    constructor() ERC721("RareBears", "BEAR") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://gateway.pinata.cloud/ipfs/QmQPmTfBbGs2z2aFHupcbcaAU6qFrqGGvYCWjGm2XLGNUE/";
    }

    function allowMintMulti(address[] memory accounts) external onlyRole(DEFAULT_ADMIN_ROLE) { //whitelisting loop
        for (uint256 account = 0; account < accounts.length; account++) {
            grantRole(MINTER_ROLE, accounts[account]);
        }
    }

    function safeMint(address to) public payable onlyRole(MINTER_ROLE) {
        require(msg.value >= 25000000000000000, "Not enough ETH sent; check price!"); // 25000000000000000 wei == 0.025 eth

        renounceRole(MINTER_ROLE, to); // one and done

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    function withdrawAll() external onlyRole(DEFAULT_ADMIN_ROLE) {
        payable(msg.sender).transfer(address(this).balance);
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControlEnumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}