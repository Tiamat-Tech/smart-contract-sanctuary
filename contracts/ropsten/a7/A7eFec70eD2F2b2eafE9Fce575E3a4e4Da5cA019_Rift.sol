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

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";

import "./Interfaces.sol";
import "./IRift.sol";

/*
    You've heard it calling... 
    Now it's time to level up your Adventure!
    Enter The Rift, and gain its power. 
    Take too much, and all suffer.
    Return what you've gained, and all benefit.. 
*/

contract Rift is Initializable, ReentrancyGuardUpgradeable, PausableUpgradeable, OwnableUpgradeable {

    event AddCharge(address indexed owner, uint256 indexed tokenId, uint16 amount, uint16 forLvl);
    event AwardXP(uint256 indexed tokenId, uint256 amount);
    event UseCharge(address indexed owner, address indexed riftObject, uint256 indexed tokenId, uint16 amount);
    event ObjectSacrificed(address indexed owner, address indexed object, uint256 tokenId, uint256 indexed bagId, uint256 powerIncrease);

    // The Rift supports 8000 Loot bags
    // 9989460 mLoot Bags (34 years worth)
    // and 2540 gLoot Bags
    IERC721 public iLoot;
    IERC721 public iMLoot;
    IERC721 public iGLoot;
    IMana public iMana;
    IRiftData public iRiftData;
    // gLoot bags must offset their bagId by adding gLootOffset when interacting
    uint32 constant glootOffset = 9997460;

    string public description;

    /*
     Rift power will decrease as bags level up and gain charges.
     Charges will create Rift Objects.
     Rift Objects can be burned into the Rift to amplify its power.
     If Rift Level reaches 0, no more charges are created.
    */
    uint32 public riftLevel;
    uint256 public riftPower;

    uint8 internal riftLevelIncreasePercentage; 
    uint8 internal riftLevelDecreasePercentage; 
    uint256 internal riftLevelMinThreshold;
    uint256 internal riftLevelMaxThreshold;
    uint256 internal riftCallibratedTime; 

    uint64 public riftObjectsSacrificed;

    mapping(uint16 => uint16) public levelChargeAward;
    mapping(address => bool) public riftObjects;
    mapping(address => bool) public riftQuests;
    address[] public riftObjectsArr;

    function initialize(address lootAddr, address mlootAddr, address glootAddr) public initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        iLoot = IERC721(lootAddr);
        iMLoot = IERC721(mlootAddr);
        iGLoot = IERC721(glootAddr);

        description = "The Rift inbetween";

        riftLevel = 2;
        riftLevelIncreasePercentage = 10; 
        riftLevelDecreasePercentage = 9;
        riftLevelMinThreshold = 21000;
        riftLevelMaxThreshold = 33100;
        riftPower = 35000;
        riftObjectsSacrificed = 0;
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
        require(riftLevel > 0, "rift has no power");
        iMana.burn(_msgSender(), iRiftData.bags(bagId).level * ((bagId < 8001 || bagId > glootOffset) ? 100 : 10));
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
        
        emit UseCharge(from, _msgSender(), bagId, amount);
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

        uint64 _xp = uint64(xp + bag.xp);

        while (_xp >= xpRequired(newlvl)) {
            _xp -= xpRequired(newlvl);
            newlvl += 1;
            _chargeBag(bagId, levelChargeAward[newlvl], newlvl);
        }

        iRiftData.updateXP(_xp, bagId);
        iRiftData.updateLevel(newlvl, bagId);
        emit AwardXP(bagId, xp);
    }

    function xpRequired(uint32 level) public pure returns (uint64) {
        if (level == 1) { return 65; }
        else if (level == 2) { return 130; }
        else if (level == 3) { return 260; }
        
        return uint64(260*(115**(level-3))/(100**(level-3)));
    }

    function _chargeBag(uint256 bagId, uint16 charges, uint16 forLvl) internal {
        if (riftLevel == 0) {
            return; // no power in the rift
        }
        if (charges == 0) {
            charges = forLvl/10;
            charges += forLvl%5 == 0 ? 1 : 0; // bonus on every fifth lvl
            charges += forLvl%10 == 0 ? 1 : 0; // bonus bonus on every tenth
        }
        if ((charges * forLvl) > riftPower) {
            riftPower = 0;
        } else {
            riftPower -= (charges * forLvl);
        }
        iRiftData.addCharges(charges, bagId);
        emit AddCharge(_msgSender(), bagId, charges, forLvl);
    }

    function setupNewBag(uint256 bagId) external {
        if (iRiftData.bags(bagId).level == 0) {
            iRiftData.updateLevel(1, bagId);    
            _chargeBag(bagId,levelChargeAward[1], 1);
        }        
    }

    function growTheRift(address burnableAddr, uint256 tokenId , uint256 bagId) _isBagHolder(bagId, msg.sender) external {
        require(riftObjects[burnableAddr], "Not of the Rift");
        require(IERC721(burnableAddr).ownerOf(tokenId) == _msgSender(), "Must be yours");
        
        _sacrificeRiftObject(burnableAddr, tokenId, bagId);
    }

    function growTheRiftRewards(address burnableAddr, uint256 tokenId) external view returns (BurnableObject memory) {
        return IRiftBurnable(burnableAddr).burnObject(tokenId);
    }

    function _sacrificeRiftObject(address burnableAddr, uint256 tokenId, uint256 bagId) internal {
        BurnableObject memory bo = IRiftBurnable(burnableAddr).burnObject(tokenId);
        ERC721BurnableUpgradeable(burnableAddr).burn(tokenId);

        riftPower += bo.power;
        iRiftData.addKarma(bo.power, msg.sender);
        riftObjectsSacrificed += 1;     

        _awardXP(uint32(bagId), bo.xp);
        iMana.ccMintTo(_msgSender(), bo.mana);
        emit ObjectSacrificed(_msgSender(), burnableAddr, tokenId, bagId, bo.power);
    }

    // Rift Power

    function recalibrateRift() external {
        require(block.timestamp - riftCallibratedTime >= 1 hours, "wait");
        if (riftPower >= riftLevelMaxThreshold) {
            // up a level
            riftLevel += 1;
            uint256 riftLevelPower = riftLevelMaxThreshold - riftLevelMinThreshold;
            riftLevelMinThreshold = riftLevelMaxThreshold;
            riftLevelMaxThreshold += riftLevelPower + (riftLevelPower * riftLevelIncreasePercentage)/100;
        } else if (riftPower < riftLevelMinThreshold) {
            // down a level
            if (riftLevel == 1) {
                riftLevel = 0;
                riftLevelMinThreshold = 0;
                riftLevelMaxThreshold = 10000;
            } else {
                riftLevel -= 1;
                uint256 riftLevelPower = riftLevelMaxThreshold - riftLevelMinThreshold;
                riftLevelMaxThreshold = riftLevelMinThreshold;
                riftLevelMinThreshold -= riftLevelPower + (riftLevelPower * riftLevelDecreasePercentage)/100;
            }
        }

        iMana.ccMintTo(msg.sender, (block.timestamp - riftCallibratedTime) / (3600) * 10 * riftLevel);
        riftCallibratedTime = block.timestamp;
    }

    // MODIFIERS

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