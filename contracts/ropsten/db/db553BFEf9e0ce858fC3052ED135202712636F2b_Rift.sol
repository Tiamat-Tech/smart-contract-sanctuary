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

import "./Interfaces.sol";
import "./IRift.sol";

contract Rift is ReentrancyGuard, Pausable, Ownable {

    event BagCharged(address owner, uint256 tokenId, uint16 amount);
    event ChargesConsumed(address owner, uint256 tokenId, uint16 amount);
    // event CrystalSacrificed(address owner, uint256 tokenId, uint256 powerIncrease);

    ERC721 public iLoot;
    ERC721 public iMLoot;
    address public riftQuests;
  // IMana public iMana;

    string public description = "The Great Unknown";

    uint256 public riftPower = 100000;
    uint256 public riftObjectsSacrificed = 0;

    mapping(uint256 => RiftBag) public bags;
    mapping(address => uint256) public karma;
    mapping(uint16 => uint16) public xpRequired;
    mapping(uint16 => uint16) public levelChargeAward;
    mapping(address => bool) riftObjects;

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

    function ownerSetRiftQuestsAddress(address addr) public onlyOwner {
        riftQuests = addr;
    }

    /**
    * enables an address to mint / burn
    * @param controller the address to enable
    */
    function addRiftObject(address controller) external onlyOwner {
        riftObjects[controller] = true;
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

  // function ownerSetManaAddress(address addr) public onlyOwner {
  //     iMana = IMana(addr);
  // }

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
    
    // WRITE

    // pay to charge
    // function chargeBag(uint256 bagId) external whenNotPaused nonReentrant {
    //     require(bagsMap[bagId].isCharged == false, "already charged");

    //     isBagHolder(bagId, _msgSender());

    //     uint256 cost = 0;
    //     // first taste is always free
    //     if (bagsMap[bagId].generation > 0) {
    //         require(riftCost[bagsMap[bagId].generation + 1].manaCost > 0, "GEN NOT AVL"); 
    //         cost = getRegistrationCost(bagsMap[bagId].generation + 1);
    //         if (bagId > 8000) cost = cost / 10; // mLoot discount
    //     }

    //     iMana.burn(_msgSender(), cost);
    //     bagsMap[bagId].isCharged = true;

    //     generationRegistry[bagsMap[bagId].generation + 1] += 1;
    // }

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

     function awardXP(uint32 bagId, uint32 xp) external nonReentrant {
        require(_msgSender() == riftQuests, "only the worthy");
    
        if (bags[bagId].level == 0) {
            bags[bagId].level = 1;
            bags[bagId].charges = 1;
        }

        bags[bagId].xp += xp;
        
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
            bags[bagId].charges += levelChargeAward[bags[bagId].level];
            riftPower -= levelChargeAward[bags[bagId].level] * bags[bagId].level;
        }
    }

    function growTheRift(address burnableAddr, uint256 tokenId) external {
        require(riftObjects[msg.sender], "Not of the Rift");
        _sacrificeRiftObject(burnableAddr, tokenId);
    }

    function _sacrificeRiftObject(address burnableAddr, uint256 tokenId) internal {
        uint256 powerIncrease = IRiftBurnable(burnableAddr).riftPower(tokenId);
        (bool success,) = address(burnableAddr).delegatecall(
            abi.encodeWithSignature("burn(uint256)", tokenId)
        );

        if (success) {
            riftPower += powerIncrease;
            karma[_msgSender()] += powerIncrease;
            riftObjectsSacrificed += 1;
            // emit CrystalSacrificed(_msgSender(), crystalId, powerIncrease);
        }
    }
}