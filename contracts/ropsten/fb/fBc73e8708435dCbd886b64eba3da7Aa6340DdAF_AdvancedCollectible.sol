// contracts/AdvancedCollectible.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract AdvancedCollectible is VRFConsumerBase, ERC721URIStorage, Ownable {
    bytes32 internal keyHash;
    uint256 public fee;
    uint256 public tokenCounter;
    string private baseUrl;
    mapping(bytes32 => address) public requestIdToSender;
    mapping(bytes32 => string) public requestIdToTokenURI;
    mapping(uint256 => Breed) public tokenIdToBreed;
    mapping(bytes32 => uint256) public requestIdToTokenId;

    enum Breed {
        a,
        b,
        c
    }

    event CequestedCollctible(bytes32 indexed requestId);

    constructor(
        address _vrfCoordinator,
        address _linkToken,
        bytes32 _keyhash
    )
        VRFConsumerBase(_vrfCoordinator, _linkToken)
        ERC721("AdvancedCollectible", "AC")
    {
        keyHash = _keyhash;
        fee = 0.1 * 10**18; // 0.1 LINK 1000000000000000000
        tokenCounter = 0;
    }

    function createCollectible(string memory tokenURI)
        public
        returns (bytes32)
    {
        bytes32 requestId = requestRandomness(keyHash, fee);

        requestIdToSender[requestId] = msg.sender;
        requestIdToTokenURI[requestId] = tokenURI;

        emit CequestedCollctible(requestId);

        return requestId;
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomNumber)
        internal
        override
    {
        address nftOwner = requestIdToSender[requestId];
        string memory tokenURI = requestIdToTokenURI[requestId];
        uint256 newItemId = tokenCounter;
        _safeMint(nftOwner, newItemId);
        _setTokenURI(newItemId, tokenURI);

        Breed breed = Breed(randomNumber % 3);
        tokenIdToBreed[newItemId] = breed;
        requestIdToTokenId[requestId] = newItemId;
        tokenCounter = tokenCounter + 1;
    }

    function setTokenURT(uint256 tokenId, string memory _tokenURI) public {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );
        _setTokenURI(tokenId, _tokenURI);
    }

    function setBaseURL(string memory _baseURL) external onlyOwner {
        baseUrl = _baseURL;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseUrl;
    }
}