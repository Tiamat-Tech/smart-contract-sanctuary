// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/** OPENSEA INTERFACES */
/**
 This is a contract that can act on behalf of an Opensea
 user. It's a proxy for the user
 */
contract OwnableDelegateProxy {}

/**
 This represents Opensea's ProxyRegistry contract.
 We use it to find and approve the opensea proxy contract of each 
 user, which allows for better opensea integration like gassless listing etc.
*/
contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

contract PPPals is AccessControl, Ownable, ERC721Enumerable {
    using Strings for uint256;

    /** ADDRESSES */
    address public openseaProxyRegistryAddress;

    /** NFT DATA */
    string public provenanceHash = "";
    string public baseURIString = "baseURIString";
    uint256 public nextTokenId = 1;

    /** FLAGS */
    bool public isFrozen = false;

    /** ROLES */
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /** MODIFIERS */
    modifier notFrozen() {
        require(!isFrozen, "CONTRACT FROZEN");
        _;
    }

    /** EVENTS */
    event Mint(address to, uint256 amount);
    event ReceivedEther(address sender, uint256 amount);

    constructor(
        string memory _name,
        string memory _symbol,
        address _openseaProxyRegistryAddress
    ) ERC721(_name, _symbol) Ownable() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(BURNER_ROLE, msg.sender);
        openseaProxyRegistryAddress = _openseaProxyRegistryAddress;
    }

    /**
    * @dev returns the baseURI for the metadata. Used by the tokenURI method.
    * @return the URI of the metadata
    */
    function _baseURI() internal override view returns (string memory) {
        return baseURIString;
    }

    /**
     * @dev returns tokenURI of tokenId based on reveal date
     * @return the URI of token tokenid
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        return string(abi.encodePacked(baseURIString, tokenId.toString(), ".json"));        
    }

     /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, ERC721Enumerable) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IAccessControl).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
    * @dev override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-less listings.
    */
    function isApprovedForAll(address owner, address operator)
        override
        public
        view
        returns (bool)
    {
        // Create an instance of the ProxyRegistry contract from Opensea
        ProxyRegistry proxyRegistry = ProxyRegistry(openseaProxyRegistryAddress);
        // whitelist the ProxyContract of the owner of the NFT
        if (address(proxyRegistry.proxies(owner)) == operator) {
            return true;
        }

        if (openseaProxyRegistryAddress == operator) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
    }

    /**
    * @dev override msgSender to allow for meta transactions on OpenSea.
    */
    function _msgSender()
        override
        internal
        view
        returns (address sender)
    {
        if (msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
                sender := and(
                    mload(add(array, index)),
                    0xffffffffffffffffffffffffffffffffffffffff
                )
            }
        } else {
            sender = payable(msg.sender);
        }
        return sender;
    }

    /**
    * @dev function to mint tokens to an address. Only 
    * accessible by accounts with a role of MINTER_ROLE
    * @param amount the amount of tokens to be minted
    * @param _to the address to which the tokens will be minted to
    */
    function mintTo(uint256 amount, address _to) external onlyRole(MINTER_ROLE) {
        for (uint i = 0; i < amount; i++) {
            _safeMint(_to, nextTokenId);
            nextTokenId = nextTokenId + 1;
        }
        emit Mint(_to, amount);
    }

    /**
     * @dev function to burn token of tokenId. Only
     * accessible by accounts with a role of BURNER_ROLE
     * @param tokenId the tokenId to burn
     */
    function burn(uint256 tokenId) external onlyRole(BURNER_ROLE) {
        _burn(tokenId);
    }

    /**
     * @dev Fallback function for receiving Ether
     */
    receive() external payable {
        emit ReceivedEther(msg.sender, msg.value);
    }


    /** OWNER */

    /**
    * @dev function to change the baseURI of the metadata
    */
    function setBaseURI(string memory _newBaseURI) external onlyOwner notFrozen {
        baseURIString = _newBaseURI;
    }
}