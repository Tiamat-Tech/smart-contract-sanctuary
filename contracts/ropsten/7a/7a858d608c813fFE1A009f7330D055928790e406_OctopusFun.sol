//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract OctopusFun is ERC721URIStorage {//, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256[] public aliveNFTs;
    uint256[] public deadNFTs;
    mapping(address => uint256) public addressToNFTToken;

    uint256 public constant MAX_OCTOPUS_FUN_TOKENS = 456;
    uint256 public constant COST_TO_MINT = 1000000000000000000; // 0.1 Ether

    constructor() ERC721("OctopusFun", "OCF") {}

    function mintNFT(address recipient, string memory tokenURI)
        external
        payable
        returns (uint256)
    {
        require(COST_TO_MINT <= msg.value, "Ether value sent is not correct");
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        aliveNFTs.push(newItemId);
        _safeMint(recipient, newItemId);
        //_samint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }

    // Basic gameplay
    // - Keep a list of all alive & dead tokens. Populate in Round 1.
    // - Each round has a specific start and end time. If you fail to participate in any week, your NFT is automatically eliminated
    // - Check each round if there's only 1 alive. If so, pay out. (Guaranteed winner)
    // - At the end of round 6, pay out to all alive

    // Returns a random number between 0-999
    function rand()
        public
        view
        returns(uint256)
    {
        uint256 seed = uint256(keccak256(abi.encodePacked(
            block.timestamp + block.difficulty +
            ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (block.timestamp)) +
            block.gaslimit + 
            ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (block.timestamp)) +
            block.number
        )));

        return (seed - ((seed / 1000) * 1000));
    }

    function playRound1(address player)
        external
        payable
        //nonReentrant
        returns (uint256)
    {
        // Random game generator
    }

}