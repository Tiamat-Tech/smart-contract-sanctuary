//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "./IAVADONFT.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMinter is Ownable {

    IAVADONFT AVADONFT;
    // track used hashes
    mapping(bytes32 => bool) usedhashes;

    constructor(IAVADONFT _NFTContract) {
        AVADONFT = _NFTContract;
    }

    function claimNFT(
        address _recipient,
        uint256 _seed,
        uint256 _key,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public returns (bytes32) {
        bytes32 hash = sha256(abi.encode(_seed, _key));
        require((ecrecover(hash, _v, _r, _s) == owner()),"Signature is wrong");
        require(usedhashes[hash] != true,"Hash already used");

        // invalidate this hash
        usedhashes[hash] = true;

        AVADONFT.Mint(_recipient, _seed);

    }
}