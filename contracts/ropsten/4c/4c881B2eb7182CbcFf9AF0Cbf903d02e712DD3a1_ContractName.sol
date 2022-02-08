//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Context, ERC165, IERC721, IERC721Metadata, Address, Strings, IERC165, IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";  // implementation of the erc721 standard, string nft inherits from this
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";  // counters that can only be incremented or decremented by 1
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";  // sets up access control so that only the owner can interact
import {Base64} from "base64-sol/base64.sol";  // gets enoding functions

contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
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
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
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
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
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
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    // /**
    //  * @dev Transfers `tokenId` from `from` to `to`.
    //  *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
    //  *
    //  * Requirements:
    //  *
    //  * - `to` cannot be the zero address.
    //  * - `tokenId` token must be owned by `from`.
    //  *
    //  * Emits a {Transfer} event.
    //  */
    // function _transfer(
    //     address from,
    //     address to,
    //     uint256 tokenId
    // ) internal virtual {
    //     require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
    //     require(to != address(0), "ERC721: transfer to the zero address");

    //     _beforeTokenTransfer(from, to, tokenId);

    //     // Clear approvals from the previous owner
    //     _approve(address(0), tokenId);

    //     _balances[from] -= 1;
    //     _balances[to] += 1;
    //     _owners[tokenId] = to;

    //     emit Transfer(from, to, tokenId);
    // }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
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
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
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
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}


    // ------------------------------------
    // implement buy and sell functionality
    // ------------------------------------

    mapping(uint256 => uint256) private forSale;  // initialize mapping of token ID to sale price
    mapping(uint256 => address) private sellers;  // initialize mapping of token ID to sellers

    event Listed(uint256 tokenId, uint256 price);  // event for when a token is put up for sale
    event Bought(uint256 tokenId, uint256 price);  // even for when a token is bought

    // put a token up for sale
    function list_for_sale(uint256 id, uint256 price) public returns (bool) {
        require(price != 0, "price must be greater than zero");
        require(msg.sender == ownerOf(id), "you are not the owner of this token, you can not sell it");

        approve(address(0), id);
        forSale[id] = price;
        sellers[id] = msg.sender;

        emit Listed(id, price);

        return true;
    }

    // take a token off the for sale list
    function delist_for_sale(uint256 id) public returns (bool) {
        require(forSale[id] != 0, "token not for sale");
        require(msg.sender == ownerOf(id), "you are not the owner of this token, so you cannot de-list it");

        approve(address(0), id);
        delete forSale[id];
        delete sellers[id];

        emit Bought(id, 0);

        return true;
    }

    // get the price of a for sale token
    function getPrice(uint256 id) public view returns (uint256) {
        require(forSale[id] != 0, "token not for sale");
        return forSale[id];
    }

    // purchase a token and transfer it to the buyer, transfer eth to seller
    function buy(uint256 id) public payable returns (bool) {
        require(forSale[id] != 0, "token not for sale");
        require(msg.value >= forSale[id], "insufficient value");
        
        address seller = sellers[id];
        uint256 price = forSale[id];

        delete sellers[id];
        delete forSale[id];

        _transfer(seller, msg.sender, id);
        (bool sent, ) = payable(seller).call{value: price}("");
        require(sent, "transaction failed");

        emit Bought(id, price);

        if (msg.value > price) {
            (sent, ) = msg.sender.call{value: msg.value - price}("");
            require(sent, "refund failed");
        }

        return sent;
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
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");
        require(forSale[tokenId] == 0, "This token is up for sale, it must be de-listed before it can be transferred");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }
}

// start contract code

contract ContractName is ERC721, Ownable {
    using Counters for Counters.Counter;  // set counter object path
    Counters.Counter private _tokenIds;  // initialize counter object
    mapping(string => bool) private usedStrings;  // initialize mapping for keeping track of unique strings
    mapping(uint256 => string) private tokenIDtoString;  // initialize mapping of token ID to string
    uint256 cost = 0.0025e18;  // set the minting fee


    constructor() ERC721("TokenName", "SYMB") {}  // smart contract's name, smart contract's symbol

    // updates the mapping with strings that have been used
    function updateStrings(string memory str) private {
        usedStrings[str] = true;
    }

    // checks to see if a string has been minted already
    function checkIfUsed(string memory str) public view returns (bool) {  // view means that we can look at the value of a state variable in the contract
        return usedStrings[str];  // tell us if the string is in the mapping (true if there, false if not)
    }

    // given tokenID, returns the string associated with that tokenID
    function getString(uint256 tokenID) public view returns (string memory) {
        require(_exists(tokenID), "TokenID does not exist!");  // make sure the tokenID is valid
        return tokenIDtoString[tokenID];  // get the string from the mapping
    }

    // string comparison --> true if same, false if different
    function strcmp(string memory a, string memory b) internal pure returns (bool) {
        return ( (bytes(a).length == bytes(b).length) && keccak256(bytes(a)) == keccak256(bytes(b)) );
        // check for same length first, then check to see if they have the same hash
    }

    function getImage(uint256 id) public view returns (string memory) {
        string memory base = 'data:application/json;base64,';  // base string telling the browser the json is in base64
        return string(abi.encodePacked(base, getString(id)));
    }

    // override the default function and wrap the string in a nice little base64'd json format
    function tokenURI(uint256 id) override public view returns (string memory) {
        string memory base = 'data:application/json;base64,';  // base string telling the browser the json is in base64
        string memory json = string(abi.encodePacked(
            '{\n\t"name": "', getString(id), '"\n', 
            '\t"image": "', getImage(id), '\n}'));  // format the json

        return string(abi.encodePacked(base, Base64.encode(bytes(json))));  // return the full concatenated string
    }

    // owner can withdraw from the contract address
    function withdraw(uint256 amt) public onlyOwner {
        require(amt <= address(this).balance);
        (bool sent, ) = payable(owner()).call{value: amt}("");
        require(sent, "transaction did not go through");
    }

    // owner can change the minting cost
    function changeCost(uint256 newCost) public onlyOwner {
        cost = newCost;
    }

    // returns the cost (gas excluded) of minting a string in wei
    function getCost() public view returns (uint256) {
        return cost;
    }

    // actually mint the string
    function mintNFT(string memory str) public payable returns (uint256) {
        require(msg.value >= cost, "payment not sufficient");  // msg.value must be larger than the minting fee
        require(bytes(str).length > 0, "string cannot be empty");  // make sure the string being minted is not empty
        require(!checkIfUsed(str), "this string has already been minted");  // check to make sure the string is unique
        //updateStrings(str);  // add string to the used list

        uint256 newItemId = _tokenIds.current();  // get the current itemID
        _tokenIds.increment();  // increment the tokenID

        tokenIDtoString[newItemId] = str;  // update the mapping
        string storage str_at_pointer = tokenIDtoString[newItemId];  // get pointer for the string so we don't write twice
        usedStrings[str_at_pointer] = true;  // add string to the used list
        
        _mint(msg.sender, newItemId);  // mint the nft and send it to the person who called the contract

        return newItemId;
    }

    function mind_and_listNFT(string memory str, uint256 price) public payable returns (uint256) {
        uint256 id = mintNFT(str);
        list_for_sale(id, price);
        return id;
    }

}