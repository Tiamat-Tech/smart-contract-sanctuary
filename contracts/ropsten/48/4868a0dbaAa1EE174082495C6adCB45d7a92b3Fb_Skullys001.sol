// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract Skullys001 is ERC721, ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;

    mapping(address => uint256) private tokensMinted;

    uint256 public constant PRICE = 99000000000000000;

    string private customBaseURI;

    string public SKULLY_PROVENANCE = "";

    uint256 public startingIndexBlock = 0;

    uint256 public startingIndex = 0;

    uint256 public SALE_START_TIMESTAMP;

    constructor(string memory customBaseURI_, address earlyMintPassAddress_, address mintPassAddress_, uint256 saleStartTime)
        ERC721("Skullys001", "TUGA")
    {
        customBaseURI = customBaseURI_;
        earlyMintPassAddress = earlyMintPassAddress_;
        mintPassAddress = mintPassAddress_;
        SALE_START_TIMESTAMP = saleStartTime;
    }

    function setProvenanceHash(string memory provenanceHash) public onlyOwner {
        require(
            bytes(SKULLY_PROVENANCE).length == 0,
            "Provenance Hash already set"
        );

        SKULLY_PROVENANCE = provenanceHash;
    }

    /* MINTING LIMITS */

    uint256 public constant MINT_LIMIT_PER_ADDRESS = 10;

    uint256 public constant PRESALE_LIMIT_PER_ADDRESS = 5;

    uint256 public constant EARLY_PRESALE_LIMIT_PER_ADDRESS = 2;

    function allowedEarlyPresaleCount(address minter) public view returns (uint256) {
        return EARLY_PRESALE_LIMIT_PER_ADDRESS - tokensMinted[minter];
    }

    function allowedMintCount(address minter) public view returns (uint256) {
        return MINT_LIMIT_PER_ADDRESS - tokensMinted[minter];
    }

    function updateMintCount(address minter, uint256 count) private {
        tokensMinted[minter] += count;
    }

    /** MINTING AND SUPPLY **/
    uint256 public constant TOTAL_SUPPLY = 40;

    uint256 public constant RESERVED_SUPPLY = 10;

    address public immutable earlyMintPassAddress;

    address public immutable mintPassAddress;

    Counters.Counter private supplyCounter;

    /**
     * Function for minting Skullys. Includes functionality for pre-sale, during which
     * only mint pass holders are able to mint 2 Skullys each. After pre-sale, anyone can mint
     * up to 10 total Skullys.
     **/
    function mint(uint256 numberOfSkullys) public payable nonReentrant {
        require(saleIsActive, "Sale not active");

        require(
            numberOfSkullys <= MINT_LIMIT_PER_ADDRESS,
            "Can't mint more than 10 skullys"
        );

        if (mintPassRequired || block.timestamp <= SALE_START_TIMESTAMP) {
            /** PRE-SALE **/

            require(tokensMinted[_msgSender()] == 0, "Address already minted in pre-sale, must wait for public sale to mint more");

            ERC721 earlyMintPass = ERC721(earlyMintPassAddress);

            ERC721 mintPass = ERC721(mintPassAddress);

            require(
                earlyMintPass.balanceOf(_msgSender()) > 0 || mintPass.balanceOf(_msgSender()) > 0,
                "You currently need a mint pass to mint a Skully"
            );

            if(earlyMintPass.balanceOf(_msgSender()) > 0) {
                require(
                    allowedEarlyPresaleCount(_msgSender()) == EARLY_PRESALE_LIMIT_PER_ADDRESS,
                    "Address already minted in pre-sale, must wait for public sale to mint more"
                );

                updateMintCount(_msgSender(), EARLY_PRESALE_LIMIT_PER_ADDRESS);
            
                /** Each early mint pass holder gets two Skullys **/
                for (uint256 i = 0; i < EARLY_PRESALE_LIMIT_PER_ADDRESS; i++) {
                    if (totalSupply() < TOTAL_SUPPLY) {
                        _safeMint(_msgSender(), totalSupply());
                        supplyCounter.increment();
                    }
                }
            }

            if(mintPass.balanceOf(_msgSender()) > 0) {
                require(
                    tokensMinted[_msgSender()] < PRESALE_LIMIT_PER_ADDRESS,
                    "Address already minted in pre-sale, must wait for public sale to mint more"
                );

                uint addressBalance = mintPass.balanceOf(_msgSender());

                uint mintCount = addressBalance <= 3 ? addressBalance : 3;

                updateMintCount(_msgSender(), mintCount);

                /** Each regular mint pass holder gets one Skully per mint pass (up to three total) **/
                for (uint256 i = 0; i < mintCount; i++){
                    if (totalSupply() < TOTAL_SUPPLY) {
                        _safeMint(_msgSender(), totalSupply());
                        supplyCounter.increment();
                    }
                }
            }
        } else {
            /** PUBLIC SALE **/

            if (allowedMintCount(_msgSender()) >= numberOfSkullys) {
                updateMintCount(_msgSender(), numberOfSkullys);
            } else {
                revert("Minting limit exceeded");
            }

            require(
                totalSupply() + numberOfSkullys <= TOTAL_SUPPLY,
                "Exceeds max supply"
            );

            require(
                msg.value >= PRICE * numberOfSkullys,
                "Not enough ETH, you need 0.099 ETH per Skully"
            );

            for (uint256 i = 0; i < numberOfSkullys; i++) {
                if (totalSupply() < TOTAL_SUPPLY) {
                    _safeMint(_msgSender(), totalSupply());

                    supplyCounter.increment();
                }
            }
        }

        if (startingIndexBlock == 0 && (totalSupply() == TOTAL_SUPPLY)) {
            startingIndexBlock = block.number;
        }
    }

    /**
     * Skullys reserved for giveaways, collaborations, etc.
     * These Skullys will be completely random and we won't be able to
     * target tokens based on rarity
     **/
    function reserveSkullys(uint256 numberToMint) public onlyOwner {
        require(
            tokensMinted[_msgSender()] + numberToMint <= RESERVED_SUPPLY,
            "Already minted full reserved supply"
        );

        for (uint256 i = 0; i < numberToMint; i++) {
            _safeMint(_msgSender(), totalSupply());
            supplyCounter.increment();
        }

        updateMintCount(_msgSender(), numberToMint);
    }

    /**
     * Allows the founders to mint their custom, 1/1 skullys first
     **/
    function mintCustomSkullys() public onlyOwner {
        require(totalSupply() < 5, "First 5 Skullys already minted");

        for (uint256 i = 0; i < 5; i++) {
            _safeMint(_msgSender(), totalSupply());
            supplyCounter.increment();
        }

        updateMintCount(_msgSender(), 5);
    }

    function totalSupply() public view returns (uint256) {
        return supplyCounter.current();
    }


    /**
     * Set the starting index for the collection. Since the first 5 tokens
     * belong to the founders of the collection they will always be the first 5 token IDs and image IDs,
     * ie if the startingIndex is 5341, the matching of tokenID:imageID will be 0:0, 1:1, 2:2, 3:3, 4:4, 5:5341,
     * 6:5342, 7:5343, ... 4663:9999, 4664:5 .... 9998:5339, 9999:5340
     **/
    function setStartingIndex() public {
        require(startingIndex == 0, "Starting index is already set");
        require(startingIndexBlock != 0, "Starting index block must be set");

        startingIndex =
            uint256(blockhash(startingIndexBlock)) %
            (TOTAL_SUPPLY - 5);

        if (block.number - (startingIndexBlock) > 255) {
            startingIndex =
                uint256(blockhash(block.number - 1)) %
                (TOTAL_SUPPLY - 5);
        }
        // Prevent default sequence
        if (startingIndex < 5) {
            startingIndex = startingIndex + 5;
        }
    }

    /**
     * Set the starting index block for the collection
     **/
    function emergencySetStartingIndexBlock() public onlyOwner {
        require(startingIndexBlock == 0, "Starting index block is already set");

        startingIndexBlock = block.number;
    }

    /** ACTIVATION **/

    bool public saleIsActive = false;

    bool public mintPassRequired = true;

    function setSaleIsActive(bool saleIsActive_) external onlyOwner {
        saleIsActive = saleIsActive_;
    }

    function setGatedMinting(bool mintPassRequired_) external onlyOwner {
        mintPassRequired = mintPassRequired_;
    }

    /** URI HANDLING **/

    function setBaseURI(string memory customBaseURI_) external onlyOwner {
        customBaseURI = customBaseURI_;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return customBaseURI;
    }

    /** PAYOUT **/

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;

        payable(owner()).transfer(balance);
    }

    /** ROYALTY STUFF **/

    function royaltyInfo(uint256, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount) {
        return (address(this), (salePrice * 700) / 10000);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return (interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId));
    }
}