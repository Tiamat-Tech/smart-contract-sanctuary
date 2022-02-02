// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./Base64.sol";
import "./FlorToken.sol";
import "./Lab.sol";

contract EvaChemist is ERC721Enumerable, Ownable, Pausable {
    using Strings for uint256;

    uint256 public MAX_TOKENS = 2500;

    Lab public lab;

    struct Chemist {
        string name;
        uint256 boostValue;
        string operator;
        uint256 life;
    }

    mapping(uint256 => Chemist) public Chemists;
    mapping(address => uint256) public chemistOwners;

    constructor() ERC721("ChemistFlore Chemist", "CHEMIST") {}

    function mint(address _to) public whenNotPaused {
        require(msg.sender == address(lab), "Only Lab");
        require(balanceOf(_to) == 0, "Max amount exceeded"); //Ensures and address owns exactly 1 chemist
        uint256 minted = totalSupply();

        require(minted <= MAX_TOKENS, "Mint ended");

        _safeMint(_to, minted);
        generate(minted);
    }

    function generate(uint256 tokenId) internal {
        Chemist memory newChemist = Chemist(
            string(abi.encodePacked("CHEMIST #", uint256(tokenId).toString())),
            randomNum(10, block.difficulty, tokenId) + 1, //Boost value ranges from 1-10
            randomNum(2, block.difficulty, tokenId) == 0 ? "+" : "-",
            randomNum(6, block.difficulty, tokenId) + 1 //Life/utility ranges from 1-6
        );

        Chemists[tokenId] = newChemist;
        chemistOwners[msg.sender] = tokenId;
    }

    function getChemist(uint256 tokenId)
        external
        view
        returns (Chemist memory chemist)
    {
        return Chemists[tokenId];
    }

    function _getChemistOperator(address owner)
        external
        view
        returns (string memory operator)
    {
        uint256 id = chemistOwners[owner];
        return Chemists[id].operator;
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
        Chemist memory token = Chemists[_tokenId];
        string memory baseURI = _baseURI();

        return
            string(
                abi.encodePacked(
                    "data:application/json",
                    abi.encodePacked(
                        '{"name":"',
                        token.name,
                        '", "life":"',
                        token.life,
                        '","operator": "',
                        token.operator,
                        '","boostValue" :"',
                        (token.boostValue).toString(),
                        '","uri":"',
                        string(
                            abi.encodePacked(baseURI, (_tokenId).toString())
                        ),
                        '"}'
                    )
                )
            );
    }

    /*
    @dev
    +Reduces the life of a given chemist
    +callable only by lab

    */
    function _updateChemist(address owner) external {
        require(msg.sender == address(lab), "only lab");
        uint256 id = chemistOwners[owner];
        Chemists[id].life -= 1;
    }

    /*
    @dev
  gets the utility of chemist

    */
    function _getChemistLife(address owner)
        external
        view
        returns (uint256 life)
    {
        uint256 id = chemistOwners[owner];
        return Chemists[id].life;
    }

    function _getChemistBoostValue(address owner)
        external
        view
        returns (uint256 boost)
    {
        uint256 id = chemistOwners[owner];
        return Chemists[id].boostValue;
    }

    function setLab(address _lab) external onlyOwner {
        lab = Lab(_lab);
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
}