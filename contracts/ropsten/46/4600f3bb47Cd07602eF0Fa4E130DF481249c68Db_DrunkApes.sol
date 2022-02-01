// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


/// @custom:security-contact [email protected]
contract DrunkApes is ERC721, ERC721Enumerable, Pausable, AccessControl {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 public MAX_SUPPlY;

    uint public constant MAX_TOKENS_PURCHASE = 5;

    Counters.Counter private _tokenIdCounter;

    uint256 public PRESALE_TIME;
    uint256 public RELEASE_TIME;

    uint MAX_WHITELIST_LENGTH = 10;

    uint256 public constant TOKEN_PRICE = 10000000000000000; //0.01 ETH

    constructor(uint256 maxSupply, uint256 preSaleTime, uint256 releaseTime, address[] memory whitelistedAddresses)
    ERC721("DrunkApes", "DAPS")
    {

        require(preSaleTime <= releaseTime, "pre-sale cannot happen after release");
        require(whitelistedAddresses.length <= MAX_WHITELIST_LENGTH, "exceeded whitelist limitation number");

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);

        for (uint i = 0; i != whitelistedAddresses.length; i++) {
            _grantRole(MINTER_ROLE, whitelistedAddresses[i]);
        }

        MAX_SUPPlY = maxSupply;
        PRESALE_TIME = preSaleTime;
        RELEASE_TIME = releaseTime;
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

    function safeMint(uint numberOfTokens) public payable whenNotPaused {

        require(block.timestamp >= PRESALE_TIME, "pre-sale has not started yet");

        if (block.timestamp >= PRESALE_TIME && block.timestamp < RELEASE_TIME) {
            require(hasRole(MINTER_ROLE, msg.sender), "public minting is not started yet");
        }

        require(numberOfTokens > 0, "cannot mint zero tokens");
        require(numberOfTokens <= MAX_TOKENS_PURCHASE, "exceeded purchase limit");
        require(totalSupply().add(numberOfTokens) <= MAX_SUPPlY, "purchase would exceed max supply");
        require(TOKEN_PRICE.mul(numberOfTokens) <= msg.value, "ether value is not correct");

        if (hasRole(MINTER_ROLE, msg.sender)) {
            renounceRole(MINTER_ROLE, msg.sender);
        }


        for (uint i = 0; i < numberOfTokens; i++) {
            uint mintIndex = totalSupply();
            if (totalSupply() < MAX_SUPPlY) {
                _safeMint(msg.sender, mintIndex);
            }
        }

    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
    internal
    whenNotPaused
    override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function withdraw() public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
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