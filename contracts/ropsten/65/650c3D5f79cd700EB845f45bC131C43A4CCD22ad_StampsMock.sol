// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC165/IERC165.sol";
import "./ERC165/ERC165.sol";
import "./utils/Address.sol";
import "./utils/EnumerableMap.sol";
import "./utils/EnumerableSet.sol";
import "./utils/SafeMath.sol";
import "./utils/Strings.sol";
import "./utils/Context.sol";
import "./ERC721/IERC721Metadata.sol";
import "./ERC721/IERC721Receiver.sol";
import "./ERC721/IERC721Enumerable.sol";
import "./ERC2309/IERC2309.sol";

import "hardhat/console.sol";


/**
 * @title StampsMock contract, used for testing
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */
contract StampsMock is Context, IERC2309, ERC165, IERC721Metadata, IERC721Enumerable {
    using SafeMath for uint256;
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    using Strings for uint256;

    // Public variables

    // TODO: Add stamps provenance hash
    // This is the provenance record of all Stamps artwork in existence
    string public constant STAMPS_PROVENANCE = "311d76249ebcca902a539043ec4c52648b5d35d3f0352ea3c38e46780ef32890";

    // TODO: Change timestamp, currently set to: Thu Mar 11 2021 23:18:00 GMT+0000
    uint256 public constant SALE_START_TIMESTAMP = 1615504674;

    // Time after which stamps are randomized and allotted
    uint256 public constant REVEAL_TIMESTAMP = SALE_START_TIMESTAMP + 86400;

    uint256 public constant MAX_NFT_SUPPLY = 1000;

    uint256 public constant MAX_PACK_SUPPLY = 200;

    uint256 public startingIndexBlock;

    uint256 public startingIndex;

    // Equals to `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    // which can be also obtained as `IERC721Receiver(0).onERC721Received.selector`
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

    // Mapping from holder address to their (enumerable) set of owned tokens
    mapping (address => EnumerableSet.UintSet) private _holderTokens;

    // Enumerable mapping from token ids to their owners
    EnumerableMap.UintToAddressMap private _tokenOwners;

    // Number of packs minted
    uint256 private _packSupply;

    // Mapping from token ID to approved address
    mapping (uint256 => address) private _tokenApprovals;

    // Mapping from token ID to whether the Stamp was minted before reveal
    mapping (uint256 => bool) private _mintedBeforeReveal;

    // Mapping from owner to operator approvals
    mapping (address => mapping (address => bool)) private _operatorApprovals;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // The address to withdraw to
    address private _withdrawAddress;


    /*
     *     bytes4(keccak256('balanceOf(address)')) == 0x70a08231
     *     bytes4(keccak256('ownerOf(uint256)')) == 0x6352211e
     *     bytes4(keccak256('approve(address,uint256)')) == 0x095ea7b3
     *     bytes4(keccak256('getApproved(uint256)')) == 0x081812fc
     *     bytes4(keccak256('setApprovalForAll(address,bool)')) == 0xa22cb465
     *     bytes4(keccak256('isApprovedForAll(address,address)')) == 0xe985e9c5
     *     bytes4(keccak256('transferFrom(address,address,uint256)')) == 0x23b872dd
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256)')) == 0x42842e0e
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)')) == 0xb88d4fde
     *
     *     => 0x70a08231 ^ 0x6352211e ^ 0x095ea7b3 ^ 0x081812fc ^
     *        0xa22cb465 ^ 0xe985e9c5 ^ 0x23b872dd ^ 0x42842e0e ^ 0xb88d4fde == 0x80ac58cd
     */
    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;

    /*
     *     bytes4(keccak256('name()')) == 0x06fdde03
     *     bytes4(keccak256('symbol()')) == 0x95d89b41
     *
     *     => 0x06fdde03 ^ 0x95d89b41 == 0x93254542
     */
    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x93254542;

    /*
     *     bytes4(keccak256('totalSupply()')) == 0x18160ddd
     *     bytes4(keccak256('tokenOfOwnerByIndex(address,uint256)')) == 0x2f745c59
     *     bytes4(keccak256('tokenByIndex(uint256)')) == 0x4f6ccce7
     *
     *     => 0x18160ddd ^ 0x2f745c59 ^ 0x4f6ccce7 == 0x780e9d63
     */
    bytes4 private constant _INTERFACE_ID_ERC721_ENUMERABLE = 0x780e9d63;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor (string memory name_, string memory symbol_, address withdrawAddress_) {
        _name = name_;
        _symbol = symbol_;
        _withdrawAddress = withdrawAddress_;
        // register the supported interfaces to conform to ERC721 via ERC165
        _registerInterface(_INTERFACE_ID_ERC721);
        _registerInterface(_INTERFACE_ID_ERC721_METADATA);
        _registerInterface(_INTERFACE_ID_ERC721_ENUMERABLE);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");

        return _holderTokens[owner].length();
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOfPacks(address owner) public view returns (uint256) {
        require(owner != address(0), "Stamps: balance query for the zero address");

        return _holderTokens[owner].length() / 5;
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view override returns (address) {
        return _tokenOwners.get(tokenId, "ERC721: owner query for nonexistent token");
    }


    function ownerOfPack(uint256 packId) public view returns (address) {
        require(packId < totalPackSupply(), "Stamps: owner query for nonexistent pack");
        return _tokenOwners.get(packId * 5, "Stamps: owner query for nonexistent pack");
    }


    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view override returns (uint256) {
        return _holderTokens[owner].at(index);
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        // _tokenOwners are indexed by tokenIds, so .length() returns the number of tokenIds
        return _tokenOwners.length();
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view override returns (uint256) {
        (uint256 tokenId, ) = _tokenOwners.at(index);
        return tokenId;
    }

    function totalPackSupply() public view returns (uint256) {
        return totalSupply() / 5;
    }

    function tokensByPack(uint256 packId) public view returns (uint256[5] memory) {
        require(packId < totalPackSupply(), "Stamp: Invalid packId parameter");
        uint256 startingTokenIndex = packId * 5;
        return [startingTokenIndex, startingTokenIndex + 1, startingTokenIndex + 2, startingTokenIndex + 3, startingTokenIndex + 4];
    }

    /**
     * @dev Gets current Stamp Pack Price
     */
    function getPackPrice() public view returns (uint256) {
        require(block.timestamp >= SALE_START_TIMESTAMP, "Stamp: Sale has not started");

        uint256 currentPackSupply = totalPackSupply();

        require(currentPackSupply < MAX_PACK_SUPPLY, "Stamp: Sale has already ended");


        //        in batches of 2500
        //        batch 1 (2500) - $180 or 0.1 eth = 450,000
        //        batch 2 - $540 or 0.3 eth per pack = 1.35mil
        //        batch 3 - $900 or 0.5 eth per pack = 2.25 mil
        //        batch 4 - $1440 or 0.8 eth  per pack= 3.6mil
        //        batch 5 - $1800 or 1 eth per pack = 4.5mil
        //        batch 6 - $2160 or 1.2 eth per pack = 5.4 mil
        //        batch 7 - $2700 or 1.5 eth per pack = 6.75 mil
        //        batch 8 - $3600 or 2 eth per pack = 9 mil
        //        33 millions

        if (currentPackSupply >= 175) {
            return 2 ether; // 175 - 200, 2 ETH
        } else if (currentPackSupply >= 150) {
            return 1.5 ether; // 150 - 175, 1.5 ETH
        } else if (currentPackSupply >= 125) {
            return 1.2 ether; // 125 - 150, 1.2 ETH
        } else if (currentPackSupply >= 100) {
            return 1 ether; // 100 - 125, 1 ETH
        } else if (currentPackSupply >= 75) {
            return 0.8 ether; // 75 - 100, 0.8 ETH
        } else if (currentPackSupply >= 50) {
            return 0.5 ether; // 50 - 75, 0.5 ETH
        } else if (currentPackSupply >= 25) {
            return 0.3 ether; // 25 - 50, 0.3 ETH
        } else {
            return 0.1 ether; // 0 - 25 0.1 ETH
        }
    }

    /**
    * @dev Mints Stamps
    */
    function mintPack(uint256 numberOfPacks) public payable {
        uint currentPackSupply = totalPackSupply();

        require(currentPackSupply < MAX_PACK_SUPPLY, "Stamps: Sale has already ended");
        require(numberOfPacks > 0, "Stamps: numberOfPacks cannot be 0");
        require(numberOfPacks <= 10, "Stamps: You may not buy more than 10 Packs at once");


        require(currentPackSupply.add(numberOfPacks) <= MAX_PACK_SUPPLY, "Stamps: Exceeds MAX_PACK_SUPPLY");
        require(getPackPrice().mul(numberOfPacks) == msg.value, "Stamps: Ether value sent is not correct");

        uint256 numberOfNfts = numberOfPacks * 5;
        uint currentSupply = totalSupply();

        uint tokenIndex = currentSupply;

        // Needed for the ConsecutiveTransfer event
        uint startingTokenId = currentSupply;


        for(uint i = 0; i < numberOfNfts; i++) {
            _holderTokens[msg.sender].add(tokenIndex);
            _tokenOwners.set(tokenIndex, msg.sender);
            tokenIndex += 1;
        }

        emit ConsecutiveTransfer(startingTokenId, tokenIndex - 1, address(0), msg.sender);

        /**
        * Source of randomness. Theoretical miner withhold manipulation possible but should be sufficient in a pragmatic sense
        */
        if (startingIndexBlock == 0 && (totalSupply() == MAX_NFT_SUPPLY || block.timestamp >= REVEAL_TIMESTAMP)) {
            startingIndexBlock = block.number;
        }
    }

    /**
     * @dev Finalize starting index
     */
    function finalizeStartingIndex() public {
        require(startingIndex == 0, "Starting index is already set");
        require(startingIndexBlock != 0, "Starting index block must be set");

        startingIndex = uint(blockhash(startingIndexBlock)) % MAX_NFT_SUPPLY;
        // Just a sanity case in the worst case if this function is called late (EVM only stores last 256 block hashes)
        if (block.number.sub(startingIndexBlock) > 255) {
            startingIndex = uint(blockhash(block.number-1)) % MAX_NFT_SUPPLY;
        }
        // Prevent default sequence
        if (startingIndex == 0) {
            startingIndex = startingIndex.add(1);
        }
    }


    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyWithdrawAddress() {
        require(_withdrawAddress == _msgSender(), "Stamps: caller is not the withdrawal address");
        _;
    }

    /**
     * @dev Withdraw ether from this contract (Callable by _withdrawAddress)
    */
    function withdraw() onlyWithdrawAddress public {
        uint balance = address(this).balance;
        payable(_withdrawAddress).transfer(balance);
    }

    /**
     * @dev Change the _withdrawAddress (Callable by _withdrawAddress)
    */
    function changeWithdrawAddress(address newWithdrawAddress) onlyWithdrawAddress public {
        require(newWithdrawAddress != address(0), "Stamps: The newWithdrawAddress can't be the zero address");
        _withdrawAddress = newWithdrawAddress;
    }

    /**
     * @dev Get the _withdrawAddress
    */
    function getWithdrawAddress() public view returns (address) {
        return _withdrawAddress;
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(_msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(operator != _msgSender(), "ERC721: approve to caller");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _tokenOwners.contains(tokenId);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Creates a pack (mints 5 tokens) and transfers them to `to`.
     */
    function _safeMintPack(address to, uint256 packId) internal virtual {
        uint currentSupply = totalSupply();
        console.log("Current NFT supply %s", currentSupply);

        for (uint mintIndex = currentSupply; mintIndex < currentSupply + 5; mintIndex++) {
            _safeMint(to, mintIndex);
        }
        console.log("Pack minted! %s", packId);
    }


    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     d*
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(address to, uint256 tokenId, bytes memory _data) internal virtual {
        _mint(to, tokenId);
        require(_checkOnERC721Received(address(0), to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(!_exists(tokenId), "ERC721: token already minted");

        _holderTokens[to].add(tokenId);

        _tokenOwners.set(tokenId, to);

        emit Transfer(address(0), to, tokenId);
    }


    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(address from, address to, uint256 tokenId) internal virtual {
        require(ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _holderTokens[from].remove(tokenId);
        _holderTokens[to].add(tokenId);

        _tokenOwners.set(tokenId, to);

        emit Transfer(from, to, tokenId);
    }


    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data)
    private returns (bool)
    {
        if (!to.isContract()) {
            return true;
        }
        bytes memory returndata = to.functionCall(abi.encodeWithSelector(
                IERC721Receiver(to).onERC721Received.selector,
                _msgSender(),
                from,
                tokenId,
                _data
            ), "ERC721: transfer to non ERC721Receiver implementer");
        bytes4 retval = abi.decode(returndata, (bytes4));
        return (retval == _ERC721_RECEIVED);
    }

    function _approve(address to, uint256 tokenId) private {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }


    /**
     * @dev Return the status of the presale (is it open)
     *
     * The sale is open when the current time is larger than the sale start time and not all packs are minted.
     *
     */
    function isSaleOpen() external view returns (bool) {
        return block.timestamp >= SALE_START_TIMESTAMP && totalPackSupply() < MAX_PACK_SUPPLY;
    }


}