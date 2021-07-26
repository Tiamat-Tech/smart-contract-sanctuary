//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract YourNFToken is ERC721PresetMinterPauserAutoId {
    using ECDSA for bytes32;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct NFT_MODEL {
        string ipfsHash;
    }

    NFT_MODEL[] private tokens;

    uint256 private price;
    address platformAddress = 0xC140ef980d369B023180d2544b1a0f80B4eA5cb0;

    modifier adminOnly() {
        require(
            hasRole(ADMIN_ROLE, msg.sender),
            "MelonMarketplace: caller is not an admin!"
        );
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        address _admin,
        uint256 _mintPrice
    ) ERC721PresetMinterPauserAutoId(_name, _symbol, _baseURI) {
        price = _mintPrice;
        _setupRole(ADMIN_ROLE, _admin);
    }

    function _verifyHashes(string[] memory ipfsHashes, bytes calldata sign)
        internal
        view
        returns (bool)
    {
        bytes32 b = keccak256(abi.encode(ipfsHashes));
        return b.toEthSignedMessageHash().recover(sign) == platformAddress;
    }

    function mintToken(
        uint8 amount,
        address to,
        string[] memory ipfsHashes,
        bytes calldata signedHashes
    ) external payable {
        require(amount > 0, "YourNFToken: amount can't be even or zero!");
        require(amount <= 20, "YourNFToken: amount must be less then 20!");
        require(msg.value >= price, "YourNFToken: insufficient funds!");
        require(
            _verifyHashes(ipfsHashes, signedHashes),
            "YourNFToken: hashes sign is not valid!"
        );
        require(
            ipfsHashes.length == amount,
            "YourNFToken: array of hashes must be the same length as the amount!"
        );
        require(
            tokens.length <= 7000,
            "YourNFToken: overall maximum of NFTs (7000) has been reached!"
        );

        for (uint256 index = 0; index < amount; index++) {
            _tokenIds.increment();
            uint256 newTokenId = _tokenIds.current();
            require(
                !_exists(newTokenId),
                "MelonMarketplace: one of this tokens are already exists!"
            );
            _mint(to, newTokenId);

            tokens[newTokenId].ipfsHash = ipfsHashes[index];
        }
    }

    function mintTokenAdmin(
        uint8 amount,
        address to,
        string[] memory ipfsHashes,
        bytes calldata signedHashes
    ) external payable adminOnly {
        require(amount > 0, "YourNFToken: amount can't be even or zero!");
        require(amount <= 20, "YourNFToken: amount must be less then 20!");
        require(msg.value >= price, "YourNFToken: insufficient funds!");
        require(
            _verifyHashes(ipfsHashes, signedHashes),
            "YourNFToken: hashes sign is not valid!"
        );
        require(
            ipfsHashes.length == amount,
            "YourNFToken: array of hashes must be the same length as the amount!"
        );
        require(
            tokens.length <= 7100,
            "YourNFToken: overall maximum of NFTs (7100) has been reached!"
        );

        for (uint256 index = 0; index < amount; index++) {
            _tokenIds.increment();
            uint256 newTokenId = _tokenIds.current();
            require(
                !_exists(newTokenId),
                "MelonMarketplace: one of this tokens are already exists!"
            );
            _mint(to, newTokenId);

            tokens[newTokenId].ipfsHash = ipfsHashes[index];
        }
    }

    function setPrice(uint256 newPrice) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender),
            "YourNFToken: caller is not an admin!"
        );
        price = newPrice;
    }

    function grantAdminRole(address account) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender),
            "YourNFToken: caller is not an admin!"
        );
        grantRole(ADMIN_ROLE, account);
    }

    function revokeAdminRole(address account) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender),
            "YourNFToken: caller is not an admin!"
        );
        revokeRole(ADMIN_ROLE, account);
    }

    function getTokenByID(uint256 id) external view returns (NFT_MODEL memory) {
        return tokens[id];
    }

    function getAllTokens() external view returns (NFT_MODEL[] memory) {
        return tokens;
    }

    function getAllTokensAmountMinted() external view returns (uint256) {
        return tokens.length;
    }
}