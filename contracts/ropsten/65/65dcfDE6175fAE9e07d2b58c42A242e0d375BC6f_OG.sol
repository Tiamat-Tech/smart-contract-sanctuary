// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";

contract OG is ERC721 {
    address private owner;
    using ECDSA for bytes32;
    
    constructor(string memory name, string memory symbol, string memory baseURI, address _owner) ERC721(name, symbol) {
        _owner = owner;
        _setBaseURI(baseURI);
    }

    function mint(address to, bytes memory signature) public virtual {
        address signer = keccak256(abi.encode(to))
            .toEthSignedMessageHash()
            .recover(signature);

        require(signer == owner, "Incorrect signature");

        string memory suffix = ".json";
        uint256 index = totalSupply();

        _mint(to, index);
        _setTokenURI(index, string(abi.encodePacked(to, suffix)));
    }
}