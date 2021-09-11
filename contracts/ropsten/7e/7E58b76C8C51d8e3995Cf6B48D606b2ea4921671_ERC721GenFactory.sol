// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@rarible/royalties/contracts/impl/RoyaltiesV2Impl.sol";
import "@rarible/royalties-upgradeable/contracts/RoyaltiesV2Upgradeable.sol";

import "./interfaces/IERC721GenMint.sol";
import "./tokens/ERC721GenDefaultApproval.sol";
import "./tokens/ERC721GenOperatorRole.sol";
import "./traits/TraitsManager.sol";
import "./utils/AddAddrToURI.sol";

contract ERC721Gen is OwnableUpgradeable, ERC721GenDefaultApproval, RoyaltiesV2Upgradeable, RoyaltiesV2Impl, TraitsManager, AddAddrToURI, ERC721GenOperatorRole, IERC721GenMint {
    using SafeMathUpgradeable for uint;

    event GenArtTotal(uint total);
    event GenArtMint(uint tokenId, uint[] traits);

    uint public total;
    uint public minted;
    uint public maxValue;

    mapping(uint => uint) mintingBlocks;
    mapping(uint => uint[]) tokenTraits;
    LibPart.Part[] collectionRoyalties;

    function __ERC721Gen_init(
        string memory _name, 
        string memory _symbol,
        string memory _baseURI, 
        address _transferProxy,
        address _operatorProxy,
        LibPart.Part[] memory _royalties,
        Trait[] memory _traits, 
        uint _total,
        uint _maxValue
    ) external initializer {
        _setBaseURI(addTokenAddrToBaseURI(_baseURI, address(this)));
        __RoyaltiesV2Upgradeable_init_unchained();
        __Context_init_unchained();
        __ERC165_init_unchained();
        __Ownable_init_unchained();
        __ERC721_init_unchained(_name, _symbol);
        __TraitsManager_init_unchained(_traits);
        __ERC721GenDefaultApproval_init_unchained(_transferProxy);
        __ERC721GenOperatorRole_init_unchained(_operatorProxy);
        __ERC721Gen_init_unchained(_royalties, _total, _maxValue);
    }

    function __ERC721Gen_init_unchained(LibPart.Part[] memory _royalties, uint _total, uint _maxValue) internal initializer {
        for (uint i = 0; i < _royalties.length; i++) {
            require(_royalties[i].account != address(0x0), "Recipient should be present");
            require(_royalties[i].value != 0, "Royalty value should be positive");
            collectionRoyalties.push(_royalties[i]);
        }
        maxValue = _maxValue;
        total = _total;
        emit GenArtTotal(total);
    }

    function mint(address artist, address to, uint value) onlyOperator() override public returns (uint[] memory) {
        require(value <= maxValue, "value of tokens to mint is too big");
        require(artist == owner(), "artist is not an owner");
        require(minted.add(value) <= total, "all minted");

        uint[] memory mintedTokens = new uint[](value);

        for (uint i = 0; i < value; i ++) {
            mintedTokens[i] = mintSingleToken(to);
        }

        return mintedTokens;
    }

    function mintSingleToken(address to) internal returns(uint) {

        minted = minted + 1;
        uint[] memory generated = generateRandomTraits();
        uint tokenId = random(0);
        _safeMint(to, tokenId);
        tokenTraits[tokenId] = generated;
        mintingBlocks[tokenId] = block.number;

        _saveRoyalties(tokenId, collectionRoyalties);

        emit GenArtMint(tokenId, generated);
        return tokenId;
    }

    function getTokenTraits(uint tokenId) view public returns (uint[] memory) {
        require(block.number > mintingBlocks[tokenId], "can't read traits in the same block");
        return tokenTraits[tokenId];
    }

    uint256[50] private __gap;
}