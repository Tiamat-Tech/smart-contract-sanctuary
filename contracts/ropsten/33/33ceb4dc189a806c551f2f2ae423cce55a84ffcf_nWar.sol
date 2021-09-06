// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../core/NPass.sol";
import "../interfaces/IN.sol";

/**
 * @title nWar contract
 * @author Maximonee (twitter.com/maximonee_)
 * @notice This contract allows n project holders to mint a nWar NFT for their corresponding n
 */
contract nWar is NPass {
    using Strings for uint256;

    constructor(
        string memory name,
        string memory symbol,
        bool onlyNHolders
    ) NPass(name, symbol, onlyNHolders) {}

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json")) : "";
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "https://gateway.pinata.cloud/ipfs/Qme4eA1NdZqU6jTyFgyecHmSaYY2yGoD922GpYjwKTco5Q/";
    }
}