// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

interface IRibbonHatToken {
    function balanceOf(address) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external;
}

contract RibbonHat is ERC721, Pausable, AccessControl, ERC721Burnable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    mapping(address => bool) public whitelist;
    IRibbonHatToken public rhatAddress;

    constructor(address rhatContractAddress) ERC721("RibbonHat", "TTRHAT") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        rhatAddress = IRibbonHatToken(rhatContractAddress);
        // TODO: Initiate whitelist
    }

    modifier onlyRhatHolder(address requester) {
        // TODO: Check whether sender has a RHAT ERC20
        // token or is part of the whitelist
        require(rhatAddress.balanceOf(requester) > 0 || whitelist[requester], "not a rhat holder");
        _;
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        // same hat for everyone
        return "https://gateway.pinata.cloud/ipfs/QmZsEQHMFadB6kmDKKjPDRab9N7qDZL45AAVam22hCbCRj";
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function safeMint(address to, uint256 tokenId) public onlyRhatHolder(to) {
        // transfer RHAT ERC20 token to this contract
        rhatAddress.transferFrom(to, address(this), 1);
        // mint RHAT NFT for the RHAT holder
        _safeMint(to, tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}