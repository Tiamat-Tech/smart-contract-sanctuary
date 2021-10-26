// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
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
 * @dev Each chest carries a certain bonus. The chest burns out after use.
 * @custom:security-contact [email protected]
 */
contract MysteryChest is Initializable, ERC721Upgradeable, ERC721URIStorageUpgradeable, PausableUpgradeable, AccessControlUpgradeable, ERC721BurnableUpgradeable {
    /// @notice Contract roles
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @notice Public address for users
    address public metasaurs_address;

    /// @notice MTS interface
    IMetasaurs internal metasaurs;

    /// @notice List of already claimed chests
    mapping(uint256 => bool) public isChestClaimed;

    /// @notice Time until which you can get your chests
    uint256 public claimEndAt;

    /// @notice When new chest minted
    event NewChest(address user, uint256 tokenId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(address _metasaurs, uint256 _claimEndAt) initializer public {
        __ERC721_init("Mystery Chest", "MCH");
        __ERC721URIStorage_init();
        __Pausable_init();
        __AccessControl_init();
        __ERC721Burnable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        _setupRole(BURNER_ROLE, msg.sender);

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
     * @notice Claim one token
     * @param tokenId - Metasaur token ID
     * @return True on success
     */
    function claim(uint256 tokenId) external claimable returns(bool) {
        require(!isChestClaimed[tokenId], "already claimed");
        require(metasaurs.ownerOf(tokenId) == msg.sender, "this is not your metasaur");
        require(_claim(tokenId), "something went wrong");
        return true;
    }

    /**
     * @notice Get your mystery chest
     * @dev Claim is possible if the caller of the function owns the metasaurs
     * and the claim period has not ended.
     * @return True on success
     */
    function claimAll() external claimable returns(bool) {
        uint256[] memory unclaimed = _checkUnclaimed(msg.sender);
        require(unclaimed.length > 0, "nothing to claim");
        for (uint256 i = 0; i < unclaimed.length; i++) {
            require(_claim(unclaimed[i]), "something went wrong");
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

    /**
     * @notice Claim token
     * @param tokenId - Metasaur token ID
     * @return True on success
     */
    function _claim(uint256 tokenId) public returns(bool) {
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

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function safeMint(address to, uint256 tokenId) public {
        _safeMint(to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
    internal
    whenNotPaused
    override
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
    internal
    onlyRole(BURNER_ROLE)
    override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
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