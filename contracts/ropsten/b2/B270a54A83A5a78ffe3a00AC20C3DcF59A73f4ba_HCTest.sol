// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

/// @custom:security-contact [email protected]
contract HCTest is ERC721, ERC721Enumerable, Pausable, AccessControl {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 public MAX_SUPPlY = 20;

    uint public constant MAX_PER_TX = 5;

    Counters.Counter private _tokenIdCounter;

    bool public preSaleState = false;
    bool public publicSaleState = false;

    uint256 public constant PRESALE_PRICE = 0.01 ether;
    uint256 public constant PUBLIC_PRICE = 0.02 ether;
    uint256 public price;

    address[8] public whitelistedAddresses = [
        0x2a7186F4f38766de45757d278565B7eA83a0dD38,
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x356c8eb739Db80bB92DE0E0e1d44648315FbFF1C,
        0xe9A439fcEdBd1C4a46B7F34748a08a0D6a1366BB,
        0xb468eAc49b7cecaB47dac263b06b48b59439ec53,
        0x8fb557b9e2E8bA9a44dd30A1c14cd1ca68424e41,
        0x1fB84A8ab8c73762ac302E8f6dcf79bf3035ceA2
    ];

    constructor() ERC721("HCTest", "HCTest") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);

        for (uint i = 0; i != whitelistedAddresses.length; i++) {
            _grantRole(MINTER_ROLE, whitelistedAddresses[i]);
        }
    }

    function safeMint(uint numberOfTokens) external payable whenNotPaused {
        require(preSaleState == true, "presale not started");
        require(numberOfTokens > 0, "zero tokens");
        require(numberOfTokens <= MAX_PER_TX, "exceeded tx limit");
        require(totalSupply().add(numberOfTokens) <= MAX_SUPPlY, "would exceed max supply");
        require(price.mul(numberOfTokens) <= msg.value, "wrong value");

        if (publicSaleState == false) {
            require(hasRole(MINTER_ROLE, msg.sender), "address not whitelisted");
            renounceRole(MINTER_ROLE, msg.sender);
        }

        for (uint i = 0; i < numberOfTokens; i++) {
            uint mintIndex = totalSupply();
            if (totalSupply() < MAX_SUPPlY) {
                _safeMint(msg.sender, mintIndex);
            }
        }
    }

    function startPreSale() external onlyRole(DEFAULT_ADMIN_ROLE) {
        price = PRESALE_PRICE;
        publicSaleState = false;
        preSaleState = true;
    }

    function startPublicSale() external onlyRole(DEFAULT_ADMIN_ROLE) {
        price = PUBLIC_PRICE;
        preSaleState = true;
        publicSaleState = true;
    }

    function stopSale() external onlyRole(DEFAULT_ADMIN_ROLE) {
        preSaleState = false;
        publicSaleState = false;
    }

    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://bafybeihpjhkeuiq3k6nqa3fkgeigeri7iebtrsuyuey5y6vy36n345xmbi/";
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
    internal
    whenNotPaused
    override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable, AccessControl)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}