//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./Randomizer.sol";
import "./ICryptoBees.sol";
import "./IHoney.sol";
import "./Base64.sol";

contract Traits is Ownable {
    using Strings for uint256;
    ICryptoBees beesContract;
    IHoney honeyContract;
    Randomizer randomizerContract;
    // mint price ETH
    uint256 public constant MINT_PRICE = .02 ether;
    uint256 public constant MINT_PRICE_DISCOUNT = .055 ether;

    // mint price HONEY
    uint256 public constant MINT_PRICE_HONEY = 3000 ether;
    // mint price WOOL
    uint256 public mintPriceWool = 3000 ether;
    // max number of tokens that can be minted
    uint256 public constant MAX_TOKENS = 40000;
    // number of tokens that can be claimed for ETH
    uint256 public constant PAID_TOKENS = 10000;
    /// @notice controls if mintWithEthPresale is paused
    bool public mintWithEthPresalePaused = true;
    /// @notice controls if mintWithWool is paused
    bool public mintWithWoolPaused = true;

    constructor() {}

    function setContracts(
        address _BEES,
        address _RANDOMIZER,
        address _HONEY
    ) external onlyOwner {
        beesContract = ICryptoBees(_BEES);
        randomizerContract = Randomizer(_RANDOMIZER);
        honeyContract = IHoney(_HONEY);
    }

    /** MINTING */
    function mintForEth(
        address owner,
        uint256 amount,
        uint256 minted,
        bool presale,
        uint256 value
    ) external {
        require(_msgSender() == address(beesContract), "DONT CHEAT!");
        mintCheck(owner, amount, minted, presale, value, true);
        for (uint256 i = 1; i <= amount; i++) {
            mint(owner, minted + i);
        }
    }

    function mintForHoney(
        address owner,
        uint256 amount,
        uint256 minted
    ) external {
        require(_msgSender() == address(beesContract), "DONT CHEAT!");
        mintCheck(owner, amount, minted, false, 0, false);
        uint256 totalHoneyCost = 0;
        for (uint256 i = 1; i <= amount; i++) {
            totalHoneyCost += mintCost(minted + i);
            mint(owner, minted + i);
        }
        honeyContract.burn(msg.sender, totalHoneyCost);
    }

    function mintForWool(
        address owner,
        uint256 amount,
        uint256 minted
    ) external returns (uint256 totalWoolCost) {
        require(!mintWithWoolPaused, "WOOL minting paused");
        require(minted + amount <= PAID_TOKENS, "All tokens on-sale already sold");
        mintCheck(owner, amount, minted, false, 0, false);

        for (uint256 i = 1; i <= amount; i++) {
            totalWoolCost += mintPriceWool;
            mint(owner, minted + i);
        }
    }

    function mint(address owner, uint256 minted) private {
        beesContract.mint(owner, minted);
    }

    function mintCheck(
        address owner,
        uint256 amount,
        uint256 minted,
        bool presale,
        uint256 value,
        bool isEth
    ) private view {
        require(tx.origin == owner, "Only EOA");
        require(minted + amount <= MAX_TOKENS, "All tokens minted");
        if (presale) {
            require(beesContract.isWhitelisted(owner), "You are not on WL");
            require(!mintWithEthPresalePaused, "Presale mint paused");
            require(amount > 0 && amount <= 2, "Invalid mint amount presale");
        } else require(amount > 0 && amount <= 10, "Invalid mint amount sale");
        if (isEth) {
            require(minted + amount <= PAID_TOKENS, "All tokens on-sale already sold");
            if (presale) require(amount * MINT_PRICE_DISCOUNT == value, "Invalid payment amount presale");
            else require(amount * MINT_PRICE == value, "Invalid payment amount sale");
        }
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

    /**
     * Gen 0 can be mint for honey too
     * @param tokenId the ID to check the cost of to mint
     * @return the cost of the given token ID
     */
    function mintCost(uint256 tokenId) public pure returns (uint256) {
        if (tokenId <= 20000) return MINT_PRICE_HONEY;
        if (tokenId <= 30000) return 7500 ether;
        return 15000 ether;
    }
}