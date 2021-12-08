//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./Randomizer.sol";
import "./ICryptoBees.sol";
import "./Base64.sol";

contract Traits is Ownable {
    using Strings for uint256;
    ICryptoBees beesContract;
    Randomizer randomizerContract;
    // mint price ETH
    uint256 public constant MINT_PRICE = .02 ether;
    uint256 public constant MINT_PRICE_DISCOUNT = .055 ether;

    // mint price HONEY
    uint256 public constant MINT_PRICE_HONEY = 3000 ether;
    // mint price WOOL
    uint256 public mintPriceWool = 3000 ether;
    // how many minted already
    uint256 public minted;
    // max number of tokens that can be minted
    uint256 public constant MAX_TOKENS = 40000;
    // number of tokens that can be claimed for ETH
    uint256 public constant PAID_TOKENS = 10000;
    /// @notice controls if mintWithEthPresale is paused
    bool public mintWithEthPresalePaused = true;
    /// @notice controls if mintWithWool is paused
    bool public mintWithWoolPaused = true;

    constructor() {}

    function setBeesContract(address _BEES_CONTRACT) external onlyOwner {
        beesContract = ICryptoBees(_BEES_CONTRACT);
    }

    function setRandomizerContract(address _RANDOMIZER_CONTRACT) external onlyOwner {
        randomizerContract = Randomizer(_RANDOMIZER_CONTRACT);
    }

    /** MINTING */
    function mintForEth(
        uint256 amount,
        bool presale,
        uint256 value
    ) external {
        require(_msgSender() == address(beesContract), "DONT CHEAT!");
        mintCheck(amount, presale, value);
        for (uint256 i = 0; i < amount; i++) {
            _mint();
        }
    }

    function _mint() private {
        minted++;
        if (minted > 1) randomizerContract.revealToken(block.number);
        randomizerContract.unrevealedTokensPush(block.number);
        beesContract.mint(minted);
    }

    function mintCheck(
        uint256 amount,
        bool presale,
        uint256 value
    ) private view {
        // require(tx.origin == _msgSender(), "Only EOA");
        require(minted + amount <= MAX_TOKENS, "All tokens minted");
        if (presale) {
            require(beesContract.isWhitelisted(_msgSender()), "You are not on WL");
            require(!mintWithEthPresalePaused, "Presale mint paused");
            require(amount > 0 && amount <= 2, "Invalid mint amount presale");
        } else require(amount > 0 && amount <= 10, "Invalid mint amount sale");
        require(minted + amount <= PAID_TOKENS, "All tokens on-sale already sold");
        if (presale) require(amount * MINT_PRICE_DISCOUNT == value, "Invalid payment amount presale");
        else require(amount * MINT_PRICE == value, "Invalid payment amount sale");
    }

    /** RENDER */

    function getTokenTextType(uint256 tokenId) external view returns (string memory) {
        require(beesContract.doesExist(tokenId), "ERC721Metadata: Nonexistent token");
        return _getTokenTextType(tokenId);
    }

    function _getTokenTextType(uint256 tokenId) private view returns (string memory) {
        uint8 _type = beesContract.getTokenData(tokenId)._type;
        if (_type == 1) return "BEE";
        else if (_type == 2) return "BEAR";
        else if (_type == 3) return "BEEKEEPER";
        else return "NOT REVEALED";
    }

    function _getTokenImage(uint256 tokenId) private view returns (string memory) {
        uint8 _type = beesContract.getTokenData(tokenId)._type;
        if (_type == 1) return "QmfCnnjNDndTuRZLZFJhLVtQ8m533pEnBis4Y2NH3BvZdF";
        else if (_type == 2) return "QmVPMv3Kxg94vAJo4fQY2FGnYTYp4RM1dq7anwr9psbz9P";
        else if (_type == 3) return "QmTUuGDbndWZDYYr6pE1aeutZLpSuZi44KMZxeUw1VB2D8";
        else return "";
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        require(beesContract.doesExist(tokenId), "ERC721Metadata: Nonexistent token");

        string memory textType = _getTokenTextType(tokenId);
        string memory image = _getTokenImage(tokenId);
        string memory metadata = string(
            abi.encodePacked(
                '{"name": "',
                textType,
                " #",
                uint256(tokenId).toString(),
                '", "type": "',
                textType,
                '", "trait": "',
                uint256(beesContract.getTokenData(tokenId)._type).toString(),
                '", "description": "',
                '","image": "',
                image,
                '"}'
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(metadata))));
    }

    function setPresaleMintPaused(bool _paused) external onlyOwner {
        mintWithEthPresalePaused = _paused;
    }

    function setWoolMintPaused(bool _paused) external onlyOwner {
        mintWithWoolPaused = _paused;
    }

    function setWoolMintPrice(uint256 _price) external onlyOwner {
        mintPriceWool = _price;
    }
}