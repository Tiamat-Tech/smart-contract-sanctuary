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
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./Interfaces.sol";
import "./IRift.sol";

contract Rift is Initializable, ReentrancyGuardUpgradeable, PausableUpgradeable, OwnableUpgradeable {

    event BagCharged(address owner, uint256 tokenId, uint16 amount);
    event ChargesConsumed(address owner, uint256 tokenId, uint16 amount);
    // event CrystalSacrificed(address owner, uint256 tokenId, uint256 powerIncrease);

    // The Rift supports 8000 Loot bags
    // 9989460 mLoot Bags (34 years worth)
    // and 2540 gLoot Bags
    ERC721 public iLoot;
    ERC721 public iMLoot;
    ERC721 public iGLoot;
    IMana public iMana;
    IRiftData public iRiftData;
    // gLoot bags must offset their bagId by adding gLootOffset when interacting
    uint32 constant glootOffset = 9997460;

    string public description;

    // rift level variables
    uint32 public riftLevel;
    uint32 internal riftTier;
    uint64 internal riftTierPower;
    uint8 internal riftTierSize;
    uint8 internal riftTierIncrease; // 15% increase
    uint64 internal riftPowerPerLevel;

    uint64 public riftObjectsSacrificed;

    mapping(uint16 => uint16) public xpRequired;
    mapping(uint16 => uint16) public levelChargeAward;
    mapping(address => bool) public riftObjects;
    mapping(address => bool) public riftQuests;
    address[] public riftObjectsArr;

    function initialize() public initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        // iLoot = ERC721(lootAddr);
        // iMLoot = ERC721(mlootAddr);
        // iGLoot = ERC721(glootAddr);

        // description = "The Great Unknown";

        riftLevel = 2;
        // riftTier = 1;
        riftTierPower = 25000;
        // riftTierSize = 5;
        // riftTierIncrease = 15;
        // riftPowerPerLevel = 10000;
        // riftObjectsSacrificed = 0;
    }

    function ownerSetDescription(string memory desc) external onlyOwner {
        description = desc;
    }

     function ownerSetManaAddress(address addr) external onlyOwner {
        iMana = IMana(addr);
    }

    function ownerSetRiftData(address addr) external onlyOwner {
        iRiftData = IRiftData(addr);
    }

    function addRiftQuest(address addr) external onlyOwner {
        riftQuests[addr] = true;
    }

    function removeRiftQuest(address addr) external onlyOwner {
        riftQuests[addr] = false;
    }

    function ownerUpdateRiftTier(uint8 tierSize, uint8 tierIncrease, uint64 ppl) external onlyOwner {
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

    // READ

    function isBagHolder(uint256 bagId, address owner) _isBagHolder(bagId, owner) external view {}

    function bags(uint256 bagId) external view returns (RiftBag memory) {
        return iRiftData.bags(bagId);
    }
    
    // WRITE

    // pay to charge. only once per day
    function buyCharge(uint256 bagId) external
        _isBagHolder(bagId, _msgSender()) 
        whenNotPaused 
        nonReentrant {
        require(block.timestamp - iRiftData.bags(bagId).lastChargePurchase > 1 days, "Too soon"); 
        iMana.burn(_msgSender(), iRiftData.bags(bagId).level * (bagId < 8001 ? 100 : 10));
        _chargeBag(bagId, 1, iRiftData.bags(bagId).level);
        iRiftData.updateLastChargePurchase(uint64(block.timestamp), bagId);
    }

    function karmaCharge(uint256 bagId) external
        _isBagHolder(bagId, _msgSender())
        topKarmaHolder(_msgSender())
        whenNotPaused
        nonReentrant {
        require(block.timestamp - iRiftData.bags(bagId).lastChargePurchase > 1 days, "Too soon"); 
        _chargeBag(bagId, 1, iRiftData.bags(bagId).level);
        iRiftData.updateLastChargePurchase(uint64(block.timestamp), bagId);
    }

    function useCharge(uint16 amount, uint256 bagId, address from) 
        _isBagHolder(bagId, from) 
        external 
        whenNotPaused 
        nonReentrant 
    {
        require(riftObjects[msg.sender], "Not of the Rift");
        iRiftData.removeCharges(amount, bagId);
    }

    function awardXP(uint32 bagId, uint16 xp) external nonReentrant {
        require(riftQuests[msg.sender], "only the worthy");
        _awardXP(bagId, xp);
    }

    function _awardXP(uint32 bagId, uint16 xp) internal {
        RiftBag memory bag = iRiftData.bags(bagId);
        uint16 newlvl = bag.level;

        if (bag.level == 0) {
            newlvl = 1;
            _chargeBag(bagId, levelChargeAward[newlvl], newlvl);
        }
        
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

        uint32 _xp = xp + bag.xp;

        while (_xp >= xpRequired[newlvl]) {
            _xp -= xpRequired[newlvl];
            newlvl += 1;
            _chargeBag(bagId, levelChargeAward[newlvl], newlvl);
        }

        iRiftData.updateXP(_xp, bagId);
        iRiftData.updateLevel(newlvl, bagId);
    }

    function _chargeBag(uint256 bagId, uint16 charges, uint16 forLvl) internal {
        iRiftData.addCharges(charges, bagId);
        removeRiftPower(charges * forLvl);
    }

    function setupNewBag(uint256 bagId) external {
        if (iRiftData.bags(bagId).level == 0) {
            iRiftData.updateLevel(1, bagId);    
            _chargeBag(bagId,levelChargeAward[1], 1);
        }        
    }

    function growTheRift(address burnableAddr, uint256 tokenId , uint256 bagId) _isBagHolder(bagId, msg.sender) external {
        require(riftObjects[burnableAddr], "Not of the Rift");
        require(ERC721(burnableAddr).ownerOf(tokenId) == _msgSender(), "Must be yours");
        
        _sacrificeRiftObject(burnableAddr, tokenId, bagId);
    }

    function _sacrificeRiftObject(address burnableAddr, uint256 tokenId, uint256 bagId) internal {
        BurnableObject memory bo = IRiftBurnable(burnableAddr).burnObject(tokenId);
        ERC721BurnableUpgradeable(burnableAddr).burn(tokenId);

        addRiftPower(bo.power);
        iRiftData.addKarma(bo.power, msg.sender);
        riftObjectsSacrificed += 1;     

        _awardXP(uint32(bagId), bo.xp);
        iMana.ccMintTo(_msgSender(), bo.mana, 0);
    }

    // Rift Power
    function addRiftPower(uint64 power) internal {
        riftTierPower += power;
        riftLevel = uint32(riftTierPower/riftPowerPerLevel);

        // up a tier
        if (riftLevel > (riftTier * riftTierSize)) {
            riftTierPower -= riftTierSize * riftPowerPerLevel;
            riftTier += 1;
            riftPowerPerLevel += (riftPowerPerLevel * riftTierIncrease)/100; // add increase as a percentage
        }
    }

    function removeRiftPower(uint64 power) internal {
        if (power > riftTierPower) {
            riftTierPower = 0;
        } else {
            riftTierPower -= power;
        }

        riftLevel = uint32(riftTierPower/riftPowerPerLevel);
    }

    // MODIFIERS

    modifier topKarmaHolder(address holder) {
        uint256 medianKarma = iRiftData.karmaTotal() / iRiftData.karmaHolders();
        require(iRiftData.karma(holder) > (medianKarma * 2), "Not enough karma");
        _;
    }

     modifier _isBagHolder(uint256 bagId, address owner) {
        if (bagId < 8001) {
            require(iLoot.ownerOf(bagId) == owner, "UNAUTH");
        } else if (bagId > glootOffset) {
            require(iGLoot.ownerOf(bagId - glootOffset) == owner, "UNAUTH");
        } else {
            require(iMLoot.ownerOf(bagId) == owner, "UNAUTH");
        }
        _;
    }
}