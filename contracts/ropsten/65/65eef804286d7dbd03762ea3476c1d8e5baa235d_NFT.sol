/**
 *Submitted for verification at Etherscan.io on 2021-09-30
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC20 {

    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155 is IERC165 {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must be have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}



/**
 * @dev _Available since v3.1._
 */
interface IERC1155Receiver is IERC165 {
    /**
        @dev Handles the receipt of a single ERC1155 token type. This function is
        called at the end of a `safeTransferFrom` after the balance has been updated.
        To accept the transfer, this must return
        `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
        (i.e. 0xf23a6e61, or its own function selector).
        @param operator The address which initiated the transfer (i.e. msg.sender)
        @param from The address which previously owned the token
        @param id The ID of the token being transferred
        @param value The amount of tokens being transferred
        @param data Additional data with no specified format
        @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
    */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
        @dev Handles the receipt of a multiple ERC1155 token types. This function
        is called at the end of a `safeBatchTransferFrom` after the balances have
        been updated. To accept the transfer(s), this must return
        `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
        (i.e. 0xbc197c81, or its own function selector).
        @param operator The address which initiated the batch transfer (i.e. msg.sender)
        @param from The address which previously owned the token
        @param ids An array containing ids of each token being transferred (order and length must match values array)
        @param values An array containing amounts of each token being transferred (order and length must match ids array)
        @param data Additional data with no specified format
        @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
    */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}


/**
 * @dev Interface of the optional ERC1155MetadataExtension interface, as defined
 * in the https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155MetadataURI is IERC1155 {
    /**
     * @dev Returns the URI for token type `id`.
     *
     * If the `\{id\}` substring is present in the URI, it must be replaced by
     * clients with the actual token type ID.
     */
    function uri(uint256 id) external view returns (string memory);
}

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

library Strings {
    // via https://github.com/oraclize/ethereum-api/blob/master/oraclizeAPI_0.5.sol
    function strConcat(
        string memory _a,
        string memory _b,
        string memory _c,
        string memory _d,
        string memory _e
    ) internal pure returns (string memory) {
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        bytes memory _bc = bytes(_c);
        bytes memory _bd = bytes(_d);
        bytes memory _be = bytes(_e);
        string memory abcde = new string(_ba.length + _bb.length + _bc.length + _bd.length + _be.length);
        bytes memory babcde = bytes(abcde);
        uint256 k = 0;
        for (uint256 i = 0; i < _ba.length; i++) babcde[k++] = _ba[i];
        for (uint256 i = 0; i < _bb.length; i++) babcde[k++] = _bb[i];
        for (uint256 i = 0; i < _bc.length; i++) babcde[k++] = _bc[i];
        for (uint256 i = 0; i < _bd.length; i++) babcde[k++] = _bd[i];
        for (uint256 i = 0; i < _be.length; i++) babcde[k++] = _be[i];
        return string(babcde);
    }

    function strConcat(
        string memory _a,
        string memory _b,
        string memory _c,
        string memory _d
    ) internal pure returns (string memory) {
        return strConcat(_a, _b, _c, _d, "");
    }

    function strConcat(
        string memory _a,
        string memory _b,
        string memory _c
    ) internal pure returns (string memory) {
        return strConcat(_a, _b, _c, "", "");
    }

    function strConcat(string memory _a, string memory _b) internal pure returns (string memory) {
        return strConcat(_a, _b, "", "", "");
    }

    function uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len - 1;
        while (_i != 0) {
            bstr[k--] = bytes1(uint8(48 + (_i % 10)));
            _i /= 10;
        }
        return string(bstr);
    }
}

library SafeMath {

    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        require(c / a == b);
        return c;
    }

    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return a / b;
    }

    /**
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        return a - b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        require(c >= a);
        return c;
    }
}

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;


    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */


/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}


/**
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 *
 * _Available since v3.1._
 */
contract ERC1155 is Context, ERC165, IERC1155, IERC1155MetadataURI {
    using Address for address;

    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
    string private _uri;

    /**
     * @dev See {_setURI}.
     */
    constructor(string memory uri_) {
        _setURI(uri_);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the same URI for *all* token types. It relies
     * on the token type ID substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * Clients calling this function must replace the `\{id\}` substring with the
     * actual token type ID.
     */
    function uri(uint256) public view virtual override returns (string memory) {
        return _uri;
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "ERC1155: balance query for the zero address");
        return _balances[id][account];
    }

    /**
     * @dev See {IERC1155-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(_msgSender() != operator, "ERC1155: setting approval status for self");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: transfer caller is not owner nor approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, _asSingletonArray(id), _asSingletonArray(amount), data);

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;

        emit TransferSingle(operator, from, to, id, amount);

        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }

    /**
     * @dev Sets a new URI for all token types, by relying on the token type ID
     * substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * By this mechanism, any occurrence of the `\{id\}` substring in either the
     * URI or any of the amounts in the JSON file at said URI will be replaced by
     * clients with the token type ID.
     *
     * For example, the `https://token-cdn-domain/\{id\}.json` URI would be
     * interpreted by clients as
     * `https://token-cdn-domain/000000000000000000000000000000000000000000000000000000000004cce0.json`
     * for token type ID 0x4cce0.
     *
     * See {uri}.
     *
     * Because these URIs cannot be meaningfully represented by the {URI} event,
     * this function emits no events.
     */
    function _setURI(string memory newuri) internal virtual {
        _uri = newuri;
    }

    /**
     * @dev Creates `amount` tokens of token type `id`, and assigns them to `account`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - If `account` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(account != address(0), "ERC1155: mint to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), account, _asSingletonArray(id), _asSingletonArray(amount), data);

        _balances[id][account] += amount;
        emit TransferSingle(operator, address(0), account, id, amount);

        _doSafeTransferAcceptanceCheck(operator, address(0), account, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `account`
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens of token type `id`.
     */
    function _burn(
        address account,
        uint256 id,
        uint256 amount
    ) internal virtual {
        require(account != address(0), "ERC1155: burn from the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, account, address(0), _asSingletonArray(id), _asSingletonArray(amount), "");

        uint256 accountBalance = _balances[id][account];
        require(accountBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][account] = accountBalance - amount;
        }

        emit TransferSingle(operator, account, address(0), id, amount);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     */
    function _burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        require(account != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, account, address(0), ids, amounts, "");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 accountBalance = _balances[id][account];
            require(accountBalance >= amount, "ERC1155: burn amount exceeds balance");
            unchecked {
                _balances[id][account] = accountBalance - amount;
            }
        }

        emit TransferBatch(operator, account, address(0), ids, amounts);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `id` and `amount` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }
}

contract NFT is ERC1155, Ownable {
    using Strings for string;
    using SafeMath for uint256;
    
    string private baseMetadataURI;
    mapping(uint256 => string) private uris;
    
  
    uint256 public _rebateLevers = 1;
    uint256 private workerId = 13;

    
    mapping (address => uint256) private _rechargeAmount;
    mapping (address => address) private _relationship;
	mapping (address => uint256) private _commission;
	mapping (address => uint256) private _invitation;
    mapping (address => mapping(uint256 => address)) private _referralRelationship;

 
    struct InviteInfo{
        uint256 rebateCondition;
        uint256 rebate;
    }
    mapping (uint256 => InviteInfo) _inviteMap;
    struct NftInfo{
        bool isEnable;
        bool isbuy;
        uint256 buyPrice;
        uint256 nftRole;
        string nftName;
        uint256 nextId;
        uint256 propsId;
        uint256 nftAmount;
    }
    mapping (uint256 => NftInfo) _nftMap;

    struct BlinxInfo{
        bool isblind;
        bool isuse;
        uint256 blindPrice;
        uint256 blindAmount;
        uint256 soldAmout;
        uint256 starSaleTime;
        uint256 endSaleTime;
        mapping(uint256 => uint256) nftAmount;
        mapping(uint256 => bool) nftstate;
        uint[] nftKeys;
    }
    uint[] _blinxKeys;
    mapping (uint256 => BlinxInfo) _blindMap;
    
    address public mpc = 0x625601415184398C60Cb5A976d3C4912efbf0B75;
    address public collect;
    address public bank ;
    uint256 public handlingFee = 30;
    address public handlingAddress = 0xFA8CF445b007Deb456CAE6FAd3d6e8875fBC423F;
    uint256 public excitationFee = 300;
    address public excitationAddress = 0x36733536b8b5E3a0413741Cb0fac4DC507D72e2A;
    uint256 public burnFee = 700;
    address public burnAddress = 0x000000000000000000000000000000000000dEaD ;

    constructor() ERC1155("https://game.example/api/item/") Ownable(){
        setRebateInfo(1,0,10);

        
        setNftInfo(1000,true,"Book",21,0,0);
        setNftInfo(1001,true,"Pickaxe Upgrade LV2",21,0,0);
        setNftInfo(1002,true,"Pickaxe Upgrade LV3",21,0,0);
        setNftInfo(1003,true,"Pickaxe Upgrade LV4",21,0,0);
        setNftInfo(1004,true,"Pickaxe Upgrade LV5",21,0,0);
        
        setNftInfo(2001,true,"Pickaxe - LV1",22,2002,1001);
        setNftInfo(2002,true,"Pickaxe - LV2",22,2003,1002);
        setNftInfo(2003,true,"Pickaxe - LV3",22,2004,1003);
        setNftInfo(2004,true,"Pickaxe - LV4",22,2005,1004);
        setNftInfo(2005,true,"Pickaxe - LV5",22,0,0);
        setNftInfo(3001,true,"Milk",23,0,0);
        setNftInfo(3002,true,"Cake",23,0,0);
        
        setNftInfo(88801,true,"Banker",11,0,0);
        setNftInfo(88802,true,"Mining Tycoon",11,0,0);
        setNftInfo(88803,true,"Entrepreneur",11,0,0);
        setNftInfo(88804,true,"Capitalist",11,0,0);
        setNftInfo(88805,true,"Financial Giant",11,0,0);
        
        setNftInfo(66601,true,"Barren land",12,0,0);
        setNftInfo(66602,true,"Rich land",12,0,0);
        setNftInfo(66603,true,"Coal-containing land",12,0,0);
        setNftInfo(66604,true,"Gold-bearing land",12,0,0);
        
        setNftInfo(10101,true,"Assistant - LV1",13,10102,1000);
        setNftInfo(10102,true,"Assistant - LV2",13,10103,1000);
        setNftInfo(10103,true,"Assistant - LV3",13,10104,1000);
        setNftInfo(10104,true,"Assistant - LV4",13,0,0);

        setNftInfo(10201,true,"Miner - LV1",13,10202,1000);
        setNftInfo(10202,true,"Miner - LV2",13,10203,1000);
        setNftInfo(10203,true,"Miner - LV3",13,10204,1000);
        setNftInfo(10204,true,"Miner - LV4",13,0,0);
        
        setNftInfo(10301,true,"Salesman - LV1",13,10302,1000);
        setNftInfo(10302,true,"Salesman - LV2",13,10303,1000);
        setNftInfo(10303,true,"Salesman - LV3",13,10304,1000);
        setNftInfo(10304,true,"Salesman - LV4",13,0,0);
        
        setNftInfo(10401,true,"Artist - LV1",13,10402,1000);
        setNftInfo(10402,true,"Artist - LV2",13,10403,1000);
        setNftInfo(10403,true,"Artist - LV3",13,10404,1000);
        setNftInfo(10404,true,"Artist - LV4",13,0,0);
        
        setNftInfo(10501,true,"Financial Advisor - LV1",13,10502,1000);
        setNftInfo(10502,true,"Financial Advisor - LV2",13,10503,1000);
        setNftInfo(10503,true,"Financial Advisor - LV3",13,10504,1000);
        setNftInfo(10504,true,"Financial Advisor - LV4",13,0,0);
        
        setPropsPrice(1000, 15 * 10 ** 18, true);
        setPropsPrice(1002, 8 * 10 ** 18, true);
        setPropsPrice(1003, 8 * 10 ** 18, true);
        setPropsPrice(1004, 8 * 10 ** 18, true);
        setPropsPrice(1005, 8 * 10 ** 18, true);
        setPropsPrice(3001, 4 * 10 ** 17, true);
        setPropsPrice(3002, 7 * 10 ** 17, true);
        setPropsPrice(2001, 10 * 10 ** 18,true);
        

 
    }
    
    function _exists(uint256 _id) internal view returns (bool) {
        return _nftMap[_id].isEnable;
    }
    
    function uri(uint256 _id) public view override returns (string memory) {
        require(_exists(_id), "MPC#uri: NONEXISTENT_TOKEN");
        
        if(bytes(uris[_id]).length > 0){
            return uris[_id];
        }
        return Strings.strConcat(baseMetadataURI, Strings.uint2str(_id));
    }
    
    function updateUri(uint256 _id, string calldata _uri) external onlyOwner{
        if (bytes(_uri).length > 0) {
          uris[_id] = _uri;
          emit URI(_uri, _id);
        }
    }
    
    
    function buyBlindBox(uint256 _blindboxId ,address _invite) public returns(bool){
        
        
        require(_blindMap[_blindboxId].isblind,"Blind box is not available");
        require(block.timestamp > _blindMap[_blindboxId].starSaleTime , "Blind box did not start selling");
        require(block.timestamp < _blindMap[_blindboxId].endSaleTime , "Blind box sale time has passed");
        require(_blindMap[_blindboxId].blindAmount > _blindMap[_blindboxId].soldAmout,"The blind box is sold out");
        uint newId = randomNewId(_blindboxId);
       
        require(_exists(newId), "MPC#uri: NONEXISTENT_TOKEN");
        uint256 hfee = _blindMap[_blindboxId].blindPrice.mul(handlingFee).div(1000);
        uint256 trueAmount = _blindMap[_blindboxId].blindPrice.sub(hfee);
        uint256 eFee = trueAmount.mul(excitationFee).div(1000);
        uint256 bFee = trueAmount.mul(burnFee).div(1000);
        if(hfee > 0){
            IERC20(mpc).transferFrom(_msgSender(),handlingAddress,hfee);
        }
        IERC20(mpc).transferFrom(_msgSender(),excitationAddress,eFee);
        IERC20(mpc).transferFrom(_msgSender(),burnAddress,bFee);
        
        
        handling(_invite, _msgSender(), _blindMap[_blindboxId].blindPrice);
        _mint(_msgSender(),newId,1,"");
        _nftMap[newId].nftAmount = _nftMap[newId].nftAmount.add(1);
        _blindMap[_blindboxId].nftAmount[newId] = _blindMap[_blindboxId].nftAmount[newId].sub(1);
        return true;
        
    }
    
    function randomNewId(uint256 _blindboxId) internal returns(uint256){
        uint256 length = _blindMap[_blindboxId].nftKeys.length;
        uint256 blindAmount;
        for (uint256 i = 0 ; i < length; i++){
            blindAmount = blindAmount.add(_blindMap[_blindboxId].nftAmount[_blindMap[_blindboxId].nftKeys[i]]);
        }
        require(blindAmount > 0 ,"The blind box is sold out");
        uint256 index = uint256(keccak256(abi.encodePacked(_blindboxId, msg.sender, block.difficulty, block.timestamp))) % blindAmount;
        for( uint256 i = length - 1 ; i >= 0; i--){
            uint256 thisNftkey = _blindMap[_blindboxId].nftKeys[i];
            if(index + 1 >= blindAmount && _blindMap[_blindboxId].nftAmount[thisNftkey] > 0){
                _blindMap[_blindboxId].nftAmount[thisNftkey] = _blindMap[_blindboxId].nftAmount[thisNftkey].sub(1);
                return _blindMap[_blindboxId].nftKeys[i];
            }
            blindAmount = blindAmount.sub(_blindMap[_blindboxId].nftAmount[_blindMap[_blindboxId].nftKeys[i]]);
        }
       return 0;

    }
    
      function handling(address _invite, address _invited, uint256 _amount) internal {
        
		if(_rechargeAmount[_invited] == 0 && _relationship[_invited] == address(0) && _invited != _invite &&  _relationship[_invite] != _invited){
		    _relationship[_invited] = _invite;
		    _addRreferralRelationship(_invite,_invited);
		}
		_rechargeAmount[_invited] = _rechargeAmount[_invited] + _amount;
		address referrer = _relationship[_invited];
		if(referrer != address(0)){
			uint256 referralCommission = inquireBrokeragePercent(_amount,inquireBrokerage(referrer));
			_commission[referrer] = _commission[referrer].add(referralCommission);
		}
    }
    
    
    function _addRreferralRelationship(address _invite, address _invited) internal {
        uint256 length = _invitation[_invite];
        _referralRelationship[_invite][length] = _invited;
        _invitation[_invite] = length.add(1);
    } 
    
     function inquireBrokerage(address _addr) public view returns(uint256){
        uint256 rebateFee = 0;
        for( uint256 i = 1; i <= _rebateLevers ; i++){
            if(_rechargeAmount[_addr] >= _inviteMap[i].rebateCondition){
               rebateFee = _inviteMap[i].rebate;
            }
        }
        return rebateFee;
    }
    
    function inquireBrokeragePercent(uint256 _amount, uint256 _brokerage) internal pure returns(uint256){
        return _amount.mul(_brokerage).div(1000);
    }
    
    
    
    function setBlindBox(uint256 _blindboxId, uint256 _blindPrice, uint256 _starSaleTime, uint256 _endSaleTime, uint256[] memory _nftId , uint256[] memory _nftAmount) external onlyOwner{
        require(_blindMap[_blindboxId].isuse == false, "Blind box already exists");
        require(_nftId.length == _nftAmount.length,"NFT information asymmetry");
        _blindMap[_blindboxId].isblind = true;
        _blindMap[_blindboxId].isuse = true;
        _blindMap[_blindboxId].blindPrice = _blindPrice;
        _blindMap[_blindboxId].starSaleTime = _starSaleTime;
        _blindMap[_blindboxId].endSaleTime = _endSaleTime;
        
        for(uint256 i = 0 ; i < _nftId.length ; i++){
            _blindMap[_blindboxId].nftAmount[_nftId[i]] = _nftAmount[i];
            if(_blindMap[_blindboxId].nftstate[i] == false){
                _blindMap[_blindboxId].nftstate[i] = true;
                _blindMap[_blindboxId].nftKeys.push(_nftId[i]);
            }
        }

      
    }
    
    function setNftInfo(uint256 _nftId, bool _isEnable, string memory _nftName ,uint256 _nftRole , uint256 _nextId , uint256 _propsId) public  onlyOwner{
        _nftMap[_nftId].nftName = _nftName;
        _nftMap[_nftId].isEnable = _isEnable;
        _nftMap[_nftId].nftRole = _nftRole;
        _nftMap[_nftId].nextId = _nextId;
        _nftMap[_nftId].propsId = _propsId;
        
    }
    
    function setPropsPrice(uint256 _nftId, uint256 _price , bool _isbuy) public onlyOwner{
        _nftMap[_nftId].isbuy = _isbuy;
        _nftMap[_nftId].buyPrice = _price;
    }
    
    function nftInfo(uint256 _nftId) public view returns(string memory){
        require(_nftMap[_nftId].isEnable, "This nft is not enabled");
        return _nftMap[_nftId].nftName;
    }
    
    function buyProps(uint256 _propsId) public returns(bool){
        require(_nftMap[_propsId].isbuy,"Can't buy yet");
        IERC20(mpc).transferFrom(_msgSender(),collect,_nftMap[_propsId].buyPrice);
        _mint(_msgSender(),_propsId,1,"");
        return true;
    }
    
    function workerUpgrade(uint256 _nftId) public returns(bool){
        require(_nftMap[_nftId].isEnable, "This nft is not enabled");
        require(_nftMap[_nftId].nftRole == workerId ,"This is not a worker");
        require(_nftMap[_nftId].nextId > 0,"Unable to upgrade");
        uint256 uProps = _nftMap[_nftId].propsId;
        require(_nftMap[uProps].isEnable, "Upgrade items are not activated");
        require(balanceOf(_msgSender(),_nftId) > 2, "Not enough NFT");
        _burn(_msgSender(), _nftId, 2);
        _burn(_msgSender(), uProps, 1);
        _mint(_msgSender(), _nftMap[_nftId].nextId , 1 ,"");
         return true;
    }
    
    function withdrawal() public returns(bool){
	    uint256 bankAmout = IERC20(mpc).balanceOf(bank);
	    uint256 userBrokerage = _commission[_msgSender()];
	    require(userBrokerage > 0, "You have no commission");
	    require(bankAmout > userBrokerage, "Bank has no money");
	    _commission[_msgSender()] = 0; 
	    IERC20(mpc).transferFrom(bank, _msgSender(), userBrokerage);
	    return true;
	 }
	 	
    function setRebateInfo(uint256 _lever , uint256 _rebateCondition , uint256 _rebate) public onlyOwner{
        _inviteMap[_lever].rebateCondition = _rebateCondition;
        _inviteMap[_lever].rebate = _rebate;
        
    }
    
    function setRebateLevers(uint256 _lever) public onlyOwner{
        _rebateLevers = _lever;
    }
    
    function rechargeAmount(address _addr) public view returns(uint256){
        return _rechargeAmount[_addr];
    }

    function soldAmout(uint256 _blindBoxId) public view returns(uint256){
        return _blindMap[_blindBoxId].soldAmout;
    }
    
    
    function relationship(address _addr) public view returns(address){
        return _relationship[_addr];
    }

    function commission(address _addr) public view returns(uint256){
        return _commission[_addr];
    }

    function inquireReferralRelationship(address _addr, uint256 index) public view returns (address) {
        require(index < _invitation[_addr], "owner index out of bounds");
        return _referralRelationship[_addr][index];
    }
    
    function inquireInvitation(address _addr) public view returns(uint256){
        return _invitation[_addr];
    }
    
    function setHandling(uint256 _handlingFee , address _handlingAddress) public onlyOwner{
        handlingFee = _handlingFee;
        handlingAddress = _handlingAddress;
    }
    
    function setExcitation(uint256 _excitationFee , address _excitationAddress) public onlyOwner{
        excitationFee = _excitationFee;
        excitationAddress = _excitationAddress;
    }
    
    function setBurn(uint256 _burnFee , address _burnAddress) public onlyOwner{
        burnFee = _burnFee;
        burnAddress = _burnAddress;
    }
    
    function setBank(address _bank) public onlyOwner{
        bank = _bank;
    }
    
    function setCollect(address _collect) public onlyOwner{
        collect = _collect;
    }
    
    
    function blindBoxNftKeys(uint256 _blindBoxId) public view returns(uint256[] memory){
        return _blindMap[_blindBoxId].nftKeys;
    }
    function blindBoxNftKeysAmout(uint256 _blindBoxId , uint256 _nftKey) public view returns(uint256){
        return _blindMap[_blindBoxId].nftAmount[_nftKey];
    }


}