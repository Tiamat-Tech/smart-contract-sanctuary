//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract Avatar is
    Initializable,
    ERC1155Upgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    ERC1155BurnableUpgradeable,
    UUPSUpgradeable
{
    using StringsUpgradeable for string;
    using StringsUpgradeable for uint256;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _tokenIdTracker;
    CountersUpgradeable.Counter private _reservedTokenCounter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    uint256 public _MAX_NUM_TOKENS;
    uint256 public _RESERVED_NUM_TOKENS;
    uint256 public _TOKEN_PRICE;
    uint256 public _MAX_NUM_TOKENS_PER_MINT;

    string public _TOKEN_METADATA_FILENAME;

    bool public _PUBLIC_MINTING_ENABLED;

    event AvatarMinted(
        uint256 indexed tokenId,
        address indexed toAddress,
        address indexed byAddress,
        uint256 amount,
        string tokenType
    );

    function initialize(string memory uri) public initializer {
        __ERC1155_init(uri);
        __Pausable_init();
        __AccessControl_init();
        __ERC1155Burnable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        _MAX_NUM_TOKENS = 10000;
        _RESERVED_NUM_TOKENS = 3000;
        _TOKEN_PRICE = 3e16; // 0.03 MATIC
        _MAX_NUM_TOKENS_PER_MINT = 10;

        _TOKEN_METADATA_FILENAME = "metadata.json";

        _PUBLIC_MINTING_ENABLED = false;
    }

    modifier mintingValidation(uint8 count, uint256[] memory amounts) {
        require(count > 0, "Minimum count should be 1");
        require(
            count <= _MAX_NUM_TOKENS_PER_MINT,
            "Too many number of tokens to mint in one transaction"
        );
        require(
            count == amounts.length,
            "Token count is not equal to Amount length"
        );
        _;
    }

    function adminUpdateTokenURI(
        string memory uri,
        string memory _tokenMetadataFilename
    ) external onlyRole(ADMIN_ROLE) {
        _setURI(uri);
        _TOKEN_METADATA_FILENAME = _tokenMetadataFilename;
    }

    function adminUpdateTokenLimits(
        uint256 maxNumTokens,
        uint256 reservedNumTokens,
        uint256 maxNumTokensPerMint
    ) external onlyRole(ADMIN_ROLE) {
        _MAX_NUM_TOKENS = maxNumTokens;
        _RESERVED_NUM_TOKENS = reservedNumTokens;
        _MAX_NUM_TOKENS_PER_MINT = maxNumTokensPerMint;
    }

    function adminUpdateTokenPrice(uint256 tokenPrice)
        external
        onlyRole(ADMIN_ROLE)
    {
        _TOKEN_PRICE = tokenPrice;
    }

    function adminUpdatePublicMinting(bool enabled)
        external
        onlyRole(ADMIN_ROLE)
    {
        _PUBLIC_MINTING_ENABLED = enabled;
    }

    function adminWithdrawAll() external onlyRole(ADMIN_ROLE) {
        require(address(this).balance > 0, "No funds left");
        _withdraw(address(msg.sender), address(this).balance);
    }

    function reservedMinting(
        address _toAddress,
        uint8 _count,
        uint256[] memory _amounts
    ) external mintingValidation(_count, _amounts) onlyRole(MINTER_ROLE) {
        require(
            remainingNumReservedTokens() >= _count,
            "Max limit reached for the admin minting"
        );

        for (uint8 i = 0; i < _count; i++) {
            _mintAnElement(
                _toAddress,
                address(msg.sender),
                _amounts[i],
                "reserved"
            );
            _reservedTokenCounter.increment();
        }
    }

    function publicMinting(
        address _toAddress,
        uint8 _count,
        uint256[] memory _amounts
    ) external mintingValidation(_count, _amounts) onlyRole(MINTER_ROLE) {
        require(
            _PUBLIC_MINTING_ENABLED == true,
            "Public minting is not enabled yet"
        );
        require(
            remainingNumPublicTokens() >= _count,
            "Max limit reached for minting"
        );

        for (uint8 i = 0; i < _count; i++) {
            _mintAnElement(
                address(_toAddress),
                address(msg.sender),
                _amounts[i],
                "public"
            );
        }
    }

    function _mintAnElement(
        address _toAddress,
        address _byAddress,
        uint256 _amount,
        string memory token_type
    ) private {
        _tokenIdTracker.increment();

        _mint(_toAddress, _tokenIdTracker.current(), _amount, "");

        emit AvatarMinted(
            _tokenIdTracker.current(),
            _toAddress,
            _byAddress,
            _amount,
            token_type
        );
    }

    function getNextTokenId() external view returns (uint256) {
        return _tokenIdTracker.current() + 1;
    }

    function getPrice(uint256 _count) public view returns (uint256) {
        return _TOKEN_PRICE * _count;
    }

    function remainingNumReservedTokens() public view returns (uint256) {
        return _RESERVED_NUM_TOKENS - _reservedTokenCounter.current();
    }

    function remainingNumPublicTokens() public view returns (uint256) {
        return
            _MAX_NUM_TOKENS -
            _RESERVED_NUM_TOKENS -
            _tokenIdTracker.current() -
            _reservedTokenCounter.current();
    }

    function remainingNumTokens() public view returns (uint256) {
        return _MAX_NUM_TOKENS - _tokenIdTracker.current();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

    function _withdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{value: _amount}("");
        require(success, "Transfer failed.");
    }

    function tokenURI(uint256 _tokenId) public view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    uri(0),
                    _tokenId.toString(),
                    "/",
                    _TOKEN_METADATA_FILENAME
                )
            );
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}