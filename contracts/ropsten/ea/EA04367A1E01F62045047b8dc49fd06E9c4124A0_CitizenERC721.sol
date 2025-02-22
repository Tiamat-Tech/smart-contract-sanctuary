pragma solidity ^0.8.4;

// Import contracts.
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

//@title Kong Land Citizen $ALPHA Token
contract CitizenERC721 is ERC721, ERC721Burnable, AccessControl {
    using Counters for Counters.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    Counters.Counter private _tokenIdCounter;

    // Allow the baseURI to be updated.
    string private _baseUpdateableURI;

    event UpdateBaseURI(string baseURI);

    // Set up the ERC721 with admin and minter roles.
    constructor() ERC721("Kong Land Alpha Citizen", "ALPHA") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    // Allow minters to mint, increment counter.
    function mint(address to) public onlyRole(MINTER_ROLE) {
        _safeMint(to, _tokenIdCounter.current());
        _tokenIdCounter.increment();
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseUpdateableURI;
    }

    function updateBaseURI(string calldata baseURI) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseUpdateableURI = baseURI;
        emit UpdateBaseURI(baseURI);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }    

}