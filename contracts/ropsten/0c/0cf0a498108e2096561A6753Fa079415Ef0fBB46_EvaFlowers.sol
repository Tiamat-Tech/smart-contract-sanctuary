// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./Base64.sol";
import "./FlorToken.sol";

import "./Lab.sol";

contract EvaFlowers is ERC721Enumerable, Ownable, Pausable {
    using Strings for uint256;

    uint256 public MAX_TOKENS = 40000; //Max supply of tokens

    uint256 public MINTED_FLOWERS;
    string[] public traits = [
        "Amber",
        "Woody",
        "Flowery",
        "Citrus",
        "Oriental",
        "Fruity"
    ];
    /*Flowers are distributed are follow:
     1500 flowers are going to hold 8 cc
     3000 flowers are going to hold 9 cc
     ....
    */
    uint16[] public flowersDistribution = [
        1500,
        3000,
        6000,
        7500,
        12000,
        3520,
        2200,
        1760,
        440,
        352,
        264,
        176,
        88,
        77,
        77,
        77,
        77,
        66,
        66,
        66,
        66,
        55,
        55,
        55,
        55,
        44,
        44,
        44,
        44,
        33,
        33,
        33,
        33,
        12,
        11,
        10,
        10,
        10,
        10,
        10,
        10,
        10,
        7
    ];
    Lab public lab;

    struct Flower {
        string name;
        uint256 trait;
        uint256 cc;
    }

    mapping(uint256 => Flower) public FlowerCollection;

    constructor() ERC721("EvaFlore Flowers", "FLOWERS") {}

    function mint(address _to) public whenNotPaused {
        require(_msgSender() == address(lab), "Only Lab");

        require(MINTED_FLOWERS <= MAX_TOKENS, "Mint ended");

        _safeMint(_to, MINTED_FLOWERS);
        generate(MINTED_FLOWERS);
        MINTED_FLOWERS++;
    }

    function generate(uint256 tokenId) internal {
        uint256 randomTrait = randomNum(6, block.difficulty, tokenId);
        uint256 numberOfCC = generateRandomCC(tokenId);
        Flower memory newflower = Flower(
            string(abi.encodePacked("Flower #", uint256(tokenId).toString())),
            randomTrait,
            numberOfCC
        );

        FlowerCollection[tokenId] = newflower;
    }

    function getFlowerCC(uint256 tokenId) external view returns (uint256) {
        return FlowerCollection[tokenId].cc;
    }

    /*
@Dev
Gets a random cc based on the flowers distribution
*CC values start from 8 to 50 
*Total numnber of cc values is 43
*The flowersDistribution array is indexed from 0 to 42
*Returns a random number from 0 to 42 and adds up 8 to round it to a correct cc value
*After a cc value is allocated to a flower we decrease the number of flowers allowed to havesame value
*/

    function generateRandomCC(uint256 _tokenId)
        internal
        returns (uint256 value)
    {
        uint256 random = randomNum(43, block.difficulty, _tokenId);
        uint256 ccValue = random + 8;
        if (flowersDistribution[random] > 0) {
            flowersDistribution[random] = flowersDistribution[random] - 1;
            return ccValue;
        } else {
            generateRandomCC(random + 1);
        }
    }

    function getFlowerTraitIndex(uint256 tokenId)
        external
        view
        returns (uint256)
    {
        return FlowerCollection[tokenId].trait;
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

    function _baseURI() internal view virtual override returns (string memory) {
        return "https://ipfs.io/ipfs/";
    }

    function buildMetadata(uint256 _tokenId)
        public
        view
        returns (string memory)
    {
        Flower memory token = FlowerCollection[_tokenId];
        string memory baseURI = _baseURI();
        return
            string(
                abi.encodePacked(
                    "data:application/json,",
                    abi.encodePacked(
                        '{"name":"',
                        token.name,
                        '", "trait":"',
                        traits[token.trait],
                        '","uri":"',
                        string(
                            abi.encodePacked(baseURI, (_tokenId).toString())
                        ),
                        '"}'
                    )
                )
            );
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

    function burnExtraFlower(uint256 tokenId) external {
        require(msg.sender == address(lab), "only lab");
        _burn(tokenId);
    }

    function burnBatchFlowers(uint256[] calldata tokenIds) external {
        require(msg.sender == address(lab), "only lab");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _burn(tokenIds[i]);
        }
    }
}