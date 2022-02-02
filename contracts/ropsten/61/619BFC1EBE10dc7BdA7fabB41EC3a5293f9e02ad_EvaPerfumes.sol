// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./FlorToken.sol";
import "./Lab.sol";

contract EvaPerfumes is ERC721Enumerable, Ownable, Pausable {
    using Strings for uint256;

    uint256 public MAX_TOKENS = 9000; //Max supply of perfumes to be minted ever

    uint256 public MINTED_PERFUMS;
    Lab public lab;

    string[] public traits = [
        "Amber",
        "Woody",
        "Flowery",
        "Citrus",
        "Oriental",
        "Fruity"
    ];
    struct Perfum {
        string name;
        string trait;
    }

    mapping(uint256 => Perfum) public PerfumCollection;

    constructor() ERC721("EvaFlore Perfumes", "PERFUM") {}

    function mint(
        address _to,
        bool withKnownTrait,
        uint256 traitIndex
    ) public whenNotPaused {
        require(_msgSender() == address(lab), "Only Lab");

        require(MINTED_PERFUMS <= MAX_TOKENS, "Mint ended");

        _safeMint(_to, MINTED_PERFUMS);
        if (withKnownTrait) {
            generateWithKnownTrait(MINTED_PERFUMS, traitIndex);
        } else {
            generate(MINTED_PERFUMS);
        }
        MINTED_PERFUMS++;
    }

    function generate(uint256 tokenId) internal {
        uint256 randomTrait = randomNum(6, block.difficulty, tokenId);
        Perfum memory newPerfum = Perfum(
            string(abi.encodePacked("Perfum #", uint256(tokenId).toString())),
            traits[randomTrait]
        );

        PerfumCollection[tokenId] = newPerfum;
    }

    function generateWithKnownTrait(uint256 tokenId, uint256 traitIndex)
        internal
    {
        Perfum memory newPerfum = Perfum(
            string(abi.encodePacked("Perfum #", uint256(tokenId).toString())),
            traits[traitIndex]
        );

        PerfumCollection[tokenId] = newPerfum;
    }

    function randomNum(
        uint256 _mod,
        uint256 _salt,
        uint256 _seed
    ) public view returns (uint256) {
        uint256 num = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    msg.sender,
                    block.number,
                    _salt,
                    _seed
                )
            )
        ) % _mod;
        return num;
    }

    function buildMetadata(uint256 _tokenId)
        public
        view
        returns (string memory)
    {
        Perfum memory token = PerfumCollection[_tokenId];
        string memory baseURI = _baseURI();
        return
            string(
                abi.encodePacked(
                    "data:application/json,",
                    abi.encodePacked( //add rarity
                        '{"name":"',
                        token.name,
                        '", "trait":"',
                        token.trait,
                        '","uri":"',
                        string(
                            abi.encodePacked(baseURI, (_tokenId).toString())
                        ),
                        '"}'
                    )
                )
            );
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "https://ipfs.io/ipfs/";
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        return buildMetadata(_tokenId);
    }

    function setLab(address _lab) external onlyOwner {
        lab = Lab(_lab);
    }

    function burnBatchPerfumes(uint256[] calldata tokenIds) external {
        require(msg.sender == address(lab), "only lab");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _burn(tokenIds[i]);
        }
    }
}