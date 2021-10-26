// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interfaces/IMetasaurs.sol";


/**
 * ╔═╗╔═╗░░╔╗░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
 * ║║╚╝║║░╔╝╚╗░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
 * ║╔╗╔╗╠═╩╗╔╬══╦══╦══╦╗╔╦═╦══╗  Metasaurs - Mystery Chest NFT  ░░░░░░░░░░░░░░░
 * ║║║║║║║═╣║║╔╗║══╣╔╗║║║║╔╣══╣  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
 * ║║║║║║║═╣╚╣╔╗╠══║╔╗║╚╝║║╠══║  Website: https://www.metasaurs.com/  ░░░░░░░░░
 * ╚╝╚╝╚╩══╩═╩╝╚╩══╩╝╚╩══╩╝╚══╝  Discord: https://discord.com/invite/metasaurs
 *
 * @notice An NFT token of Mystery Chest for Metasaurs
 * @dev Each chest carries a certain bonus. The chest burns out after use. We
 * are using the EIP-1967 Transparent Proxy pattern to be able to update game
 * mechanics in the future.
 * @custom:security-contact [email protected]
 */
contract MysteryChest is Initializable, ERC721Upgradeable, ERC721URIStorageUpgradeable, AccessControlUpgradeable, ERC721BurnableUpgradeable {
    /// @notice Contract roles
    bytes32 public constant LOTTERY_ROLE = keccak256("LOTTERY_ROLE");

    /// @notice Public address for users
    address public metasaurs_address;

    /// @notice MTS interface
    IMetasaurs internal metasaurs;

    /// @notice List of already claimed chests
    mapping(uint256 => bool) public isChestClaimed;

    /// @notice List of chest types
    mapping(uint256 => uint8) public chestTypes;

    /// @notice Time until which you can get your chests
    uint256 public claimEndAt;

    /// @notice The types of chests and their bonuses will be announced later
    uint8 public typesList;

    /// @notice Base URI for token URI
    string public baseURI;

    /// @notice When new chest minted
    event NewChest(address user, uint256 tokenId);

    /// @notice When new chest minted
    event ChestOpened(uint256 tokenId, uint8 chestType);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(address _metasaurs, uint256 _claimEndAt) initializer public {
        __ERC721_init("Mystery Chest", "MCH");
        __ERC721URIStorage_init();
        __AccessControl_init();
        __ERC721Burnable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(LOTTERY_ROLE, msg.sender);

        metasaurs_address = _metasaurs;
        metasaurs = IMetasaurs(_metasaurs);
        claimEndAt = _claimEndAt;
    }

    /**
     * @dev Only if the claimable period is not over
     */
    modifier claimable() {
        require(block.timestamp <= claimEndAt, "claiming period is over");
        _;
    }

    /**
     * @notice Set the number of types of chests
     * @param types - Number of types
     */
    function setChestTypes(uint8 types) external onlyRole(LOTTERY_ROLE) {
        typesList = types;
    }

    /**
     * @notice Set baseURI param
     * @param newBaseURI - New base URI
     */
    function setBaseURI(string memory newBaseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseURI = newBaseURI;
    }

    /**
     * @notice Set the number of types of chests
     * @param chestId - Number of types
     * @param chestType - Type of chest
     */
    function updateChest(uint256 chestId, uint8 chestType) external onlyRole(LOTTERY_ROLE) {
        require(typesList > 0, "set types first");
        require(chestType > 0, "num is too low");
        require(typesList >= chestType, "num is too big");
        require(chestId <= 9999, "exceeded max amount");
        chestTypes[chestId] = chestType;
    }

    /**
     * @notice Claim tokens
     * @param tokenIds - Array of Metasaur token IDs
     * @return True on success
     */
    function claim(uint256[] memory tokenIds) external claimable returns(bool) {
        for (uint16 i = 0; i < tokenIds.length; i++) {
            require(_claim(tokenIds[i]));
        }
        return true;
    }

    /**
     * @notice Get array of unclaimed metasaurs id
     * @return Array of unclaimed tokens
     */
    function checkUnclaimed() external view returns(uint256[] memory) {
        return _checkUnclaimed(msg.sender);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    /**
     * @notice Claim token
     * @param tokenId - Metasaur token ID
     * @return True on success
     */
    function _claim(uint256 tokenId) private returns(bool) {
        require(metasaurs.ownerOf(tokenId) == msg.sender, "not your token");
        isChestClaimed[tokenId] = true;
        _safeMint(msg.sender, tokenId);
        emit NewChest(msg.sender, tokenId);
        return true;
    }

    /**
     * @notice Get array of unclaimed tokens
     * @param holder - Metasaur token owner
     * @return Array of unclaimed tokens
     */
    function _checkUnclaimed(address holder) private view returns(uint256[] memory) {
        uint256[] memory myMetasaurs = metasaurs.tokensOfOwner(holder);
        require(myMetasaurs.length > 0, "you have 0 metasaurs");
        uint256[] memory unclaimed;
        for (uint256 i = 0; i < myMetasaurs.length; i++) {
            if (!isChestClaimed[myMetasaurs[i]]) {
                unclaimed[i] = myMetasaurs[i];
            }
        }
        return unclaimed;
    }

    /// @notice This hook is launched before the start of the transfer
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
    internal
    override
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @notice "Open" chest
     * @dev This will be done by a lottery contract
     * @param tokenId - Chest ID
     */
    function _burn(uint256 tokenId)
    internal
    onlyRole(LOTTERY_ROLE)
    override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
        emit ChestOpened(tokenId, chestTypes[tokenId]);
    }

    function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721Upgradeable, AccessControlUpgradeable)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}