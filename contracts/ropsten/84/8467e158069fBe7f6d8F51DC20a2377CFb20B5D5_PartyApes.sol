// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface IUSDC {
    function transferFrom(address sender, address recipient, uint256 amount) external returns(bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enumerable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}

contract PartyApes is ERC721Enumerable, Ownable, ReentrancyGuard {

    struct Offer {
        bool isForSale;
        uint256 apesIndex;
        address seller;
        uint256 minValue;          // in ether
        address onlySellTo;     // specify to sell only to a specific person
    }

    struct Bid {
        bool hasBid;
        uint256 apesIndex;
        address bidder;
        uint256 value;
    }

    mapping(uint256 => uint256) private assignOrders;

    mapping (uint256 => Offer) public apesOfferedForSale;
    mapping (uint256 => Bid) public apesBids;
    mapping (address => uint256) public pendingWithdrawals;
    string public baseURI;
    string public imageHash = "49e10bfb53d486314279342b5e3f11a83a4eb6f8dfbb27c5fa98834d9499c9a3";
    uint256 public apesRemainingToAssign = 0;
    uint256 public claimPrice = 500 * 1000000;

    address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    modifier onlyTradableApes (address from, uint256 tokenId) {
        require(tokenId < 1000, "Out of tokenId");
        require(ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        _;
    }

    event Assign(address indexed to, uint256 apesIndex);
    event ApesTransfer(address indexed from, address indexed to, uint256 apesIndex);
    event ApesOffered(uint256 indexed apesIndex, uint256 minValue, address indexed toAddress);
    event ApesBidEntered(uint256 indexed apesIndex, uint256 value, address indexed fromAddress);
    event ApesBidWithdrawn(uint256 indexed apesIndex, uint256 value, address indexed fromAddress);
    event ApesBought(uint256 indexed apesIndex, uint256 value, address indexed fromAddress, address indexed toAddress);
    event ApesNoLongerForSale(uint256 indexed apesIndex);

    constructor () ERC721("PartyApes", "pApes") {
        apesRemainingToAssign = 1000;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory uri) public onlyOwner {
        baseURI = uri;
    }

    function mint() public {
        require(apesRemainingToAssign > 0, "No remainig apes");
        require(IUSDC(USDC).transferFrom(msg.sender, owner(), claimPrice), "Payment is failed");
        uint256 randIndex = _random() % apesRemainingToAssign;
        uint256 apesIndex = _fillAssignOrder(--apesRemainingToAssign, randIndex);
        _safeMint(_msgSender(), apesIndex);
        emit Assign(_msgSender(), apesIndex);
    }

    function transferApes(address to, uint256 tokenId) public {
        _safeTransfer(_msgSender(), to, tokenId, "");
    }

    function apesNoLongerForSale(uint256 tokenId) public {
        _apesNoLongerForSale(_msgSender(), tokenId);
    }

    function offerApesForSale(uint256 tokenId, uint256 minSalePriceInWei) public onlyTradableApes(_msgSender(), tokenId) {
        apesOfferedForSale[tokenId] = Offer(true, tokenId, _msgSender(), minSalePriceInWei, address(0));
        emit ApesOffered(tokenId, minSalePriceInWei, address(0));
    }

    function offerApesForSaleToAddress(uint256 tokenId, uint256 minSalePriceInWei, address toAddress) public onlyTradableApes(_msgSender(), tokenId) {
        apesOfferedForSale[tokenId] = Offer(true, tokenId, _msgSender(), minSalePriceInWei, toAddress);
        emit ApesOffered(tokenId, minSalePriceInWei, toAddress);
    }

    function buyApes(uint256 tokenId, uint256 amount) public {
        Offer memory offer = apesOfferedForSale[tokenId];
        require(tokenId < 1000, "Out of tokenId");
        require(offer.isForSale, "Apes is not for sale");
        require(offer.onlySellTo == address(0) || offer.onlySellTo == _msgSender(), "Unable to sell");
        require(amount >= offer.minValue, "Insufficient amount to pay");
        require(ownerOf(tokenId) == offer.seller, "Not apes seller");
        require(IUSDC(USDC).transferFrom(msg.sender, address(this), amount), "Payment is failed");

        address seller = offer.seller;
        _safeTransfer(seller, _msgSender(), tokenId, "");
        pendingWithdrawals[seller] += amount;
        emit ApesBought(tokenId, amount, seller, _msgSender());
    }

    function withdraw() public nonReentrant {
        uint256 amount = pendingWithdrawals[_msgSender()];
        pendingWithdrawals[_msgSender()] = 0;
        require(IUSDC(USDC).transfer(_msgSender(), amount), "Payment is failed");
    }

    function enterBidForApes(uint256 tokenId, uint256 amount) public {
        require(tokenId < 1000, "Out of tokenId");
        require(ownerOf(tokenId) != _msgSender(), "Invalid bid");
        require(amount > apesBids[tokenId].value, "Require bigger amount");
        require(IUSDC(USDC).transferFrom(msg.sender, address(this), amount), "Payment is failed");
        Bid memory existing = apesBids[tokenId];
        if (existing.value > 0) {
            // Refund the failing bid
            pendingWithdrawals[existing.bidder] += existing.value;
        }
        apesBids[tokenId] = Bid(true, tokenId, _msgSender(), amount);
        emit ApesBidEntered(tokenId, amount, _msgSender());
    }

    function acceptBidForApes(uint256 tokenId, uint256 minPrice) public onlyTradableApes(_msgSender(), tokenId) {
        require(apesBids[tokenId].value >= minPrice, "Bid price is low");
        Bid memory bid = apesBids[tokenId];

        apesBids[tokenId] = Bid(false, tokenId, address(0), 0);
        _safeTransfer(_msgSender(), bid.bidder, tokenId, "");

        uint256 amount = bid.value;
        pendingWithdrawals[_msgSender()] += amount;
        emit ApesBought(tokenId, bid.value, _msgSender(), bid.bidder);
    }

    function withdrawBidForApes(uint256 tokenId) public {
        require(tokenId < 1000, "Out of tokenId");
        require(ownerOf(tokenId) != _msgSender(), "Invalid bid");
        require(apesBids[tokenId].bidder == _msgSender(), "Invalid bidder");
        uint256 amount = apesBids[tokenId].value;
        apesBids[tokenId] = Bid(false, tokenId, address(0), 0);
        // Refund the bid money
        require(IUSDC(USDC).transfer(_msgSender(), amount), "Payment is failed");
        emit ApesBidWithdrawn(tokenId, apesBids[tokenId].value, _msgSender());
    }

    function _random() internal view returns(uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(block.timestamp + block.difficulty + ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / block.timestamp) + block.gaslimit + ((uint256(keccak256(abi.encodePacked(_msgSender())))) / block.timestamp) + block.number)
            )
        ) / apesRemainingToAssign;
    }

    function _fillAssignOrder(uint256 orderA, uint256 orderB) internal returns(uint256) {
        uint256 temp = orderA;
        if (assignOrders[orderA] > 0) temp = assignOrders[orderA];
        assignOrders[orderA] = orderB;
        if (assignOrders[orderB] > 0) assignOrders[orderA] = assignOrders[orderB];
        assignOrders[orderB] = temp;
        return assignOrders[orderA];
    }

    function _transfer(address from, address to, uint256 tokenId) internal override onlyTradableApes(from, tokenId) {
        super._transfer(from, to, tokenId);
        emit ApesTransfer(from, to, tokenId);
        if (apesOfferedForSale[tokenId].isForSale) {
            _apesNoLongerForSale(to, tokenId);
        }

        if (apesBids[tokenId].bidder == to) {
            pendingWithdrawals[to] += apesBids[tokenId].value;
            apesBids[tokenId] = Bid(false, tokenId, address(0), 0);
        }
    }

    function _apesNoLongerForSale(address from, uint256 tokenId) internal onlyTradableApes(from, tokenId) {
        apesOfferedForSale[tokenId] = Offer(false, tokenId, from, 0, address(0));

        emit ApesNoLongerForSale(tokenId);
    }
}