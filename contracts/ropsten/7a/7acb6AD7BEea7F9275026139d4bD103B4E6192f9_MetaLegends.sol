// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

pragma solidity ^0.8.0;

// made by array
// dsc array#0007

contract MetaLegends is ERC721, AccessControl, PaymentSplitter {
    using SafeMath for uint256;
    using Strings for uint256;
    using Counters for Counters.Counter;

    address[] private _team = [
        0xC33424A82f65aa2746504eBf37cdffDC2daf9Ab9,
        0xdEcCad927A808d6Ca1Ef3Eee0579Ab1bF512e49f,
        0x8eD1408470B7D780Fee3F5ad36a4a038613CDDa6
    ];

    uint256[] private _teamShares = [33, 33, 34];

    struct dutchAuctionParams {
        uint256 startTime;
        uint256 startPrice;
        uint256 reservePrice;
        uint256 priceStep;
        uint256 timeRange;
    }

    // Roles
    bytes32 private constant whitelistedRole = keccak256("wl");

    // Public parameters
    uint256 public maxSupply = 12345;
    uint256 public wlMaxMints = 1;
    uint256 public wlMintPrice = 0.3 ether;
    bool public wlMintActivated = false;

    bool public publicMintActivated = false;
    uint256 public publicMaxMints = 2;
    dutchAuctionParams public dutchAuction;

    // Public variables
    string public baseURI;

    // Private variables
    Counters.Counter private _tokenIds;
    bool internal revealed = false;
    mapping(address => uint256) private wlMints;
    mapping(address => uint256) private publicMints;

    // Events
    event publicMinted(
        address indexed from,
        uint256 price,
        uint256 timestamp,
        uint256[] tokenIds
    );
    event whitelistMinted(
        address indexed from,
        uint256 timestamp,
        uint256[] tokenIds
    );

    /**
    @dev Gives the owner of the contract the admin role
    */
    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
        PaymentSplitter(_team, _teamShares)
    {
        _setRoleAdmin(whitelistedRole, DEFAULT_ADMIN_ROLE);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
    @dev Modifier for only admins
     */
    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Restricted to admins."
        );
        _;
    }

    /**
    @dev Add an account as an admin of this contract
     */
    function addAdmin(address account) public onlyAdmin {
        grantRole(DEFAULT_ADMIN_ROLE, account);
    }

    /**
    @dev Remove an account as an admin of this contract
     */
    function removeAdmin(address account) public onlyAdmin {
        revokeRole(DEFAULT_ADMIN_ROLE, account);
    }

    /// ADMIN FUNCTIONS
    /**
    @dev Base URI setter
     */
    function _setBaseURI(string memory _newBaseURI) public onlyAdmin {
        baseURI = _newBaseURI;
    }

    /**
    @dev Setter for the maxmium of mints possible for whitelisted accounts
     */
    function setMaximumWhitelistMints(uint256 _nb) external onlyAdmin {
        wlMaxMints = _nb;
    }

    /**
    @dev Setter for mint price for whitelisted accounts
     */
    function setWhitelistMintPrice(uint256 _nb) external onlyAdmin {
        wlMintPrice = _nb;
    }

    /**
    @dev Grand whitelist role for given addresses
     */
    function addAddressesToWhitelist(address[] calldata addresses)
        external
        onlyAdmin
    {
        for (uint32 i = 0; i < addresses.length; i++) {
            grantRole(whitelistedRole, addresses[i]);
        }
    }

    /**
    @dev Remove given addresses from the whitelist role
     */
    function removeAddressesOfWhitelist(address[] calldata addresses)
        external
        onlyAdmin
    {
        for (uint32 i = 0; i < addresses.length; i++) {
            revokeRole(whitelistedRole, addresses[i]);
        }
    }

    /**
    @dev Switch status of whitelist mint
     */
    function flipWhitelistMint() external onlyAdmin {
        wlMintActivated = !wlMintActivated;
    }

    /**
    @dev Activate the public mint with given parameters for a dutch auction
     */
    function activatePublicMint(
        uint256 _start,
        uint256 _reserve,
        uint256 _step,
        uint256 _timeRange
    ) external onlyAdmin {
        require(_start > _reserve, "Invalid prices");
        publicMintActivated = true;
        dutchAuction = dutchAuctionParams(
            block.timestamp,
            _start,
            _reserve,
            _step,
            _timeRange
        );
    }

    /**
    @dev Deactivate the public mint
     */
    function deactivatePublicMint() external onlyAdmin {
        publicMintActivated = false;
    }

    /**
    @dev Switch status of revealed
     */
    function flipRevealed() external onlyAdmin {
        revealed = !revealed;
    }

    /**
    @dev Withdraw balance of contract
     */
    function withdrawAll() external onlyAdmin {
        for (uint256 i = 0; i < _team.length; i++) {
            address payable wallet = payable(_team[i]);
            release(wallet);
        }
    }

    /// PUBLIC FUNCTIONS
    /**
    @dev Returns token URI
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory base = _baseURI();
        if (!revealed) {
            return bytes(base).length > 0 ? string(abi.encodePacked(base)) : "";
        }
        return
            bytes(base).length > 0
                ? string(abi.encodePacked(base, tokenId.toString()))
                : "";
    }

    /**
    @dev Returns the total supply
     */
    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }

    /**
    @dev Check if an address is whitelisted
     */
    function isWhitelisted(address account) public view returns (bool) {
        return hasRole(whitelistedRole, account);
    }

    /**
    @dev Check if an address is admin
     */
    function isAdmin(address account) public view returns (bool) {
        return hasRole(whitelistedRole, account);
    }
    /**
    @dev Mint for whitelisted address
     */
    function whitelistMint(uint256 _nb)
        public
        payable
        onlyRole(whitelistedRole)
    {
        require(wlMintActivated, "Whitelisted sale is not active.");
        require(totalSupply().add(_nb) <= maxSupply, "Not enough tokens left.");
        require(msg.value <= wlMintPrice.mul(_nb), "Insufficient amount.");
        require(wlMints[msg.sender].add(_nb) <= wlMaxMints, "Limit exceeded.");

        uint256[] memory _tokenIdsMinted = new uint256[](_nb);
        for (uint32 i = 0; i < _nb; i++) {
            _tokenIds.increment();
            uint256 _tokenId = _tokenIds.current();
            _safeMint(msg.sender, _tokenId);
            _tokenIdsMinted[i] = _tokenId;
        }
        wlMints[msg.sender] = wlMints[msg.sender].add(_nb);
        emit whitelistMinted(msg.sender, block.timestamp, _tokenIdsMinted);
    }

    /**
    @dev Public mint as a dutch auction
     */
    function publicMint(uint256 _nb) public payable {
        require(publicMintActivated, "Public sale is not active.");
        require(totalSupply().add(_nb) <= maxSupply, "Not enough tokens left.");
        uint256 currentTimestamp = block.timestamp;
        uint256 currentPrice = _getPublicCurrentPrice(currentTimestamp);
        require(msg.value <= currentPrice.mul(_nb), "Insufficient amount.");
        require(
            publicMints[msg.sender].add(_nb) <= publicMaxMints,
            "Limit exceeded."
        );

        uint256[] memory _tokenIdsMinted = new uint256[](_nb);
        for (uint32 i = 0; i < _nb; i++) {
            _tokenIds.increment();
            uint256 _tokenId = _tokenIds.current();
            _safeMint(msg.sender, _tokenId);
            _tokenIdsMinted[i] = _tokenId;
        }
        publicMints[msg.sender] = publicMints[msg.sender].add(_nb);
        emit publicMinted(
            msg.sender,
            currentPrice,
            currentTimestamp,
            _tokenIdsMinted
        );
    }

    /**
    @dev Gives mint princ of the dutch auction for a given timestamp
     */
    function getPublicMintPrice(uint256 _timestamp)
        public
        view
        returns (uint256)
    {
        return _getPublicCurrentPrice(_timestamp);
    }

    /// INTERNAL FUNCTIONS
    /**
    @dev Returns base token URI
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    /**
    @dev Give current price of the dutch auction
     */
    function _getPublicCurrentPrice(uint256 _timestamp)
        internal
        view
        returns (uint256)
    {
        require(publicMintActivated, "Public sale is not active.");
        require(
            dutchAuction.startTime != 0 &&
                dutchAuction.startPrice != 0 &&
                dutchAuction.reservePrice != 0 &&
                dutchAuction.priceStep != 0 &&
                dutchAuction.timeRange != 0
        );
        require(
            _timestamp - dutchAuction.startTime > 0,
            "Timestamp after the start time."
        );
        uint256 nbCycles = _timestamp.sub(dutchAuction.startTime).div(
            dutchAuction.timeRange
        );
        return
            Math.max(
                dutchAuction.reservePrice,
                dutchAuction.startPrice.sub(
                    nbCycles.mul(dutchAuction.priceStep)
                )
            );
    }

    /// Necessary overrides
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}