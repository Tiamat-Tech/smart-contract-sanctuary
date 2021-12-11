/*

▄▄▄█████▓ ██░ ██ ▓█████     ██▀███   ██▓  █████▒▄▄▄█████▓   (for Adventurers)
▓  ██▒ ▓▒▓██░ ██▒▓█   ▀    ▓██ ▒ ██▒▓██▒▓██   ▒ ▓  ██▒ ▓▒
▒ ▓██░ ▒░▒██▀▀██░▒███      ▓██ ░▄█ ▒▒██▒▒████ ░ ▒ ▓██░ ▒░
░ ▓██▓ ░ ░▓█ ░██ ▒▓█  ▄    ▒██▀▀█▄  ░██░░▓█▒  ░ ░ ▓██▓ ░ 
  ▒██▒ ░ ░▓█▒░██▓░▒████▒   ░██▓ ▒██▒░██░░▒█░      ▒██▒ ░ 
  ▒ ░░    ▒ ░░▒░▒░░ ▒░ ░   ░ ▒▓ ░▒▓░░▓   ▒ ░      ▒ ░░   
    ░     ▒ ░▒░ ░ ░ ░  ░     ░▒ ░ ▒░ ▒ ░ ░          ░    
  ░       ░  ░░ ░   ░        ░░   ░  ▒ ░ ░ ░      ░      
          ░  ░  ░   ░  ░      ░      ░                   
                                                         
    by chris and tony
    
*/
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

import "./Interfaces.sol";
import "./IRift.sol";

contract Rift is ReentrancyGuard, Pausable, Ownable {

    event BagCharged(address owner, uint256 tokenId, uint16 amount);
    event ChargesConsumed(address owner, uint256 tokenId, uint16 amount);
    // event CrystalSacrificed(address owner, uint256 tokenId, uint256 powerIncrease);

    ERC721 public iLoot;
    ERC721 public iMLoot;
    IMana public iMana;

    string public description = "The Great Unknown";

    // rift level variables
    uint256 public riftLevel = 3;
    uint256 internal riftTier = 1;
    uint256 internal riftTierPower = 17500;
    uint16 internal riftTierSize = 5;
    uint16 internal riftTierIncrease = 15; // 15% increase
    uint256 internal riftPowerPerLevel = 5000;

    uint256 public riftObjectsSacrificed = 0;

    uint256 internal karmaTotal;
    uint256 internal karmaHolders;

    uint32 internal xpMultTiny = 10;
    uint32 internal xpMultMod = 50;
    uint32 internal xpMultLrg = 100;
    uint32 internal xpMultEpc = 300;

    mapping(uint256 => RiftBag) public bags;
    mapping(address => uint256) public karma;
    mapping(uint16 => uint16) public xpRequired;
    mapping(uint16 => uint16) public levelChargeAward;
    mapping(address => bool) public riftObjects;
    mapping(address => bool) public riftQuests;
    address[] public riftObjectsArr;

    constructor() Ownable() {
    }

    function ownerSetDescription(string memory desc) public onlyOwner {
        description = desc;
    }

    function ownerSetLootAddress(address addr) public onlyOwner {
        iLoot = ERC721(addr);
    }

    function ownerSetMLootAddress(address addr) public onlyOwner {
        iMLoot = ERC721(addr);
    }

    function addRiftQuest(address addr) public onlyOwner {
        riftQuests[addr] = true;
    }

    function removeRiftQuest(address addr) public onlyOwner {
        riftQuests[addr] = false;
    }

    function ownerUpdateRiftTier(uint16 tierSize, uint16 tierIncrease, uint256 ppl) public onlyOwner {
        riftTierSize = tierSize;
        riftTierIncrease = tierIncrease;
        riftPowerPerLevel = ppl;
    }

    /**
    * enables an address to mint / burn
    * @param controller the address to enable
    */
    function addRiftObject(address controller) external onlyOwner {
        riftObjects[controller] = true;
        riftObjectsArr.push(controller);
    }

    /**
    * disables an address from minting / burning
    * @param controller the address to disbale
    */
    function removeRiftObject(address controller) external onlyOwner {
        riftObjects[controller] = false;
    }

    function setPaused(bool _paused) external onlyOwner {
        if (_paused) _pause();
        else _unpause();
    }

    function ownerWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function ownerSetXpRequirement(uint16 level, uint16 xp) external onlyOwner {
        xpRequired[level] = xp;
    }

    function ownerSetLevelChargeAward(uint16 level, uint16 charges) external onlyOwner {
        levelChargeAward[level] = charges;
    }

    function ownerSetManaAddress(address addr) public onlyOwner {
        iMana = IMana(addr);
    }

    function ownerSetXPMultipliers(uint32 tiny, uint32 moderate, uint32 large, uint32 epic) external onlyOwner {
        xpMultTiny = tiny;
        xpMultMod = moderate;
        xpMultLrg = large;
        xpMultEpc = epic;
    }

    // READ

    modifier _isBagHolder(uint256 bagId, address owner) {
        if (bagId < 8001) {
            require(iLoot.ownerOf(bagId) == owner, "UNAUTH");
        } else {
            require(iMLoot.ownerOf(bagId) == owner, "UNAUTH");
        }
        _;
    }

    function isBagHolder(uint256 bagId, address owner) external view {
        if (bagId < 8001) {
            require(iLoot.ownerOf(bagId) == owner, "UNAUTH");
        } else {
            require(iMLoot.ownerOf(bagId) == owner, "UNAUTH");
        }
    }

    function getBag(uint256 bagId) external view returns (RiftBag memory) {
        return bags[bagId];
    }
    
    // WRITE

    // pay to charge. only once per day
    function buyCharge(uint256 bagId) external
        _isBagHolder(bagId, _msgSender()) 
        whenNotPaused 
        nonReentrant {
    
        require(block.timestamp - bags[bagId].lastChargePurchase > 1 days, "Too soon"); 
        
        //one with the rift
        if (topKarmaHolder(_msgSender())) {
            _chargeBag(bagId);
        } else {
            iMana.burn(_msgSender(), bags[bagId].level * 1000);
            _chargeBag(bagId);
        }

        bags[bagId].lastChargePurchase = uint64(block.timestamp);
    }

    function useCharge(uint16 amount, uint256 bagId, address from) 
        _isBagHolder(bagId, from) 
        external 
        whenNotPaused 
        nonReentrant 
    {
        require(riftObjects[msg.sender], "Not of the Rift");
        require(bags[bagId].charges >= amount, "Not enough Rift charges");

        bags[bagId].chargesUsed += amount;
        bags[bagId].charges -= amount;
    }

    function awardXP(uint32 bagId, XP_AMOUNT xp) public nonReentrant {
        require(riftQuests[msg.sender], "only the worthy");
    
        if (bags[bagId].level == 0) {
            bags[bagId].level = 1;
            _chargeBag(bagId);
        }

        bags[bagId].xp += convertXP(xp, bagId);
        
        /*
 _        _______           _______  _                   _______  _ 
( \      (  ____ \|\     /|(  ____ \( \        |\     /|(  ____ )( )
| (      | (    \/| )   ( || (    \/| (        | )   ( || (    )|| |
| |      | (__    | |   | || (__    | |        | |   | || (____)|| |
| |      |  __)   ( (   ) )|  __)   | |        | |   | ||  _____)| |
| |      | (       \ \_/ / | (      | |        | |   | || (      (_)
| (____/\| (____/\  \   /  | (____/\| (____/\  | (___) || )       _ 
(_______/(_______/   \_/   (_______/(_______/  (_______)|/       (_)                                                    
                                                                 
        */
        while (bags[bagId].xp >= xpRequired[bags[bagId].level]) {
            bags[bagId].xp -= xpRequired[bags[bagId].level];
            bags[bagId].level += 1;
            _chargeBag(bagId);
        }
    }

    function _chargeBag(uint256 bagId) internal {
        bags[bagId].charges += levelChargeAward[bags[bagId].level];
        removeRiftPower(levelChargeAward[bags[bagId].level] * bags[bagId].level);
    }

    function setupNewBag(uint256 bagId) external {
        require(bags[bagId].level == 0, "bag must be unregistered");
        bags[bagId].level = 1;
        _chargeBag(bagId);
    }

    function convertXP(XP_AMOUNT xp, uint32 bagId) internal view returns (uint32) {
        if (xp == XP_AMOUNT.NONE) { return 0; }
        else if (xp == XP_AMOUNT.TINY) { return bags[bagId].level * xpMultTiny; }
        else if (xp == XP_AMOUNT.MODERATE) { return bags[bagId].level * xpMultMod; }
        else if (xp == XP_AMOUNT.LARGE) { return bags[bagId].level * xpMultLrg; }
        else if (xp == XP_AMOUNT.EPIC) { return bags[bagId].level * xpMultEpc; }

        return 0;
    }

    function growTheRift(address burnableAddr, uint256 tokenId , uint256 bagId) _isBagHolder(bagId, msg.sender) external {
        require(riftObjects[burnableAddr], "Not of the Rift");
        require(ERC721(burnableAddr).ownerOf(tokenId) == _msgSender(), "Must be yours");
        
        _sacrificeRiftObject(burnableAddr, tokenId, bagId);
    }

    function _sacrificeRiftObject(address burnableAddr, uint256 tokenId, uint256 bagId) internal {
        uint256 powerIncrease = IRiftBurnable(burnableAddr).riftPower(tokenId);
        ERC721Burnable(burnableAddr).burn(tokenId);

        addRiftPower(powerIncrease);
        if (karma[_msgSender()] == 0) { karmaHolders += 1; }
        karmaTotal += powerIncrease;
        karma[_msgSender()] += powerIncrease;
        riftObjectsSacrificed += 1;     

        awardXP(uint32(bagId), XP_AMOUNT.MODERATE);
    }

    function topKarmaHolder(address holder) public view returns (bool) {
        require(karma[holder] > 0, "has no karma");
        uint256 medianKarma = karmaTotal / karmaHolders;
        return karma[holder] > (medianKarma * 2);
    }

    // Rift Power
    function addRiftPower(uint256 power) internal {
        riftTierPower += power;
        riftLevel = riftTierPower/riftPowerPerLevel;

        // up a tier
        if (riftLevel > (riftTier * riftTierSize)) {
            riftTierPower -= riftTierSize * riftPowerPerLevel;
            riftTier += 1;
            riftPowerPerLevel += (riftPowerPerLevel * riftTierIncrease)/100; // add increase as a percentage
        }
    }

    function removeRiftPower(uint256 power) internal {
        if (power > riftTierPower) {
            riftTierPower = 0;
        } else {
            riftTierPower -= power;
        }

        riftLevel = riftTierPower/riftPowerPerLevel;
    }
}