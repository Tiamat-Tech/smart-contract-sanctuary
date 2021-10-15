//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract OctopusFun is ERC721URIStorage, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    Counters.Counter public aliveNFTCount;

    mapping(address => uint256) public aliveNFTs;  // Maps address to current round that player is in
    mapping(address => uint256) public deadNFTs;  // Maps address to current round that player is in
    address[] private alivePlayerAddresses;  // Used to keep addresses of all alive players for payout of winners

    uint256 public constant MAX_OCTOPUS_FUN_TOKENS = 456;
    uint256 public constant COST_TO_MINT = 100000000000000000; // 0.1 Ether

    constructor() ERC721("OctopusFun", "OCF") {}

    function mintNFT(address recipient, string memory tokenURI)
        external
        payable
        returns (uint256)
    {
        require(COST_TO_MINT <= msg.value, "Ether value sent is not correct");
        require(_tokenIds.current()<MAX_OCTOPUS_FUN_TOKENS, "We have reached the max number of players, try again next time");
        _tokenIds.increment();
        aliveNFTCount.increment();

        uint256 newItemId = _tokenIds.current();
        _safeMint(recipient, newItemId);
        //_samint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);
        aliveNFTs[recipient] = 1; // set each new minted NFT to start on round 1
        alivePlayerAddresses.push(recipient);

        return newItemId;
    }

    // Basic gameplay
    // - Keep a list of all alive & dead tokens. Populate alive in minting.
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


    // Starts on Wednesday, October 20, 2021 10:00:00 AM GMT
    function playRound1(address player)
        external
        nonReentrant
        returns(string memory)
    {
        // require(block.timestamp>1634724000 && block.timestamp<1634810400, "Sorry, it is not time for round 1.");
        uint256 roundThatPlayerIsIn = aliveNFTs[player];
        require(roundThatPlayerIsIn != 0 && roundThatPlayerIsIn == 1, "Must be a player with an NFT that's alive and in round 1!");
        uint256 chanceOfSurvival = rand(); // ~50% chance of surviving round 1
        if(chanceOfSurvival < 499){ // Sorry, you are eliminated from round 1
            eliminateNFT(player, roundThatPlayerIsIn);
            return "Sorry, you were eliminated from round 1.";
        }

        aliveNFTs[player] = aliveNFTs[player] + 1; // increment the round that the player is on
        return "Congrats, you survived round 1.";
    }

    // Starts on Thursday, October 21, 2021 10:00:00 AM GMT
    function playRound2(address player)
        external
        nonReentrant
        returns(string memory)
    {
        // require(block.timestamp>1634810400 && block.timestamp<1634896800, "Sorry, it is not time for round 2.");
        uint256 roundThatPlayerIsIn = aliveNFTs[player];
        require(roundThatPlayerIsIn != 0 && roundThatPlayerIsIn == 2, "Must be a player with an NFT that's alive and in round 2!");
        uint256 chanceOfSurvival = rand(); // ~50% chance of surviving round 1
        if(chanceOfSurvival < 499){ // Sorry, you are eliminated from round 1
            eliminateNFT(player, roundThatPlayerIsIn);
            return "Sorry, you were eliminated from round 2.";
        }

        aliveNFTs[player] = aliveNFTs[player] + 1; // increment the round that the player is on
        return "Congrats, you survived round 2.";
    }

    // Starts on Friday, October 22, 2021 10:00:00 AM GMT
    function playRound3(address player)
        external
        nonReentrant
        returns(string memory)
    {
        // require(block.timestamp>1634896800 && block.timestamp<1634904000000, "Sorry, it is not time for round 3.");
        uint256 roundThatPlayerIsIn = aliveNFTs[player];
        require(roundThatPlayerIsIn != 0 && roundThatPlayerIsIn == 3, "Must be a player with an NFT that's alive and in round 3!");
        uint256 chanceOfSurvival = rand(); // ~50% chance of surviving round 1
        if(chanceOfSurvival < 499){ // Sorry, you are eliminated from round 1
            eliminateNFT(player, roundThatPlayerIsIn);
            return "Sorry, you were eliminated from round 3.";
        }

        aliveNFTs[player] = aliveNFTs[player] + 1; // increment the round that the player is on
        return "Congrats, you survived round 3.";
    }

    // function playRound4(address player)
    //     external
    //     payable
    //     nonReentrant
    // {
    //     uint256 tokenOfAddress = aliveNFTs[player];
    //     require(tokenOfAddress != 0, "Must be a player with an NFT that's alive!");
    //     uint256 chanceOfSurvival = rand(); // ~50% chance of surviving round 1
    //     if(chanceOfSurvival < 499){ // Sorry, you are eliminated from round 1
    //         eliminateNFT(player, tokenOfAddress);
    //     }
    // }

    // function playRound5(address player)
    //     external
    //     payable
    //     nonReentrant
    // {
    //     uint256 tokenOfAddress = aliveNFTs[player];
    //     require(tokenOfAddress != 0, "Must be a player with an NFT that's alive!");
    //     uint256 chanceOfSurvival = rand(); // ~50% chance of surviving round 1
    //     if(chanceOfSurvival < 499){ // Sorry, you are eliminated from round 1
    //         eliminateNFT(player, tokenOfAddress);
    //     }
    // }

    // function playRound6(address player)
    //     external
    //     payable
    //     nonReentrant
    // {
    //     uint256 tokenOfAddress = aliveNFTs[player];
    //     require(tokenOfAddress != 0, "Must be a player with an NFT that's alive!");
    //     uint256 chanceOfSurvival = rand(); // ~50% chance of surviving round 1
    //     if(chanceOfSurvival < 499){ // Sorry, you are eliminated from round 1
    //         eliminateNFT(player, tokenOfAddress);
    //     }
    // }

    function eliminateNFT(address player, uint256 roundThatPlayerIsIn) 
        private
    {
        aliveNFTs[player] = 0;
        deadNFTs[player] = roundThatPlayerIsIn;

        aliveNFTCount.decrement();
    }

    // If there's one player left, payout to solo winner!
    // Else, check that round 6 (Ends on Friday, October 22, 2021 3:00:00 PM GMT) is over
    function checkIfWinnerAndPayout(address player) 
        public
        nonReentrant
        payable
        returns(string memory)
    {
        if(aliveNFTCount.current() == 1) {
            address winnerAddress = player;
            uint256 balance = address(this).balance;
            payable(winnerAddress).transfer(balance);
        } else {
            // require(block.timestamp>1634904000000, "Be patient, the game is not finished");
            uint256 roundThatPlayerIsIn = aliveNFTs[player];
            require(roundThatPlayerIsIn != 0 && roundThatPlayerIsIn == 4, "Must be a player with an NFT that's alive and passed all 3 rounds!");
            uint256 balance = address(this).balance;
            uint256 numberOfWinners = aliveNFTCount.current();
            uint256 payoutToEachWinner = balance/numberOfWinners;
            payable(player).transfer(payoutToEachWinner);
        }

        return "You've won! Here's your winnings";
    }

}