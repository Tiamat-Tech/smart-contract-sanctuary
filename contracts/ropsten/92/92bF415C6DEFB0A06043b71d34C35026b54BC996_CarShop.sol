// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.6.0;

import "@openzeppelin/contracts/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";


/**
 * @title Hashmasks contract
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */
contract CarShop is Context, Ownable, ERC165, IERC721Metadata {
    using SafeMath for uint256;
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    using Strings for uint256;

    // Public variables

    // Mapping from holder address to their (enumerable) set of owned cars
    mapping (address => EnumerableSet.UintSet) private _holderCars;

    // Enumerable mapping from car ids to their owners
    EnumerableMap.UintToAddressMap private _carOwners;

    // Mapping from car ID to approved address
    mapping (uint256 => address) private _carApprovals;

    // Mapping from car ID to name
    mapping (uint256 => string) private _carName;

    // Mapping if certain name string has already been reserved
    mapping (string => bool) private _nameReserved;

    // Mapping from car ID to price
    mapping (uint256 => uint256) private _carPrice;

    // Mapping from owner to operator approvals
    mapping (address => mapping (address => bool)) private _operatorApprovals;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Events
    event NameChange (uint256 indexed maskIndex, string newName);
    event Sold (address indexed to, uint256 indexed carId);

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor (string memory name, string memory symbol) public {
        _name = name;
        _symbol = symbol;
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) external view override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");

        return _holderCars[owner].length();
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 carId) public view override returns (address) {
        return _carOwners.get(carId, "ERC721: owner query for nonexistent car");
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() external view override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 carId) external view override returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256) {
        return _holderCars[owner].at(index);
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view returns (uint256) {
        // _carOwners are indexed by tokenIds, so .length() returns the number of tokenIds
        return _carOwners.length();
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) external view returns (uint256) {
        (uint256 carId, ) = _carOwners.at(index);
        return carId;
    }

    /**
     * @dev Returns name of the NFT at index.
     */
    function carNameByIndex(uint256 index) external view returns (string memory) {
        return _carName[index];
    }

    /**
     * @dev Returns if the name has been reserved.
     */
    function isNameReserved(string memory nameString) public view returns (bool) {
        return _nameReserved[toLower(nameString)];
    }

    /**
     * @dev Returns name of the NFT at index.
     */
    function carPriceByIndex(uint256 index) external view returns (uint256) {
        return _carPrice[index];
    }

    /**
    * @dev Add a new car
    */
    function addNewCar(uint256 price) onlyOwner external {
        uint mintIndex = totalSupply();
        _safeMint(msg.sender, mintIndex);
        _carPrice[mintIndex] = price;
    }

    /**
    * @dev Sell the car
    */
    function sellCar(address to, uint256 carId) onlyOwner external {
        safeTransferFrom(_msgSender(), to, carId);
        emit Sold(to, carId);
    }

    /**
     * @dev Changes the name for car
     */
    function changeName(uint256 carId, string memory newName) onlyOwner external {
        require(validateName(newName) == true, "Not a valid new name");
        require(sha256(bytes(newName)) != sha256(bytes(_carName[carId])), "New name is same as the current one");
        require(isNameReserved(newName) == false, "Name already reserved");

        // If already named, dereserve old name
        if (bytes(_carName[carId]).length > 0) {
            toggleReserveName(_carName[carId], false);
        }
        toggleReserveName(newName, true);
        _carName[carId] = newName;

        emit NameChange(carId, newName);
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 carId) external virtual override {
        address owner = ownerOf(carId);
        require(to != owner, "ERC721: approval to current owner");

        require(_msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, carId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 carId) public view override returns (address) {
        require(_exists(carId), "ERC721: approved query for nonexistent car");

        return _carApprovals[carId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) external virtual override {
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
    function transferFrom(address from, address to, uint256 carId) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), carId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, carId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 carId) public virtual override {
        safeTransferFrom(from, to, carId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 carId, bytes memory _data) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), carId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, carId);
    }

    /**
     * @dev Safely transfers `carId` car from `from` to `to`, checking first that contract recipients
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
     * - `carId` car must exist and be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(address from, address to, uint256 carId) internal virtual {
        _transfer(from, to, carId);
    }

    /**
     * @dev Returns whether `carId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 carId) internal view returns (bool) {
        return _carOwners.contains(carId);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `carId`.
     *
     * Requirements:
     *
     * - `carId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 carId) internal view returns (bool) {
        require(_exists(carId), "ERC721: operator query for nonexistent car");
        address owner = ownerOf(carId);
        return (spender == owner || getApproved(carId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Safely mints `carId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `carId` must not exist.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 carId) internal virtual {
        _mint(to, carId);
    }

    /**
     * @dev Mints `carId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `carId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 carId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(carId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, carId);

        _holderCars[to].add(carId);

        _carOwners.set(carId, to);

        emit Transfer(address(0), to, carId);
    }

    /**
     * @dev Destroys `carId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `carId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 carId) internal virtual {
        address owner = ownerOf(carId);

        _beforeTokenTransfer(owner, address(0), carId);

        // Clear approvals
        _approve(address(0), carId);

        _holderCars[owner].remove(carId);

        _carOwners.remove(carId);

        emit Transfer(owner, address(0), carId);
    }

    /**
     * @dev Transfers `carId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `carId` car must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(address from, address to, uint256 carId) internal virtual {
        require(ownerOf(carId) == from, "ERC721: transfer of car that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, carId);

        // Clear approvals from the previous owner
        _approve(address(0), carId);

        _holderCars[from].remove(carId);
        _holderCars[to].add(carId);

        _carOwners.set(carId, to);

        emit Transfer(from, to, carId);
    }

    function _approve(address to, uint256 carId) private {
        _carApprovals[carId] = to;
        emit Approval(ownerOf(carId), to, carId);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `carId` will be
     * transferred to `to`.
     * - When `from` is zero, `carId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `carId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 carId) internal virtual { }

    /**
     * @dev Reserves the name if isReserve is set to true, de-reserves if set to false
     */
    function toggleReserveName(string memory str, bool isReserve) internal {
        _nameReserved[toLower(str)] = isReserve;
    }

    /**
     * @dev Check if the name string is valid (Alphanumeric and spaces without leading or trailing space)
     */
    function validateName(string memory str) public pure returns (bool){
        bytes memory b = bytes(str);
        if(b.length < 1) return false;
        if(b.length > 25) return false; // Cannot be longer than 25 characters
        if(b[0] == 0x20) return false; // Leading space
        if (b[b.length - 1] == 0x20) return false; // Trailing space

        bytes1 lastChar = b[0];

        for(uint i; i<b.length; i++){
            bytes1 char = b[i];

            if (char == 0x20 && lastChar == 0x20) return false; // Cannot contain continous spaces

            if(
                !(char >= 0x30 && char <= 0x39) && //9-0
                !(char >= 0x41 && char <= 0x5A) && //A-Z
                !(char >= 0x61 && char <= 0x7A) && //a-z
                !(char == 0x20) //space
            )
                return false;

            lastChar = char;
        }

        return true;
    }

    /**
     * @dev Converts the string to lowercase
     */
    function toLower(string memory str) public pure returns (string memory){
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint i = 0; i < bStr.length; i++) {
            // Uppercase character
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }
}