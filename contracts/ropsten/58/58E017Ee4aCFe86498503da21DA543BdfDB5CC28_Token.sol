pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IPT.sol";

//SPDX-License-Identifier: MIT

contract Token is ERC721, Ownable {
    // mint price
    uint256 public MINT_PRICE = .068850 ether;
    uint256 public points;
    uint8 public gamePhase = 0;
    uint256 public gpCost = 100;
    bool public paused = false;
    // reference to $GP for burning on mint
    IPT public pToken;

    struct Pet {
        uint256 strength; //0-255
        uint256 magic;
        uint256 dexterity;
        uint256 wisdom;
        uint256 intelligence;
        uint256 lastMeal;
        uint256 endurance; // for example 24 to survive
    }

    uint256 nextId = 0;

    mapping(uint256 => Pet) private _tokenDetails;

    constructor(
        string memory name,
        string memory symbol,
        uint256 _points
    ) ERC721(name, symbol) {
        points = _points;
    }

    /** CRITICAL TO SETUP */

    modifier requireContractsSet() {
        require(address(pToken) != address(0), "Contracts not set");
        _;
    }

    function setContracts(address _pt) external onlyOwner {
        pToken = IPT(_pt);
    }

    function getTokenDetails(uint256 tokenId) public view returns (Pet memory) {
        return _tokenDetails[tokenId];
    }

    //only owner
    function setgamePhase(uint8 _newGamePhase) public onlyOwner {
        gamePhase = _newGamePhase;
    }

    //only owner
    function setCost(uint256 _newPrice) public onlyOwner {
        MINT_PRICE = _newPrice;
    }

    //only owner
    function setPleyerPoints(uint256 _newPoints) public onlyOwner {
        points = _newPoints;
    }

    //only owner
    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function mint(
        uint256 strength,
        uint8 magic,
        uint256 dexterity,
        uint256 wisdom,
        uint256 intelligence,
        uint256 endurance
    ) public onlyOwner {
        _tokenDetails[nextId] = Pet(
            strength,
            magic,
            dexterity,
            wisdom,
            intelligence,
            block.timestamp,
            endurance
        );
        _safeMint(msg.sender, nextId);
        nextId++;
    }

    function playerMint(
        uint256 strength,
        uint8 magic,
        uint256 dexterity,
        uint256 wisdom,
        uint256 intelligence,
        uint256 endurance
    ) external payable {
        uint256 totalPoints = strength + magic + intelligence;
        require(!paused);
        //require(tx.origin == _msgSender(), "Only EOA");
        require(MINT_PRICE == msg.value, "Invalid payment amount");
        require(totalPoints == points, "Invalid points");
        _tokenDetails[nextId] = Pet(
            strength,
            magic,
            dexterity, 
            wisdom,
            intelligence,
            block.timestamp,
            endurance
        );
        _safeMint(msg.sender, nextId);
        nextId++;
    }

    function feed(uint256 tokenId) public {
        Pet storage pet = _tokenDetails[tokenId];
        require(pet.lastMeal + pet.endurance > block.timestamp, "Pet is dead!");
        pet.lastMeal = block.timestamp;
    }

    function upgrade(
        uint256 tokenId,
        uint256 strength,
        uint256 magic,
        uint256 dexterity,
        uint256 wisdom,
        uint256 intelligence
    ) public {
        require(gamePhase > 1, "can't upgrade at phase 1");
        Pet storage pet = _tokenDetails[tokenId];
        uint256 oldTotalPoints = pet.strength + pet.magic + pet.intelligence + pet.dexterity + pet.wisdom;
        uint256 totalPoints = oldTotalPoints + strength + magic + intelligence;
        require(totalPoints == points, "Invalid points");

        uint256 totalGpCost = (totalPoints - oldTotalPoints)*gpCost;
        if (totalGpCost > 0) {
            pToken.burn(_msgSender(), totalGpCost);
            pToken.updateOriginAccess();
        }

        pet.dexterity += dexterity;
        pet.wisdom += wisdom;
        pet.strength += strength;
        pet.magic += magic;
        pet.intelligence += intelligence;
    }

    function getAllTokensForUser(address user)
        public
        view
        returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(user);
        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 totalPets = nextId;
            uint256 resultIndex = 0;
            uint256 i;
            for (i = 0; i < totalPets; i++) {
                if (ownerOf(i) == user) {
                    result[resultIndex] = i;
                    resultIndex++;
                }
            }
            return result;
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);
        Pet storage pet = _tokenDetails[tokenId];
        require(pet.lastMeal + pet.endurance > block.timestamp, "Pet is dead!");
    }

    /**
     * allows owner to withdraw funds from minting
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}