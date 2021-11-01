//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "hardhat/console.sol";
contract Punknpunks is ERC721URIStorage, Ownable {
    using Strings for uint256;
    using Address for address;
    using Counters for Counters.Counter;
    Counters.Counter public _tokenCount; //make private.

    string private nftBaseURI;  //URI + /pnp

    uint256 public constant NFT_PRICE = 5000000000000000; // 0.005 ETH
    uint256 public constant MAX_SUPPLY = 10000;

    // Variables for game
    address[] public participants;
    uint256 public payoutInterval = 5;
    uint256 private Funds = 0;
    uint256 private Pool = 0;

    bool public saleIsActive = false;  // set to false on deployment.
    bool public payout = false;

    constructor() ERC721("test", "NFT") {}

    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }

    // Will withdrawl all the money in the event there are funds left over after all 10,000 are minted.
    function withdrawAll() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    // Withdraw only from rationed funds.
    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(Funds);
        Funds = 0;
    }

    function mintNFT(address recipient, uint256 pnpId) public payable returns (uint256) {
        // TODO:
        // * ensure token totalSupply() is less than 10,000
        // * restrict mint price
        // * make sure id isnt used twice
        require(saleIsActive);
        require(pnpId < MAX_SUPPLY);
        require(NFT_PRICE == msg.value);

        enterPlayer(recipient);

        uint256 fundAmnt = 4000000000000000; // 0.004 ETH
        uint256 poolAmnt = 1000000000000000; // 0.001 ETH
        Funds = Funds + fundAmnt;
        Pool = Pool + poolAmnt;


        uint256 pnpCount = _tokenCount.current();
        if (pnpCount % payoutInterval == 0 && pnpCount > 0) {
            payout = true;
            payOutPool();
            payout = false;
        }

        string memory tokenURI = buildTokenURI(pnpId);
        _safeMint(recipient, pnpId);
        _setTokenURI(pnpId, tokenURI);

        _tokenCount.increment();
        return pnpId;
    }

    // Handles lottery payment function.
    function payOutPool() private {
        require(payout);
        address winner = participants[random() % participants.length];
        payable(winner).transfer(Pool);  // Send funds to winner.
        // Cleanup.
        Pool = 0;
        participants = new address payable[](0);
    }

    // Enter someone into the game.
    function enterPlayer(address recipient) private {
        require(NFT_PRICE == msg.value);
        participants.push(recipient);
    }

    // Sets the base uri for nft.
    function setBaseURI(string memory nftBaseURI_) public onlyOwner {
        nftBaseURI = nftBaseURI_;
    }

    // Generates token uri and adjusts for meta data name.
    function buildTokenURI(uint256 pnpId_) public view returns (string memory) {
        // string memory metaData = string(abi.encodePacked(pnpId_.toString(), ".json"));
        return string(abi.encodePacked(nftBaseURI, pnpId_.toString()));
    }

    // Generates random number.
    function random() public view returns (uint){  // TODO: Change to private.
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, participants)));
    }


}