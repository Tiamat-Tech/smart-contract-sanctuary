// //Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "@openzeppelin/contracts/utils/Counters.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

// contract MyNFT is ERC721URIStorage, Ownable {
//     using Counters for Counters.Counter;
//     Counters.Counter private _tokenIds;
//     string public saySomething;
//     uint256 public minRate = 0.01 ether;

//     constructor() ERC721("MyNFT", "NFT") {
//         saySomething = "Hello World!";
//     }

//     function mintNFT(address to, string memory tokenURI)
//         public payable
//         returns (uint256)
//     {
//         require(msg.value >= minRate, "not engoth ether sent");
//         _tokenIds.increment();

//         uint256 newItemId = _tokenIds.current();
//         _mint(to, newItemId);
//         _setTokenURI(newItemId, tokenURI);

//         return newItemId;
//     }
// }

//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MyNFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    string public saySomething;
    uint256 public minRate = 0.01 ether;
    uint256 public publicSalesStartTime;
    bool public publicSaleStarted;

    constructor() ERC721("MyNFT", "NFT") {
        saySomething = "Hello World!";
    }

    function setPublicSalesTime(uint256 _startTime) public {
        publicSalesStartTime = _startTime;
    }

    function startPublicSale(bool start) public {
        publicSaleStarted = start;
    }

    function mintNFT(uint256 _mintQty) public payable {
        require(msg.value * _mintQty >= minRate, "not engoth ether sent");
        require(
            publicSalesStartTime > 0 && block.timestamp >= publicSalesStartTime,
            "Not time yet"
        );
        for (uint256 i = 0; i < _mintQty; i++) {
            _tokenIds.increment();
            _mint(msg.sender, _tokenIds.current());
        }
    }

    function mintNFT1(uint256 _mintQty) public payable {
        require(msg.value * _mintQty >= minRate, "not engoth ether sent");
        require(publicSaleStarted, "Not started yet");
        for (uint256 i = 0; i < _mintQty; i++) {
            _tokenIds.increment();
            _mint(msg.sender, _tokenIds.current());
        }
    }

    function mintNFT2(uint256 _mintQty, bytes32[] calldata proof)
        public
        payable
    {
        require(msg.value * _mintQty >= minRate, "not engoth ether sent");
        for (uint256 i = 0; i < _mintQty; i++) {
            _tokenIds.increment();
            _mint(msg.sender, _tokenIds.current());
        }
    }
}