/*

 ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄       ▄▄▄▄▄▄▄▄▄▄   ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄ 
▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌     ▐░░░░░░░░░░▌ ▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌
▐░█▀▀▀▀▀▀▀█░▌ ▀▀▀▀█░█▀▀▀▀ ▐░█▀▀▀▀▀▀▀▀▀  ▀▀▀▀█░█▀▀▀▀      ▐░█▀▀▀▀▀▀▀█░▌▐░█▀▀▀▀▀▀▀█░▌ ▀▀▀▀█░█▀▀▀▀ ▐░█▀▀▀▀▀▀▀█░▌
▐░▌       ▐░▌     ▐░▌     ▐░▌               ▐░▌          ▐░▌       ▐░▌▐░▌       ▐░▌     ▐░▌     ▐░▌       ▐░▌
▐░█▄▄▄▄▄▄▄█░▌     ▐░▌     ▐░█▄▄▄▄▄▄▄▄▄      ▐░▌          ▐░▌       ▐░▌▐░█▄▄▄▄▄▄▄█░▌     ▐░▌     ▐░█▄▄▄▄▄▄▄█░▌
▐░░░░░░░░░░░▌     ▐░▌     ▐░░░░░░░░░░░▌     ▐░▌          ▐░▌       ▐░▌▐░░░░░░░░░░░▌     ▐░▌     ▐░░░░░░░░░░░▌
▐░█▀▀▀▀█░█▀▀      ▐░▌     ▐░█▀▀▀▀▀▀▀▀▀      ▐░▌          ▐░▌       ▐░▌▐░█▀▀▀▀▀▀▀█░▌     ▐░▌     ▐░█▀▀▀▀▀▀▀█░▌
▐░▌     ▐░▌       ▐░▌     ▐░▌               ▐░▌          ▐░▌       ▐░▌▐░▌       ▐░▌     ▐░▌     ▐░▌       ▐░▌
▐░▌      ▐░▌  ▄▄▄▄█░█▄▄▄▄ ▐░▌               ▐░▌          ▐░█▄▄▄▄▄▄▄█░▌▐░▌       ▐░▌     ▐░▌     ▐░▌       ▐░▌
▐░▌       ▐░▌▐░░░░░░░░░░░▌▐░▌               ▐░▌          ▐░░░░░░░░░░▌ ▐░▌       ▐░▌     ▐░▌     ▐░▌       ▐░▌
 ▀         ▀  ▀▀▀▀▀▀▀▀▀▀▀  ▀                 ▀            ▀▀▀▀▀▀▀▀▀▀   ▀         ▀       ▀       ▀         ▀ 
     by chris and tony                                                                                                       
*/

// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

struct RiftBag {
        uint16 charges;
        uint32 chargesUsed;
        uint16 level;
        uint32 xp;
        uint64 lastChargePurchase;
    }

interface IRiftData {
    function bags(uint256 bagId) external view returns (RiftBag memory);
    function addCharges(uint16 charges, uint256 bagId) external;
    function removeCharges(uint16 charges, uint256 bagId) external;
    function updateLevel(uint16 level, uint256 bagId) external;
    function updateXP(uint32 xp, uint256 bagId) external;
    function addKarma(uint64 k, address holder) external;
    function removeKarma(uint64 k, address holder) external;
    function updateLastChargePurchase(uint64 time, uint256 bagId) external;
}

/*
    Logic free storage of Rift Data. 
    The intent of this storage is twofold:
    1. The data manipulation performed by the Rift is novel (especially to the authors), 
        and this store acts as a failsafe in case a new Rift contract needs to be deployed.
    2. The authors' intent is to grant control of this data to more controllers (a DAO, L2 rollup, etc).
*/
contract RiftData is IRiftData, ReentrancyGuard, Pausable, Ownable {
    mapping(address => bool) public riftControllers;

    uint256 internal karmaTotal;
    uint256 internal karmaHolders;

    mapping(uint256 => RiftBag) internal _bags;
    mapping(address => uint64) public karma;

    function addRiftController(address addr) external onlyOwner {
        riftControllers[addr] = true;
    }

    function removeRiftController(address addr) external onlyOwner {
        riftControllers[addr] = false;
    }

    modifier onlyRiftController() {
        require(riftControllers[msg.sender], "NO!");
        _;
    }

    function bags(uint256 bagId) external view override returns (RiftBag memory) {
        return _bags[bagId];
    }

    function addCharges(uint16 charges, uint256 bagId) external override onlyRiftController {
        _bags[bagId].charges += charges;
    }

    function removeCharges(uint16 charges, uint256 bagId) external override onlyRiftController {
        require(_bags[bagId].charges >= charges, "Not enough charges");
        _bags[bagId].charges -= charges;
        _bags[bagId].chargesUsed += charges;
    }

    function updateLevel(uint16 level, uint256 bagId) external override onlyRiftController {
        _bags[bagId].level = level;
    }

    function updateXP(uint32 xp, uint256 bagId) external override onlyRiftController {
        _bags[bagId].xp = xp;
    }

    function addKarma(uint64 k, address holder) external override onlyRiftController {
        karma[holder] += k;
    }

    function removeKarma(uint64 k, address holder) external override onlyRiftController {
        k > karma[holder] ? karma[holder] = 0 : karma[holder] -= k;
    }

    function updateLastChargePurchase(uint64 time, uint256 bagId) external override onlyRiftController {
        _bags[bagId].lastChargePurchase = time;
    }
}