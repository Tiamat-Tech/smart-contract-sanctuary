// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Testerboi is ERC721Enumerable, Ownable {
    using ECDSA for bytes32;

    address private _signerAddress = 0x2c83f281C169f4b6E7F9cE30934a747C9995770E;

    // Default empty token URI. To be updated after mint for reveal via the setBaseURI method.
    string private baseURI = "ipfs://yolo";
    mapping(string => bool) private _usedNonces;

    constructor() ERC721("Testerboi", "TBI") { }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    // verify whether hash matches against tampering; use of others' minting opportunity, diff mint count etc
    function hashTransaction(string memory nonce) private pure returns(bytes32) {
        bytes32 hash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            keccak256(abi.encodePacked(nonce)))
        );
        return hash;
    }

    // match serverside private key sign to set pub key
    function matchAddresSigner(bytes32 hash, bytes memory signature) private view returns(bool) {
        return _signerAddress == hash.recover(signature);
    }

    // not payable for snippet
    function mint(bytes memory signature, string memory nonce) external {
        require(matchAddresSigner(hashTransaction(nonce), signature), "Invalid Signature");
        require(!_usedNonces[nonce], "Code Already Redeemed");
        _usedNonces[nonce] = true;

        _safeMint(msg.sender, totalSupply() + 1);
    }

    // change public key for relaunches so signatures get invalidated
    function setSignerAddress(address addr) external onlyOwner {
        _signerAddress = addr;
    }

    /**
     * Update the base URI for this contract to the given value.
     */
    function setBaseURI(string memory __baseURI) external onlyOwner {
        baseURI = __baseURI;
    }
}