// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./SystemContext.sol";

/**
 * @title ERC721Mintable
 * ERC721Mintable - ERC721 contract that allows to mint some tokens with id range
 */
contract ERC721Mintable is ERC721Enumerable, AccessControl {

    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    event TokenUrlChanged(uint256 tokenId, string tokenUrl);
    event Fallback(bytes data);

    mapping(uint256 => string) internal tokenUrls;
    bytes32 internal collectionId;
    uint256 internal slotStart;
    uint256 internal slotEnd;
    SystemContext internal system;

    constructor(string memory name_, string memory symbol_, bytes32 collectionId_,
        address owner_, uint256 slotStart_, uint256 slotEnd_, SystemContext system_) ERC721(name_, symbol_) {
        require(slotStart_ < slotEnd_, "Slot start id must be lower than slot end id");
        collectionId = collectionId_;
        slotStart = slotStart_;
        slotEnd = slotEnd_;

        _setupRole(BRIDGE_ROLE, msg.sender);
        _setRoleAdmin(BRIDGE_ROLE, BRIDGE_ROLE);
        _setupRole(DEFAULT_ADMIN_ROLE, owner_);

        system = system_;
        system.getCollectionRegistry().registerCollection(collectionId_, name_, owner_, address(this));
    }

    /**
     * @dev Sets available slot start and slot end ids
     * @param slotStart_ first available mint id
     * @param slotEnd_ last available mint id
     */
    function setSlot(uint256 slotStart_, uint256 slotEnd_) external onlyRole(BRIDGE_ROLE) {
        slotStart = slotStart_;
        slotEnd = slotEnd_;
    }

    /**
     * @dev Sets token url for token with `tokenId_` id
     * @param tokenId_ token whose url is changed
     */
    function setTokenUrl(uint256 tokenId_, string memory tokenUrl_) external {
        tokenUrls[tokenId_] = tokenUrl_;

        emit TokenUrlChanged(tokenId_, tokenUrl_);
    }

    /**
     * @dev Returns token url at `tokenId_`
     * @param tokenId_ token whose url is requested
     */
    function getTokenUrl(uint256 tokenId_) public view returns(string memory) {
        return tokenUrls[tokenId_];
    }

    /**
    * @dev Returns collection identifier`
     */
    function getCollectionId() public view returns (bytes32) {
        return collectionId;
    }

    /**
     * @dev Mints a token to an address.
     * @param _to address of the future owner of the token
     * @param tokenId new token id
     */
    function mintTo(address _to, uint256 tokenId) external {
        if (address(system.getBridge()) != msg.sender) {
            require(slotStart <= tokenId && tokenId <= slotEnd, "Mint id outside of slot range");
            _mint(_to, tokenId);
        } else {
            if (isOwner(address(this), tokenId)) {
                ERC721.transferFrom(address(this), _to, tokenId);
            }
            else {
                _mint(_to, tokenId);
            }
        }
    }

    /**
     * @dev Mints a token to msg.signer.
     */
    function mint(uint256 tokenId) external {
        if (address(system.getBridge()) != msg.sender) {
            require(slotStart <= tokenId && tokenId <= slotEnd, "Mint id outside of slot range");
        }
        _mint(msg.sender, tokenId);
    }

    /**
     * @dev Burns a token of msg.signer.
     */
    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }

    function moveTo(uint16 l0ChainId, bytes calldata destinationBridge, bytes calldata destinationContract, uint256 tokenId) external payable {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        transferFrom(msg.sender, address(this), tokenId);

        system.getBridge().mintOnSecondChain{value: msg.value}(l0ChainId, destinationBridge, destinationContract, msg.sender, msg.sender, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, AccessControl) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId ||
            interfaceId == type(AccessControl).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function isOwner(address _address, uint256 _tokenId) public view returns (bool){
        uint256 balance = balanceOf(_address);
        for (uint256 i = 0; i < balance; i++) {
            if (tokenOfOwnerByIndex(_address, i) == _tokenId) {
                return true;
            }
        }
        return false;
    }
}