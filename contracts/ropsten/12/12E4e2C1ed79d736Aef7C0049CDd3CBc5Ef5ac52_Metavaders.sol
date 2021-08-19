// SPDX-License-Identifier: MIT

/// @title: Metavaders - Mint
/// @author: PxGnome
/// @notice: Basic core Metavaders NFT Smart Contract
/// @dev: This is Version 1.0
//
// ███╗   ███╗███████╗████████╗ █████╗ ██╗   ██╗ █████╗ ██████╗ ███████╗██████╗ ███████╗
// ████╗ ████║██╔════╝╚══██╔══╝██╔══██╗██║   ██║██╔══██╗██╔══██╗██╔════╝██╔══██╗██╔════╝
// ██╔████╔██║█████╗     ██║   ███████║██║   ██║███████║██║  ██║█████╗  ██████╔╝███████╗
// ██║╚██╔╝██║██╔══╝     ██║   ██╔══██║╚██╗ ██╔╝██╔══██║██║  ██║██╔══╝  ██╔══██╗╚════██║
// ██║ ╚═╝ ██║███████╗   ██║   ██║  ██║ ╚████╔╝ ██║  ██║██████╔╝███████╗██║  ██║███████║
// ╚═╝     ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝  ╚═══╝  ╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝
//

pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Metavaders is 
    Ownable,
    AccessControlEnumerable,
    ERC721Enumerable,
    ERC721URIStorage
{
    
    // SPECIAL ROLE DEFINE
    bytes32 public constant ACTIVATOR_ROLE = keccak256("ACTIVATOR_ROLE");
    
    using Strings for uint256;
    string _baseTokenURI;
    mapping (uint256 => string) private _tokenURIs; // Optional mapping for token URIs
    uint256 public max_mint = 10101;
    uint256 private _reserved = 1000; // Reserved amount for special usage
    uint256 private _price = 0.05 ether;
    bool public _paused = true;
    bool private _reveal = false;

    address public vaultAddress;
    address public invadeAddress;


    // -- CONSTRUCTOR FUNCTIONS -- //
    // 10101 Metavaders in total
    constructor(string memory baseURI) ERC721("Metavaders", "METAVADE")  {
        // Set up baseURI for when not yet revealed
        setBaseURI(baseURI);

        // Set Up Roles
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(ACTIVATOR_ROLE, _msgSender());
        grantRole(ACTIVATOR_ROLE, address(this));

        // Integrate Vault Address
        vaultAddress = owner();
    } 

    // // -- UTILITY FUNCTIONS -- //
    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    // -- BASE FUNCTIONS -- //
    // Shows Base URI
    function getBaseURI() public view virtual returns (string memory) {
        return _baseTokenURI;
    }
    // Mint Function
    function mint(uint256 num) public payable virtual {
        uint256 supply = totalSupply();
        require( !_paused,                              "Sale paused" );
        require( num < 20,                              "You can mint a maximum of 20 Metavaders" );
        require( supply + num < max_mint - _reserved,   "Exceeds maximum Metavaders supply" );
        require( msg.value >= _price * num,             "Ether sent is not correct");

        for(uint256 i; i < num; i++){
            _safeMint(_msgSender(), supply + i );
        }
    }

    // Used to set up overrides
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControlEnumerable, ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
        require(_exists(tokenId), "ERC721URIStorage: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        if (!_reveal) {
            return _baseURI();
        }
        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }


    // Used to state current price (since we can edit price)
    function getPrice() public view returns (uint256){
        return _price;
    }

    // -- SMART CONTRACT OWNER ONLY FUNCTIONS -- //
    // Just in case ETH rises too quickly and need to re-adjust pricing
    function setPrice(uint256 _newPrice) public onlyOwner {
        _price = _newPrice;
    }
    // Change Vault Address For Future Use
    function updateVaultAddress(address _address) public onlyOwner {
        vaultAddress = _address;
    }
    // Update Invade Address Incase There Is an Issue
    function updateInvadeAddress(address _address) public onlyOwner {
        invadeAddress = _address;
    }

    // Used to update baseURI to make upgrades to metadata - Only done by owner
    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    // To allow token URI to reveal the actual collection
    function reveal(bool _revealed) public onlyOwner {
        _reveal = _revealed;
    }
    // Pause sale/mint in case of special reason
    function pause(bool val) public onlyOwner {
        _paused = val;
    }

    // Minted the reserve
    function reserveMint(address _to, uint256 _amount) external onlyOwner() {
        require( _amount <= _reserved, "Exceeds reserved Metavaders supply" );
        uint256 supply = totalSupply();
        for(uint256 i; i < _amount; i++){
            _safeMint( _to, supply + i );
        }
        _reserved -= _amount;
    }

    // Withdraw ETH to owner addresss
    function withdrawAll() public payable onlyOwner returns (uint256) {
        uint256 balance = address(this).balance;
        require(payable(owner()).send(balance)); 
        return balance;
    }

    // -- CUSTOM ADD ONS  --//
    // ACTIVATOR_ROLE
    function getActivator() public pure returns (bytes32) {
        return ACTIVATOR_ROLE;
    }
    function grantActivator(address _address) public {
        grantRole(ACTIVATOR_ROLE, _address);
    }
    function revokeActivator(address _address) public {
        revokeRole(ACTIVATOR_ROLE, _address);
    }

    // Changes the Metavaders' mode can bse used by ACTIVATORS
    function changeMode(uint256 tokenId, string memory mode) public virtual {
        require(hasRole(ACTIVATOR_ROLE, _msgSender()), "Must have ACTIVATOR_ROLE to execute");
        _setTokenURI(tokenId, string(abi.encodePacked(tokenId.toString(), mode)));
    }

    // Helps check which Metavader this wallet owner owns
    function walletOfOwner(address _owner) public view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for(uint256 i; i < tokenCount; i++){
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }
}