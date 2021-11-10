// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Testerboi is ERC721Enumerable, Ownable {
    using ECDSA for bytes32;

    // The address of the wallet used to authenticate mint requests.
    address private SIGNER_ADDRESS = 0x2c83f281C169f4b6E7F9cE30934a747C9995770E;
    // The mint price.
    uint256 public MINT_PRICE = 0.03 ether;
    // The minimum acceptable value that the mint price can be set to.
    uint256 public MINT_PRICE_FLOOR = 0.0001 ether;
    // The maximum acceptable value that the mint price can be set to.
    uint256 public MINT_PRICE_CEIL = 1 ether;
    // The base metadata URI.
    string private BASE_URI = "ipfs://yolo";
    // The set of nonces that have already been consumed.
    mapping(uint256 => bool) private USED_NONCES;

    constructor() ERC721("Testerboi", "TBI") { }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function _baseURI() internal view override returns (string memory) {
        return BASE_URI;
    }

    /**
     * @dev Hash a nonce so that we can validate a signature passed by the minter.
     */
    function hashNonce(uint256 nonce) private pure returns(bytes32) {
        bytes32 hash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            keccak256(abi.encodePacked(nonce)))
        );
        return hash;
    }

    /**
     * @dev Verify that the address that signed the given hash is the same as our configured signing address.
     */
    function matchAddresSigner(bytes32 hash, bytes memory signature) private view returns(bool) {
        return SIGNER_ADDRESS == hash.recover(signature);
    }

    /**
     * @dev Mint a token, given a signature and a nonce.
     */
    function mint(bytes memory signature, uint256 nonce) external payable {
        require(msg.value >= MINT_PRICE, "Insufficient Funds");
        require(matchAddresSigner(hashNonce(nonce), signature), "Invalid Code");
        require(!USED_NONCES[nonce], "Code Already Redeemed");
        USED_NONCES[nonce] = true;

        _safeMint(msg.sender, nonce);
    }

    /**
     * @dev Update the signer address used to authenticate mint requests.
     */
    function setSignerAddress(address addr) external onlyOwner {
        SIGNER_ADDRESS = addr;
    }

    /**
     * @dev Update the mint price to the given value, provided it is within the configured acceptable bounds.
     */
    function setMintPrice(uint256 price) external onlyOwner {
        require(price >= MINT_PRICE_FLOOR, "Mint price < 0.0001 eth, did you pass a value in wei?");
        require(price <= MINT_PRICE_CEIL, "Mint price > 1 eth, did you pass a value in wei?");
        MINT_PRICE = price;
    }

    /**
     * @dev Update the base URI for this contract to the given value.
     */
    function setBaseURI(string memory __baseURI) external onlyOwner {
        BASE_URI = __baseURI;
    }
}