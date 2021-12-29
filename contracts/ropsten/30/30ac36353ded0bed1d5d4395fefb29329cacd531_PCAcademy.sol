// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

import "./ERC2981ContractWideRoyalties.sol";

contract PCAcademy is ERC721, ERC721Enumerable, Pausable, AccessControl, ERC2981ContractWideRoyalties {
    using Counters for Counters.Counter;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant AIRDROP_ROLE = keccak256("AIRDROP_ROLE");
    bytes32 public constant ALLOWLIST_MOD_ROLE = keccak256("ALLOWLIST_MOD_ROLE");
    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _reserveCounter;
    Counters.Counter private _publicCounter;

    uint public constant maxPurchase = 1;
    uint public constant maxTokens = reservedSupply + publicSupply;
    uint public constant reservedSupply = 1000;
    uint public constant publicSupply = 9000;
    bool public publicMint = false;
    uint256 public constant tokenPrice = 0;


    constructor() ERC721("Coin", "COIN") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(AIRDROP_ROLE, msg.sender);
        _grantRole(ALLOWLIST_MOD_ROLE, msg.sender);
        //_pause();

    }

    function batchAllowlist(address[] memory addresses) public onlyRole(ALLOWLIST_MOD_ROLE) {
        require(addresses.length > 0, "E001");

        for (uint256 i = 0; i < addresses.length; i++) {
            _grantRole(MINTER_ROLE, addresses[i]);
        }

    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://ipfs.fleek.co/ipfs/QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn/";
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function flipPublicMint() public onlyRole(DEFAULT_ADMIN_ROLE) {
        publicMint = !publicMint;
    }

    function airDrop(address to, uint numberOfTokens) public onlyRole(AIRDROP_ROLE) {
        require((_reserveCounter.current() + numberOfTokens) <= reservedSupply, "E002");
        require((_tokenIdCounter.current() + numberOfTokens) <= maxTokens, "E003");

        for(uint i = 0; i < numberOfTokens; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _reserveCounter.increment();
            _safeMint(to, tokenId);
        }
    }


    function publicMintToken(address to, uint numberOfTokens) public payable {
        require(publicMint, "E008");
        require(numberOfTokens <= maxPurchase, "E004");
        require((tokenPrice * numberOfTokens) <= msg.value, "E005");
        require((_publicCounter.current() + numberOfTokens) <= publicSupply, "E006");
        require((_tokenIdCounter.current() + numberOfTokens) <= maxTokens, "E007");

        for(uint i = 0; i < numberOfTokens; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _publicCounter.increment();
            _safeMint(to, tokenId);
        }
    }

    /**
    * @dev Remove onlyRole to make public mint
    */
    function mintToken(address to, uint numberOfTokens) public payable onlyRole(MINTER_ROLE) {
        require(numberOfTokens <= maxPurchase, "E004");
        require((tokenPrice * numberOfTokens) <= msg.value, "E005");
        require((_publicCounter.current() + numberOfTokens) <= publicSupply, "E006");
        require((_tokenIdCounter.current() + numberOfTokens) <= maxTokens, "E007");

        for(uint i = 0; i < numberOfTokens; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _publicCounter.increment();
            _safeMint(to, tokenId);
        }
        if (!hasRole(ALLOWLIST_MOD_ROLE, msg.sender)) {
            _revokeRole(MINTER_ROLE, msg.sender);
        }

    }


    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function getReserved() external view returns(uint256) {
        return _reserveCounter.current();
    }
    function getPublic() external view returns(uint256) {
        return _publicCounter.current();
    }

    /// @notice Allows to set the royalties on the contract
    /// @dev This function in a real contract should be protected with a onlOwner (or equivalent) modifier
    /// @param recipient the royalties recipient
    /// @param value royalties value (between 0 and 10000)
    function setRoyalties(address recipient, uint256 value) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setRoyalties(recipient, value);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl, ERC2981Base)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}