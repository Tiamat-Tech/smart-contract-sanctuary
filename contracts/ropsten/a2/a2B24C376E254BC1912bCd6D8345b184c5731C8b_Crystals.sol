/*

 _______  _______           _______ _________ _______  _        _______ 
(  ____ \(  ____ )|\     /|(  ____ \\__   __/(  ___  )( \      (  ____ \   (for Adventurers) 
| (    \/| (    )|( \   / )| (    \/   ) (   | (   ) || (      | (    \/
| |      | (____)| \ (_) / | (_____    | |   | (___) || |      | (_____ 
| |      |     __)  \   /  (_____  )   | |   |  ___  || |      (_____  )
| |      | (\ (      ) (         ) |   | |   | (   ) || |            ) |
| (____/\| ) \ \__   | |   /\____) |   | |   | )   ( || (____/\/\____) |
(_______/|/   \__/   \_/   \_______)   )_(   |/     \|(_______/\_______)   
    by chris and tony
    
*/
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./Interfaces.sol";
import "./IRift.sol";

/// @title Loot Crystals from the Rift
contract Crystals is
    ERC721,
    IERC2981,
    ERC721Burnable,
    ReentrancyGuard,
    Ownable,
    Pausable,
    IRiftBurnable
{
    struct GenerationMintRequirement {
        uint256 manaCost;
    }

    event ManaClaimed(address owner, uint256 tokenId, uint256 amount);
    event CrystalLeveled(address owner, uint256 tokenId, uint256 level);

    ICrystalsMetadata public iMetadata;
    ICrystalManaCalculator public iCalculator;

    IMana public iMana;
    IRift public iRift;
    address internal riftAddress;
    
    uint8 public maxFocus = 10;
    uint32 private constant GEN_THRESH = 10000000;
    uint32 private constant glootOffset = 9997460;

    uint64 public mintedCrystals;

    uint256 public mintFee = 0.05 ether;
    uint256 public mMintFee = 0.01 ether;
    uint16[] private xpTable = [15,30,50,75,110,155,210,280,500,800];

    /// @dev indexed by bagId + (GEN_THRESH * bag generation) == tokenId
    mapping(uint256 => Crystal) public crystalsMap;
    mapping(uint256 => Bag) public bags;

    address private openSeaProxyRegistryAddress;
    bool private isOpenSeaProxyActive = false;

    constructor(address manaAddress) ERC721("Loot Crystals", "CRYSTAL") Ownable() {
        iMana = IMana(manaAddress);
    }

    //WRITE

    function firstMint(uint256 bagId) 
        external
        payable
        whenNotPaused
        nonReentrant
    {
        require(iRift.bags(bagId).level == 0, "Use mint crystal");
        if (bagId < 8001 || bagId > glootOffset) {
            require(msg.value == mintFee, "FEE");
        } else {
            require(msg.value == mMintFee, "FEE");
        }
        // set up bag in rift and give it a charge
        iRift.setupNewBag(bagId);

        _mintCrystal(bagId);
    }

    // lock to level 2 or higher
    function mintCrystal(uint256 bagId)
        external
        whenNotPaused
        nonReentrant
    {
        require(iRift.bags(bagId).level > 0, "Use first mint");

        _mintCrystal(bagId);
    }

    function _mintCrystal(uint256 bagId) internal {
        iRift.useCharge(1, bagId, _msgSender());

        uint256 tokenId = getNextCrystal(bagId);

        bags[tokenId % GEN_THRESH].mintCount += 1;
        crystalsMap[tokenId].attunement = iRift.bags(bagId).level;
        crystalsMap[tokenId].focus = 1;
        crystalsMap[tokenId].lastClaim = uint64(block.timestamp - (24 * 60 * 60));
        crystalsMap[tokenId].regNum = uint32(mintedCrystals);

        iRift.awardXP(uint32(bagId), 50 + (15 * (iRift.bags(bagId).level - 1)));
        mintedCrystals += 1;
        _safeMint(_msgSender(), tokenId);
    }

    function claimCrystalMana(uint256 tokenId)
        external
        whenNotPaused
        ownsCrystal(tokenId)
        nonReentrant
    {
        require(crystalsMap[tokenId].lvlClaims < iRift.riftLevel(), "Rift not powerful enough for this action");
        uint32 manaToProduce = iCalculator.claimableMana(tokenId);
        require(manaToProduce > 0, "NONE");
        crystalsMap[tokenId].lastClaim = uint64(block.timestamp);
        crystalsMap[tokenId].levelManaProduced += manaToProduce;
        crystalsMap[tokenId].lvlClaims += 1;
        bags[tokenId % GEN_THRESH].totalManaProduced += manaToProduce;
        iMana.ccMintTo(_msgSender(), manaToProduce, 1);
        emit ManaClaimed(_msgSender(), tokenId, manaToProduce);
    }

    function levelUpCrystal(uint256 tokenId)
        external
        whenNotPaused
        ownsCrystal(tokenId)
        nonReentrant
    {
        Crystal memory crystal = crystalsMap[tokenId];
        require(crystal.focus < maxFocus, "MAX");
        require(
            diffDays(
                crystal.lastClaim,
                block.timestamp
            ) >= crystal.focus, "WAIT"
        );
        uint256 claimableMana = iCalculator.claimableMana(tokenId);

        // mint extra mana
        if (claimableMana > (crystal.focus * getResonance(tokenId))) {
            iMana.ccMintTo(_msgSender(), claimableMana - (crystal.focus * getResonance(tokenId)), 1);
        }

        crystalsMap[tokenId] = Crystal({
            focus: crystal.focus + 1,
            lastClaim: uint64(block.timestamp),
            levelManaProduced: 0,
            attunement: crystal.attunement,
            regNum: crystal.regNum,
            lvlClaims: 0
        });

        emit CrystalLeveled(_msgSender(), tokenId, crystal.focus);
    }

    // READ 
    function getResonance(uint256 tokenId) public view returns (uint32) {
        // 1 or 2 per focus                             loot vs mloot multiplier               generation bonus
        return uint32(getLevelRolls(tokenId, "%RES", 2, 1)
            * (isOGCrystal(tokenId) ? 10 : 1)
            * attunementBonus(crystalsMap[tokenId].attunement));
    }

    // 10% increase per generation
    function attunementBonus(uint16 genNum) internal pure returns (uint32) {
        // first gen
        if (genNum == 0) {
            return 1;
        } else {
            return (attunementBonus(genNum - 1) * 110) / 100;
        }
    }

    function getSpin(uint256 tokenId) public view returns (uint32) {
        uint32 multiplier = isOGCrystal(tokenId) ? 10 : 1;
        return uint32(((88 * (crystalsMap[tokenId].focus)) + (getLevelRolls(tokenId, "%SPIN", 4, 1) * multiplier))
            * attunementBonus(crystalsMap[tokenId].attunement));
    }

    // rift burnable
    function burnObject(uint256 tokenId) external view override returns (BurnableObject memory) {
        require(diffDays(crystalsMap[tokenId].lastClaim, block.timestamp) >= crystalsMap[tokenId].focus, "not ready");
        return BurnableObject({
            power: (crystalsMap[tokenId].focus * crystalsMap[tokenId].attunement / 2) == 0 ?
                    1 :
                    crystalsMap[tokenId].focus * crystalsMap[tokenId].attunement / 2,
            mana: getSpin(tokenId),
            xp: crystalsMap[tokenId].attunement * xpTable[crystalsMap[tokenId].focus - 1]
        });
    }

    /**
     * @dev Return the token URI through the Loot Expansion interface
     * @param lootId The Loot Character URI
     */
    function getLootExpansionTokenUri(uint256 lootId) external view returns (string memory) {
        return tokenURI(lootId);
    }

    function getNextCrystal(uint256 bagId) internal view returns (uint256) {
        return bags[bagId].mintCount * GEN_THRESH + bagId;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

     function tokenURI(uint256 tokenId) 
        public
        view
        override
        returns (string memory) 
    {
        require(address(iMetadata) != address(0), "no addr set");
        return iMetadata.tokenURI(tokenId);
    }

    // OWNER

    function ownerUpdateMaxLevel(uint8 maxFocus_) external onlyOwner {
        require(maxFocus > maxFocus, "INV");
        maxFocus = maxFocus_;
    }

    // function to disable gasless listings for security in case
    // opensea ever shuts down or is compromised
    function setIsOpenSeaProxyActive(bool _isOpenSeaProxyActive)
        external
        onlyOwner
    {
        isOpenSeaProxyActive = _isOpenSeaProxyActive;
    }

    function ownerSetOpenSeaProxy(address addr) external onlyOwner {
        openSeaProxyRegistryAddress = addr;
    }

    function ownerSetCalculatorAddress(address addr) external onlyOwner {
        iCalculator = ICrystalManaCalculator(addr);
    }

    function ownerSetRiftAddress(address addr) external onlyOwner {
        iRift = IRift(addr);
        riftAddress = addr;
    }

    function ownerSetManaAddress(address addr) external onlyOwner {
        iMana = IMana(addr);
    }

    function ownerSetMetadataAddress(address addr) external onlyOwner {
        iMetadata = ICrystalsMetadata(addr);
    }

    function ownerWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function setPaused(bool _paused) external onlyOwner {
        if (_paused) _pause();
        else _unpause();
    }

    // HELPER

    function isOGCrystal(uint256 tokenId) internal pure returns (bool) {
        // treat OG Loot and GA Crystals as OG
        return tokenId % GEN_THRESH < 8001 || tokenId % GEN_THRESH > glootOffset;
    }

    function diffDays(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256)
    {
        require(fromTimestamp <= toTimestamp);
        return (toTimestamp - fromTimestamp) / (24 * 60 * 60);
    }

    function getLevelRolls(
        uint256 tokenId,
        string memory key,
        uint256 size,
        uint256 times
    ) internal view returns (uint256) {
        uint8 index = 1;
        uint256 score = getRoll(tokenId, key, size, times);
        uint8 focus = crystalsMap[tokenId].focus;

        while (index < focus) {
            score += ((
                random(string(abi.encodePacked(
                    (index * GEN_THRESH) + tokenId,
                    key
                ))) % size
            ) + 1) * times;

            index++;
        }

        return score;
    }

    /// @dev returns random number based on the tokenId
    function getRandom(uint256 tokenId, string memory key)
        internal
        view
        returns (uint256)
    {
        return random(string(abi.encodePacked(tokenId, key, crystalsMap[tokenId].regNum)));
    }

    /// @dev returns random roll based on the tokenId
    function getRoll(
        uint256 tokenId,
        string memory key,
        uint256 size,
        uint256 times
    ) internal view returns (uint256) {
        return ((getRandom(tokenId, key) % size) + 1) * times;
    }

    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input, "%RIFT-OPEN")));
    }

    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT license
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721) {
        super._burn(tokenId);
    }

    modifier ownsCrystal(uint256 tokenId) {
        require(ownerOf(tokenId) == _msgSender(), "UNAUTH");
        _;
    }

    /**
     * @dev Override isApprovedForAll to allowlist user's OpenSea proxy accounts to enable gas-less listings.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        override
        returns (bool)
    {
        // Get a reference to OpenSea's proxy registry contract by instantiating
        // the contract using the already existing address.
        ProxyRegistry proxyRegistry = ProxyRegistry(
            openSeaProxyRegistryAddress
        );
        if (
            isOpenSeaProxyActive &&
            address(proxyRegistry.proxies(owner)) == operator
        ) {
            return true;
        }

        if (operator == riftAddress) { return true; }
        return super.isApprovedForAll(owner, operator);
    }

    /**
     * @dev See {IERC165-royaltyInfo}.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        require(_exists(tokenId), "Nonexistent token");

        return (address(this), SafeMath.div(SafeMath.mul(salePrice, 5), 100));
    }
}

// These contract definitions are used to create a reference to the OpenSea
// ProxyRegistry contract by using the registry's address (see isApprovedForAll).
contract OwnableDelegateProxy {

}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}