// contracts/Token.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract BrainwashToken is ERC721, ERC721Enumerable, AccessControl, Ownable {

    // Define WHITELIST starting and stop date
    uint256 public constant WHITELIST_START_TIMESTAMP = 1614783600;
    uint256 public constant WHITELIST_STOP_TIMESTAMP = 1614783600;

    // Define SALE starting and stop date
    uint256 public constant SALE_START_TIMESTAMP = 1614783600;
    uint256 public constant SALE_STOP_TIMESTAMP = 1614783600;

    // Create a new role identifier for the whitelisted addresses
    bytes32 public constant WHITELISTED = keccak256("WHITELISTED");


    // NFT supply and max order
    uint256 public constant MAX_SUPPLY = 500;
    uint256 public constant MAX_ORDER_FOR_ADDRESS = 10;

    // NFT price here (equal to 0.1 ETH)
    uint256 public constant NFT_PRICE = 100000000000000000;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Mints a new NFT token
     */
    function mint(uint256 quantity) public {
        require(totalSupply() < MAX_SUPPLY, "Sale has already ended");
        // TODO: aggiungere if per controllo periodo whitelist (se attiva l'indirizzo deve essere whitelistato)
        require(hasRole(WHITELISTED, msg.sender), "Caller is not a whitelisted address");
        require(quantity < MAX_SUPPLY, "Quantity is over the supply limit");
        require(quantity < MAX_ORDER_FOR_ADDRESS, "Quantity is over the limit");
        // require(getNFTPrice().mul(quantity) == msg.value, "Ether value sent is not correct");
        for (uint i = 0; i < quantity; i++) {
            uint _tokenId = totalSupply();
            _mint(msg.sender, _tokenId);
        }
    }

    /**
     * @dev Subscribe addresses to the whitelist
     */
    function subscribeToWhitelist(address[] memory addresses) public onlyOwner returns (bool) {
        for (uint i = 0; i < addresses.length; i++) {
            _setupRole(WHITELISTED, addresses[i]);
        }
        return true;
    }

    /**
     * @dev Gets current Token Price
     */
    function getNFTPrice() public view returns (uint256) {
        require(totalSupply() < MAX_SUPPLY, "Sale has already ended");
        return NFT_PRICE;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://bafybeiamjvnjv7pb2pzfpuy5mgb6atofqxv65p34nj77mjo5vf5t3cvhfm.ipfs.dweb.link";
    }

    function baseURI() public pure returns (string memory) {
        return _baseURI();
    }
}