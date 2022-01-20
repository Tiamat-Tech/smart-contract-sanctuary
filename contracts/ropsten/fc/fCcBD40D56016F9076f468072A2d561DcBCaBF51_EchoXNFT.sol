// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./token/ERC721Preset.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract EchoXNFT is ERC721Preset {
    using Strings for uint256;
    using Counters for Counters.Counter;

    event Mint(address owner, uint256 tokenId, uint256 _activityId);

    event NFTTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 timestamp
    );

    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) ERC721Preset(name, symbol, baseTokenURI) {}

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "EchoXNFT: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(
                    abi.encodePacked(
                        baseURI,
                        tokenId.toString(),
                        "/metadata.json"
                    )
                )
                : "";
    }

    function getAllTokenIdByAddress(address owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 balance = balanceOf(owner);
        require(balance != 0, "EchoXNFT: Owner has no token");
        uint256[] memory res = new uint256[](balance);

        for (uint256 i = 0; i < balance; i++) {
            res[i] = this.tokenOfOwnerByIndex(owner, i);
        }

        return res;
    }

    function setBaseTokenURI(string memory baseTokenURI) public {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "EchoXNFT: Only DEFAULT_ADMIN_ROLE can modify baseTokenURI"
        );
        _baseTokenURI = baseTokenURI;
    }

    function mint(address to, uint256 _activityId) public returns (uint256) {
        uint256 tokenId = _tokenIdTracker.current();
        mint(to);

        emit Mint(to, tokenId, _activityId);
        return tokenId;
    }

    function _mint(address to, uint256 tokenId) internal virtual override {
        super._mint(to, tokenId);
        emit NFTTransfer(address(0), to, tokenId, block.timestamp);
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        super._transfer(from, to, tokenId);
        emit NFTTransfer(from, to, tokenId, block.timestamp);
    }
}