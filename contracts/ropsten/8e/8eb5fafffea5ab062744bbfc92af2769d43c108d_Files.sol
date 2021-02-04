/**
 *Submitted for verification at Etherscan.io on 2021-02-04
*/

// File: @openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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

// File: @openzeppelin/contracts-upgradeable/proxy/Initializable.sol

// SPDX-License-Identifier: MIT

// solhint-disable-next-line compiler-version
pragma solidity >=0.4.24 <0.8.0;


/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {UpgradeableProxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {

    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || _isConstructor() || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /// @dev Returns true if and only if the function is running in the constructor
    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

// File: @openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;


/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
    uint256[50] private __gap;
}

// File: @openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
    uint256[49] private __gap;
}

// File: @openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    /**
     * @dev Converts a `uint256` to its ASCII `string` representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        uint256 index = digits - 1;
        temp = value;
        while (temp != 0) {
            buffer[index--] = bytes1(uint8(48 + temp % 10));
            temp /= 10;
        }
        return string(buffer);
    }
}

// File: contracts/Files.sol

// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity >=0.4.22 <0.8.0;



contract Files is OwnableUpgradeable {

    // V2 contract : Adding new meta data field

    // Audio Fles Contract:

    // File number: 1 
    // Title: Breaking the Chain
    // Album: Living an Impossible Dream
    // Website: https://QuantumIndigo.org
    // IPFS URL: (IPFS URL)
    // Comment: The World's First Decentralised Media Arts Collective.
    // Copyright: 2020 QMP (GnuPG ID FFE28038)
    // Submission Date: [DD.MM.YY]
    // Blockchain Write Date: [UNIX Date Generated by Smart Contract]
    // MD5 Hash: [MD5_hash]
    // New Info: [New Info]

    struct FileOutput {
		string separator;
        string file_number;
		string title;
		string album;
		string website;
		string ipfs_hash;
		string comment;
		string copyright;
        string submission_date;
		string blockchain_date;
        string md_hash;
        string new_info;
    }

    struct FileOutputCollection {
		string[] separator;
        string[] file_number;
		string[] title;
		string[] album;
		string[] website;
		string[] ipfs_hash;
		string[] comment;
		string[] copyright;
        string[] submission_date;
		string[] blockchain_date;
        string[] md_hash;
        string[] new_info;
    }

    uint256 private size;

	// Searches will be done nased on IPFS hash and SHA256 Hash.

    mapping(uint256 => string) filesNumberIndex;
    mapping(string => uint256[]) filesByNumber;

    mapping(uint256 => string) filesIpfsHashIndex;
    mapping(string => uint256[]) filesByIpfsHash;

	mapping(uint256 => string) filesMDHashIndex;
    mapping(string => uint256[]) filesByMDHash;

  
	mapping(uint256 => string) filesTitleIndex;
    mapping(uint256 => string) filesAlbumSeriesIndex;
	mapping(uint256 => string) filesWebsiteIndex;
	mapping(uint256 => string) filesCommentIndex;
	mapping(uint256 => string) filesCopyrightIndex;
    mapping(uint256 => string) filesSubmissionDateIndex;
	mapping(uint256 => uint256) filesBlockchainDateIndex;
    mapping(uint256 => string) filesNewInfoIndex;
    
    function initialize() initializer public {
        __Ownable_init();
    }

    function addFile(string[] memory metadata) public onlyOwner returns (uint256) {

        require( metadata.length == 10);

		// Data is pasted in FileOutput Order. Blockchain date is skipped because it will be added when the block is mined.
		// 8 Items in total

        string memory _file_number = metadata[0];
        string memory _title = metadata[1];
        string memory _album = metadata[2];
        string memory _website = metadata[3];
	    string memory _ipfs_hash = metadata[4];
        string memory _comment = metadata[5];
		string memory _copyright = metadata[6];
        string memory _submission_date = metadata[7];
		string memory _md_hash = metadata[8];
        string memory _new_info = metadata[9];
 

        filesNumberIndex[size] = _file_number;
        filesTitleIndex[size] = _title;
        filesAlbumSeriesIndex[size] = _album;
        filesWebsiteIndex[size] = _website;
        filesIpfsHashIndex[size] = _ipfs_hash;
        filesCommentIndex[size] = _comment;
        filesCopyrightIndex[size] = _copyright;
        filesSubmissionDateIndex[size] = _submission_date;
        filesBlockchainDateIndex[size] = block.timestamp;
		filesMDHashIndex[size] = _md_hash;
        filesNewInfoIndex[size] = _new_info;


        filesByNumber[_file_number].push(size);
        filesByIpfsHash[_ipfs_hash].push(size);
        filesByMDHash[_md_hash].push(size);

        size = size + 1;
        return size;
    }

    function Find_Files_by_QI_Audio_Catalogue_Number(uint256 QI_Audio_Catalogue) view external returns (FileOutput[] memory) {
        return findFilesByKey(1, StringsUpgradeable.toString(QI_Audio_Catalogue));
    }

    function Find_Files_by_IPFS_Hash(string calldata IPFS_Hash) view external returns (FileOutput[] memory) {
        return findFilesByKey(2, IPFS_Hash);
    }

    function Find_Files_by_MD5_Hash(string calldata MD5_Hash) view external returns (FileOutput[] memory) {
        return findFilesByKey(3, MD5_Hash);
    }

    function findFilesByKey(int key, string memory hash) view internal returns (FileOutput[] memory) {
        uint256 len;


        if(key == 1){
            len = filesByNumber[hash].length;
        } 

        if(key == 2){
            len = filesByIpfsHash[hash].length;
        } 

        if(key == 3){
            len = filesByMDHash[hash].length;
        } 

        FileOutputCollection memory outputsCollection;

        outputsCollection.separator = new string[](len);
        outputsCollection.file_number = new string[](len);
        outputsCollection.title = new string[](len);
        outputsCollection.album = new string[](len);
        outputsCollection.website = new string[](len);
        outputsCollection.ipfs_hash = new string[](len);
        outputsCollection.comment = new string[](len);
        outputsCollection.copyright = new string[](len);
        outputsCollection.submission_date = new string[](len);
        outputsCollection.blockchain_date = new string[](len);	
		outputsCollection.md_hash = new string[](len);	
        outputsCollection.new_info = new string[](len);	

        for (uint256 index = 0; index < len; index++){
            uint256 id;

            if(key == 1){
                id = filesByNumber[hash][index];
            } 

            if(key == 2){
                id = filesByIpfsHash[hash][index];
            } 

            if(key == 3){
                id = filesByMDHash[hash][index];
            } 

            (uint year, uint month, uint day) = timestampToDate(filesBlockchainDateIndex[id]);

            outputsCollection.file_number[index] = filesNumberIndex[id];
            outputsCollection.title[index] = filesTitleIndex[id];
            outputsCollection.album[index] = filesAlbumSeriesIndex[id];
            outputsCollection.website[index] = filesWebsiteIndex[id];
            outputsCollection.ipfs_hash[index] = filesIpfsHashIndex[id];
            outputsCollection.comment[index] = filesCommentIndex[id];
            outputsCollection.copyright[index] = filesCopyrightIndex[id];
            outputsCollection.submission_date[index] = filesSubmissionDateIndex[id];
            outputsCollection.blockchain_date[index] =  concat( StringsUpgradeable.toString(day),  "-",  StringsUpgradeable.toString(month), "-", StringsUpgradeable.toString(year) );
			outputsCollection.md_hash[index] = filesMDHashIndex[id];	
            outputsCollection.new_info[index] = filesNewInfoIndex[id];	

        }

        
		FileOutput[] memory outputs = new FileOutput[](len);
		for (uint256 index = 0; index < len; index++) {

            FileOutput memory output;

            output = FileOutput(
                "****",
                concat("File Number: ", outputsCollection.file_number[index]),
                concat("Title: ", outputsCollection.title[index]),
                concat("Album: ", outputsCollection.album[index]),
                concat("Website: ", outputsCollection.website[index]),
                concat("IPFS URL: https://ipfs.io/ipfs/", outputsCollection.ipfs_hash[index]),
                concat("Comment: ", outputsCollection.comment[index]),
                concat("Copyright: ", outputsCollection.copyright[index]),
                concat("Submission Date: ", outputsCollection.submission_date[index]),
                concat("Blockchain Write Date: ", outputsCollection.blockchain_date[index]),
                concat("MD5 Hash: ", outputsCollection.md_hash[index]),
                concat("New Info: ", outputsCollection.new_info[index])
            );

			outputs[index] = output;
		}
		return outputs;

	}

	function concat(string memory a, string memory b) private pure returns (string memory) {
		return string(abi.encodePacked(a, b));
	}

    
	function timestampToDate(uint timestamp) internal pure returns (uint year, uint month, uint day) {
        (year, month, day) = _daysToDate(timestamp / (24 * 60 * 60));
    }

    function _daysToDate(uint _days) internal pure returns (uint year, uint month, uint day) {
        int __days = int(_days);

        int L = __days + 68569 + 2440588;
        int N = 4 * L / 146097;
        L = L - (146097 * N + 3) / 4;
        int _year = 4000 * (L + 1) / 1461001;
        L = L - 1461 * _year / 4 + 31;
        int _month = 80 * L / 2447;
        int _day = L - 2447 * _month / 80;
        L = _month / 11;
        _month = _month + 2 - 12 * L;
        _year = 100 * (N - 49) + _year + L;

        year = uint(_year);
        month = uint(_month);
        day = uint(_day);
    }

	function concat(string memory a, string memory b, string memory c, string memory d, string memory e) private pure returns (string memory) {
		return string(abi.encodePacked(a, b, c, d, e));
	}

}