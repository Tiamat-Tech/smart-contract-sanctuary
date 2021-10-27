// SPDX-License-Identifier: GPL-3.0
// v1 @ 27-10-21

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Helicopters is ERC721, Ownable, AccessControlEnumerable, PaymentSplitter {

    // Allows for safe math operations on integers such as add, sub, mul, and div
    using SafeMath for uint256;

    // Roles to allow for the staff to call protected functions such as set sale active to true
    bytes32 public constant STAFF_ROLE     = keccak256("STAFF_ROLE");
    bytes32 public constant WHITELIST_ROLE = keccak256("WHITELIST_ROLE");

    // General token specifics
    uint256 public constant MAX_TOKENS = 10000;
    uint256 public constant MAX_MINTS_PER_TX = 20; // limit the amount of mints per transaction
    uint256 public tokenPrice = 80000000000000000; // 0.080 ether
    uint256 public nextTokenId = 1;

    // Contract information storage for for instance metadata storage
    string  public baseURI;
    string  public contractURI;
    string  public provenance;

    // Control booleans for minting functions
    bool public saleIsActive = false;
    bool public whiteListSaleIsActive = false;

    // Register of user wallets that are whitelisted for the whitelist sale
    mapping(address => bool) public whitelist;

    address[] private constantPayees = [
      0x33A7B4D0eD67E44CCdc56c08822809859f541A17,   // PLS
      0x724878296ef5E9DE81CD27BE8b2dE3Dc325E45D1,   // UI
      0xF55fFe9EB51E2B013eA4cAEb7868C5c75cA65396    // PLD
    ];

    uint256[] private constantShares = [40,20,40];

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `STAFF_ROLE` and `WHITELIST_ROLE` to the
     * account that deploys the contract.
     *
     * See {ERC721}.
     */
    constructor() ERC721("Helicopters", "HELI") PaymentSplitter(constantPayees, constantShares) {
      _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
      _setupRole(STAFF_ROLE, _msgSender());
      _setupRole(WHITELIST_ROLE, _msgSender());
    }


    /**
     * @dev As both ERC721 and AccessControlEnumerable include supportsInterface we need to override both.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControlEnumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }


    /**
     * @dev Flip the boolean state of saleIsActive to enable/disable public sale
     */
    function flipSaleState() external {
        require(hasRole(STAFF_ROLE, _msgSender()), "Must have staff role to call this function.");
        saleIsActive = !saleIsActive;
    }


    /**
     * @dev Flip the boolean state of whiteListSaleIsActive to enable/disable whitelist sale
     */
    function flipWhiteListSaleState() external {
        require(hasRole(WHITELIST_ROLE, _msgSender()), "Must have whitelist role to call this function.");
        whiteListSaleIsActive = !whiteListSaleIsActive;
    }


    /**
     * @dev Add an array of user wallets to the whitelist for whitelist sale
     */
    function addWhitelist(address[] memory _whitelist) external {
        _changeWhiteList(_whitelist, true);
    }


    /**
     * @dev Remove an array of user wallets from the whitelist for whitelist sale
     */
    function removeWhitelist(address[] memory _whitelist) external {
        _changeWhiteList(_whitelist, false);
    }


    function _changeWhiteList(address[] memory _whitelist, bool _value) internal {
        require(hasRole(WHITELIST_ROLE, _msgSender()), "Must have whitelist role to call this function.");
        for(uint256 i = 0; i < _whitelist.length; i++) {
            whitelist[_whitelist[i]] = _value;
        }
    }


    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }


    /**
     * @dev Set the base uri per token
     */
    function setBaseURI(string memory newBaseUri) external {
        require(hasRole(STAFF_ROLE, _msgSender()), "Must have staff role to call this function.");
        baseURI = newBaseUri;
    }


    /**
     * @dev Set the Contract-level URI
     */
    function setContractURI(string memory _contractURI) external {
        require(hasRole(STAFF_ROLE, _msgSender()), "Must have staff role to call this function.");
        contractURI = _contractURI;
    }


    /**
     * @dev Provenance may only be set once irreversibly
     */
    function setProvenance(string memory _provenance) external {
        require(hasRole(STAFF_ROLE, _msgSender()), "Must have staff role to call this function.");
        require(bytes(provenance).length == 0, "Provenance already set.");
        provenance = _provenance;
    }


    /**
     * @dev Minting for those that are on the whitelist when whiteListSaleIsActive is set to true
     */
    function whitelistMint(uint256 numberOfTokens) external payable {
        require(whiteListSaleIsActive, "Whitelist sale must be active to mint.");
        require(whitelist[_msgSender()], "You are not whitelisted.");
        _mintToken(numberOfTokens);
    }


    /**
     * @dev Minting for the public when saleIsActive is set to true
     */
    function mint(uint256 numberOfTokens) external payable {
        require(saleIsActive, "Sale must be active to mint.");
        _mintToken(numberOfTokens);
    }


    function _mintToken(uint256 numberOfTokens) internal {
        require(numberOfTokens > 0 && numberOfTokens <= MAX_MINTS_PER_TX, "There is a limit on minting too many at a time.");
        require(nextTokenId.sub(1).add(numberOfTokens) <= MAX_TOKENS, "Minting this many would exceed supply.");
        require(msg.value >= tokenPrice.mul(numberOfTokens), "Not enough ether sent.");
        require(_msgSender() == tx.origin, "Contracts are not allowed to mint.");

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(_msgSender(), nextTokenId++);
        }
    }
}