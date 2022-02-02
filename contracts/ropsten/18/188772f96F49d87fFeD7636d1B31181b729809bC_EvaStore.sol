// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./Lab.sol";

contract EvaStore is ERC721Enumerable, Ownable, Pausable {
    using Strings for uint256;

    uint256 public MAX_TOKENS = 1000; //Max supply of stores to be minted

    Lab public lab;

    struct Store {
        string name;
    }

    mapping(uint256 => Store) public StoreCollection;

    constructor() ERC721("EvaStore Store", "STORE") {}

    function mint(address _to) public whenNotPaused {
        require(_msgSender() == address(lab), "Only Lab");
        uint256 minted = totalSupply();

        require(minted <= MAX_TOKENS, "Mint ended");

        _safeMint(_to, minted);
        generate(minted);
    }

    function generate(uint256 tokenId) internal {
        Store memory newStore = Store(
            string(abi.encodePacked("STORE #", uint256(tokenId).toString()))
        );

        StoreCollection[tokenId] = newStore;
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
        Store memory token = StoreCollection[_tokenId];
        string memory baseURI = _baseURI();
        return
            string(
                abi.encodePacked(
                    "data:application/json,",
                    abi.encodePacked( //add rarity
                        '{"name":"',
                        token.name,
                        '","uri":',
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
}