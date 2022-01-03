// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CozyChicklets is ERC721Enumerable, Ownable {
    using Strings for uint256;

    uint256 public constant MAX_CHICKLETS = 80;
    uint256 public constant MAX_SES = 8;
    uint256 public constant MAX_COSTUMES = 8;
    uint256 public constant NUM_TRAITS = 5;
    mapping(uint256 => string) internal ipfsCids;
    uint256 internal nonce;
    uint256 public price = 0.05 ether;
    bool public activeSale = false;
    uint8[NUM_TRAITS][MAX_CHICKLETS] internal chickletTraits;
    uint8[NUM_TRAITS] internal TRAIT_COUNTS = [16, 48, 25, 50, 6];
    address internal addy = 0xcae0CAd7fe32bae4B4921F08902cB46490B23bd7;

    string internal baseTokenURI;

    uint16[MAX_SES + 1] internal superStock = [
        uint16(MAX_CHICKLETS - MAX_SES),
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1
    ];

    uint16[MAX_COSTUMES + 1] internal costumeStock = [
        uint16(MAX_CHICKLETS - MAX_COSTUMES * 10),
        10,
        10,
        10,
        10,
        10,
        10,
        10,
        10
    ];

    ////Constructor////
    constructor() ERC721("Cozy Chicklets", "COZY") {
        nonce = 12;
    }

    ////Public Functions////
    function mintChicklet(uint256 num) public payable {
        uint256 supply = totalSupply();
        require(activeSale, "Sale paused");
        require(num < 11, "You can mint a maximum of 20 Chicklets");
        require(supply + num <= MAX_CHICKLETS, "Exceeds maximum supply");
        require(msg.value >= price * num, "Eth sent is not correct");

        for (uint256 i; i < num; i++) {
            _mintChick(num, msg.sender);
        }
    }

    function getTraits(uint256 tokenId)
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: Trait query for nonexistent token"
        );
        require(
            bytes(ipfsCids[tokenId]).length > 0 || _msgSender() == owner(),
            "Unauthorized"
        );

        return (
            chickletTraits[tokenId][0],
            chickletTraits[tokenId][1],
            chickletTraits[tokenId][2],
            chickletTraits[tokenId][3],
            chickletTraits[tokenId][4]
        );
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(tokenId), "Query for nonexistent token");

        return
            bytes(ipfsCids[tokenId]).length > 0
                ? string(abi.encodePacked(baseTokenURI, ipfsCids[tokenId]))
                : "ipfs://QmVXMMj5eBikicjViQLtqJDVVgupbFr3miFeo2pZmCX2kC";
    }

    function getPrice() public view returns (uint256) {
        return price;
    }

    ////Only Owner Functions////
    function setPrice(uint256 newPrice) public onlyOwner {
        price = newPrice;
    }

    function setSaleBool(bool activeSaleBool) public onlyOwner {
        activeSale = activeSaleBool;
    }

    function setTokenCID(uint256 tokenId, string memory tokenCID)
        public
        onlyOwner
    {
        ipfsCids[tokenId] = tokenCID;
    }

    function withdraw() public payable onlyOwner {
        uint256 balance = address(this).balance;
        payable(addy).transfer(balance);
    }

    ////Internal Functions////
    function _mintChick(uint256 num, address sender) internal {
        for (uint256 i = 0; i < num; i++) {
            uint256 seed = uint256(
                keccak256(
                    abi.encodePacked(
                        nonce,
                        block.difficulty,
                        block.timestamp,
                        sender
                    )
                )
            );
            uint256 tokenId = totalSupply();
            addTraits(seed, tokenId);
            _safeMint(sender, tokenId);
        }
    }

    function addTraits(uint256 seed, uint256 tokenId) internal {
        for (uint8 i = 0; i < NUM_TRAITS; i++) {
            nonce++;
            chickletTraits[tokenId][i] = determineTrait(i, seed);
        }

        if (!checkForSe(tokenId, seed)) {
            checkForCostume(tokenId, seed);
        }
    }

    function determineTrait(uint8 traitType, uint256 seed)
        internal
        view
        returns (uint8)
    {
        uint8 trait = uint8(seed % TRAIT_COUNTS[traitType]);
        return trait;
    }

    function checkForSe(uint256 tokenId, uint256 seed) internal returns (bool) {
        uint16 roll = uint16(seed % (MAX_CHICKLETS - totalSupply()));
        for (uint8 i = 0; i < MAX_SES + 1; i++) {
            if (roll < superStock[i]) {
                superStock[i]--;
                if (i > 0) {
                    createSuper(tokenId, i);
                    return true;
                }
                return false;
            }
            roll -= superStock[i];
        }
        revert("FAILED");
    }

    function createSuper(uint256 tokenId, uint256 superId) internal {
        for (uint8 i = 0; i < NUM_TRAITS; i++) {
            chickletTraits[tokenId][i] = uint8(100 + superId);
        }
    }

    function checkForCostume(uint256 tokenId, uint256 seed) internal {
        uint16 roll = uint16(seed % (MAX_CHICKLETS - totalSupply()));
        for (uint8 i = 0; i < MAX_COSTUMES + 1; i++) {
            if (roll < costumeStock[i]) {
                costumeStock[i]--;
                if (i > 0) {
                    createCostume(tokenId, i, seed);
                }
                return;
            }
            roll -= costumeStock[i];
        }
        revert("FAILED");
    }

    function createCostume(
        uint256 tokenId,
        uint256 costumeId,
        uint256 seed
    ) internal {
        for (uint8 i = 0; i < NUM_TRAITS; i++) {
            (i == 2 || i == 4)
                ? chickletTraits[tokenId][i] = uint8(seed % TRAIT_COUNTS[i])
                : chickletTraits[tokenId][i] = uint8(200 + costumeId);
        }
    }
}