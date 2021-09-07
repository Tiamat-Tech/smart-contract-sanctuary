// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract WantedPunks is Ownable, ERC721Enumerable {
    using Strings for uint256;

    /// @dev Emitted when {setTokenURI} is executed.
    event TokenURISet(string indexed tokenUri);
    /// @dev Emitted when {lockTokenURI} is executed (once-only).
    event TokenURILocked(string indexed tokenUri);
    event CollectionRevealed();

    error ZeroMultisigAddress();
    error WantedPunksSoldOut();
    error ZeroWantedPunksRequested();
    error BuyLimitExceeded(uint256 maxAllowedPerTx);
    error InvalidETHAmount(uint256 received, uint256 expected);
    error MintingExceedsMaxSupply(uint256 supplyAfterMinting, uint256 hardCap);
    error MintingExceedsSpecialReserve(
        uint256 reserveAfterMinting,
        uint256 reserveCap
    );
    error ZeroWEIRequested();
    error AmountExceedsEarnings(uint256 amount, uint256 earnings);
    error ETHTransferFailed();
    error UnknownTokenId(uint256 tokenId);
    error StrangerDetected();
    error TokenURILockedErr();

    uint256 public constant PRICE = 1 ether / 25;
    uint256 public constant MAX_WP_SUPPLY = 950;
    uint256 public constant WP_PACK_LIMIT = 5;
    uint256 private constant SPECIAL_RESERVE = 50;
    uint256 private constant SPLIT = 40;
    address private constant DEV_WALLET =
        0xebA9F4d9D11A3bD96C5dE4bcE02da592a2676473;
    string private constant PLACEHOLDER_SUFFIX = "placeholder.json";
    string private constant METADATA_INFIX = "/metadata/";
    // TODO: set me
    string public constant provenance = "";

    // current metadata base prefix
    string private _baseTokenUri;
    uint256 private tipAccumulator;
    uint256 private earningsAccumulator;
    uint256 private specialReserveCounter;
    address private multisig;
    bool public tokenURILocked;
    bool public collectionRevealed;

    constructor(address multisig_) ERC721("WP", "Wanted Punks") {
        if (multisig_ == address(0)) revert ZeroMultisigAddress();
        multisig = multisig_;
    }

    /**
     * @dev Set base token URI. Only callable by the owner and only
     * if token URI hasn't been locked through {lockTokenURI}. Emit
     * TokenURISet with the new value on every successful execution.
     *
     * @param newUri The new base URI to use from this point on.
     */
    function setTokenURI(string memory newUri)
        public
        onlyOwner
        whenUriNotLocked
    {
        _baseTokenUri = newUri;
        emit TokenURISet(_baseTokenUri);
    }

    /**
     * @dev Prevent further modification of the currently set base token URI.
     *  Do nothing if already locked. Emit {TokenURILocked} with the current
     *  base token URI on initial execution. Only callable by the owner.
     */
    function lockTokenURI() public onlyOwner {
        if (!tokenURILocked) {
            tokenURILocked = true;
            emit TokenURILocked(_baseTokenUri);
        }
    }

    /// @dev mint up to `punks` tokens
    function mint(uint256 punks) public payable {
        uint256 ts = totalSupply();
        if (ts >= MAX_WP_SUPPLY) revert WantedPunksSoldOut();
        if (punks == 0) revert ZeroWantedPunksRequested();
        if (punks > WP_PACK_LIMIT) revert BuyLimitExceeded(WP_PACK_LIMIT);
        if (PRICE * punks != msg.value)
            revert InvalidETHAmount(msg.value, PRICE * punks);
        if (ts + punks > MAX_WP_SUPPLY)
            revert MintingExceedsMaxSupply(ts + punks, MAX_WP_SUPPLY);

        for (uint256 i = 0; i < punks; i++) {
            _safeMint(msg.sender, ts + i);
        }

        uint256 tip = (msg.value * 40) / 100;
        tipAccumulator += tip;
        earningsAccumulator += (msg.value - tip);

        if (totalSupply() == MAX_WP_SUPPLY) {
            _reveal();
        }
    }

    function memorialize(uint256 punks) public onlyOwner {
        if (specialReserveCounter + punks > SPECIAL_RESERVE)
            revert MintingExceedsSpecialReserve(
                specialReserveCounter + punks,
                SPECIAL_RESERVE
            );

        if (punks == 0) revert ZeroWantedPunksRequested();

        for (uint256 i = 0; i < punks; i++) {
            _safeMint(multisig, MAX_WP_SUPPLY + specialReserveCounter + i);
        }

        specialReserveCounter += punks;
    }

    function tipdraw(uint256 amount) public onlyDev {
        if (amount == 0) revert ZeroWEIRequested();
        if (amount > tipAccumulator)
            revert AmountExceedsEarnings(amount, tipAccumulator);

        tipAccumulator -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");

        if (!success) revert ETHTransferFailed();
    }

    function withdraw(uint256 amount) public onlyOwner {
        if (amount == 0) revert ZeroWEIRequested();
        if (amount > earningsAccumulator)
            revert AmountExceedsEarnings(amount, earningsAccumulator);

        earningsAccumulator -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");

        if (!success) revert ETHTransferFailed();
    }

    /**
     * @dev Returns placeholder for a minted token prior to reveal time,
     * the regular tokenURI otherise.
     *
     * @param tokenId Identity of an existing (minted) WP NFT.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory result)
    {
        if (!_exists(tokenId)) revert UnknownTokenId(tokenId);

        result = collectionRevealed ? regularURI(tokenId) : placeholderURI();
    }

    function earnings() public view returns (uint256 bal) {
        if ((msg.sender != owner()) && (msg.sender != DEV_WALLET))
            revert StrangerDetected();

        bal = (msg.sender == DEV_WALLET) ? tipAccumulator : earningsAccumulator;
    }

    function reveal() public onlyOwner {
        _reveal();
    }

    //
    // BASEMENT
    //
    modifier onlyDev() {
        if (msg.sender != DEV_WALLET) revert StrangerDetected();

        _;
    }

    modifier whenUriNotLocked() {
        if (tokenURILocked) revert TokenURILockedErr();

        _;
    }

    function placeholderURI() internal view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    _baseTokenUri,
                    METADATA_INFIX,
                    PLACEHOLDER_SUFFIX
                )
            );
    }

    function regularURI(uint256 tokenId) internal view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    _baseTokenUri,
                    METADATA_INFIX,
                    tokenId.toString(),
                    ".json"
                )
            );
    }

    function _reveal() internal {
        if (!collectionRevealed) {
            collectionRevealed = true;
            emit CollectionRevealed();
        }
    }
}