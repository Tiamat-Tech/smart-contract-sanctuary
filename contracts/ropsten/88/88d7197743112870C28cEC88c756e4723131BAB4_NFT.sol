pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Base64.sol";

import "hardhat/console.sol";


contract NFT is ERC721Enumerable, Ownable {
    using Strings for uint256;

    struct Word {
        string name;
        string description;
        string message;
        string color;
    }

    mapping (uint256 => Word) public wordsToTokenId;
    uint8 public messageLimit = 15;

    constructor() ERC721("NEW TEST NFT", "TEST2") {}

    function mint(string calldata _message, string calldata _color) external {
        bytes memory messageBytes = bytes(_message);
        require(messageBytes.length <= messageLimit, "message is to long");
        uint256 newTokenID = totalSupply() + 1;

        Word memory newWord = Word(
            string(abi.encodePacked("NFT ", newTokenID.toString())),
            "Test NFT only background and message in the center of image",
            _message,
            _color
        );

        wordsToTokenId[newTokenID] = newWord;

        _safeMint(msg.sender, newTokenID);
    }

    function tokenURI(uint256 _tokenId) public override view returns (string memory) {
        require(_exists(_tokenId), "NO_NFT_WITH_THIS_ID");
        return buildMetadata(_tokenId);
    }

    function buildMetadata(uint256 _tokenId) private view returns (string memory) {
        Word memory _word = wordsToTokenId[_tokenId];
        string memory image = buildImage(_word.message, _word.color);
        console.log(image);
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"',
                            _word.name,
                            '", "description":"',
                            _word.description,
                            '", "image":"',
                            "data:image/svg+xml;base64,",
                            image,
                            '"}'
                        )
                    )
                )
            )
        );
    }

    function buildImage(string memory _message, string memory _color) public pure returns (string memory) {
        return
            Base64.encode(
                bytes(
                    abi.encodePacked(
                        '<svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">',
                        '<circle cx="50" cy="50" r="40" fill="',
                        _color,
                        '"',
                        ' />',
                        '<text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle" fill="white">',
                        _message,
                        '</text>',
                        '</svg>'
                    )
                )
            );
    }
}