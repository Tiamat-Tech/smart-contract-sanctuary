pragma solidity ^0.8.0;


/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// Ownable.sol


pragma solidity ^0.8.0;


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


pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}


//newerc.sol
pragma solidity ^0.8.0;

import "./ERC721A.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract newerc is ERC721A ,Ownable, Pausable,  ReentrancyGuard {
	using Strings for uint256;
	string public baseURI;
	uint256 public cost = 0.045 ether;
	uint256 public maxSupply = 10000;
    uint256 public maxwhitlist = 20;
    uint256 public nftPerwhiteAddressLimit = 2;
    //bytes32  public merkleroot=0x792c67a7699557b94b6f7be389d8d28d786e950e965a2386f5ba877e8a5cadb7;
    bytes32  public merkleroot;
    mapping(address=>bool) public whitelistClaimed;
    mapping(address => uint256) public whitelistaddressMinted;

	bool public status = false;
    mapping(address => uint256) public addressMintedBalance;


	constructor(bytes32 _merkleroot) ERC721A("Newerc", "newerc"){
	    setBaseURI("");
        merkleroot=_merkleroot;

	}

	function _baseURI() internal view virtual override returns (string memory) {
	    return baseURI;
	}
  function whitelistMint(bytes32[] calldata _merkleProof,uint256 _mintAmount) public payable nonReentrant{
     uint256 s = totalSupply();
     uint256 ownerMintedCount = whitelistaddressMinted[msg.sender];
     require(ownerMintedCount + _mintAmount <= nftPerwhiteAddressLimit, "max NFT per Whitelist address exceeded");
     require(_mintAmount > 0, "Cant mint 0" );
     require(s + _mintAmount <= maxwhitlist, "Cant go over supply" );
     require(msg.value >= cost * _mintAmount);
    // require(!whitelistClaimed[msg.sender], "Address has Already Cliamed" );
     bytes32 leaf=keccak256(abi.encodePacked(msg.sender));
     require(MerkleProof.verify(_merkleProof, merkleroot, leaf),"Invalid  Proof.");
     //whitelistClaimed[msg.sender];

		for (uint256 i = 0; i < _mintAmount; ++i) {
            addressMintedBalance[msg.sender]++;
			_safeMint(msg.sender, s + i, "");
		}
		delete s;
        delete ownerMintedCount;


  }

	function mint(uint256 _mintAmount) public payable nonReentrant{
		uint256 s = totalSupply();
        require(_mintAmount > 0, "Cant mint 0" );
		require(_mintAmount <= 20, "Cant mint more then maxmint" );
		require(s + _mintAmount <= maxSupply, "Cant go over supply" );
		require(msg.value >= cost * _mintAmount);
		for (uint256 i = 1; i < _mintAmount; i++) {
			_safeMint(msg.sender, s + i, "");
		}
		delete s;
	}

	function gift(uint[] calldata quantity, address[] calldata recipient) external onlyOwner{
		require(quantity.length == recipient.length, "Provide quantities and recipients" );
		uint totalQuantity = 0;
		uint256 s = totalSupply();
		for(uint i = 0; i < quantity.length; ++i){
			totalQuantity += quantity[i];
		}
		require( s + totalQuantity <= maxSupply, "Too many" );
		delete totalQuantity;
		for(uint i = 0; i < recipient.length; ++i){
			for(uint j = 0; j < quantity[i]; ++j){
			_safeMint( recipient[i], s++, "" );
			}
		}
		delete s;
	}

	function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
	    require(_exists(tokenId), "ERC721Metadata: Nonexistent token");
	    string memory currentBaseURI = _baseURI();
	    return bytes(currentBaseURI).length > 0	? string(abi.encodePacked(currentBaseURI, tokenId.toString())) : "";
	}


function setMerkleroot(bytes32 _newsetMerkleroot) public onlyOwner {
	    merkleroot = _newsetMerkleroot;
	}

	function setCost(uint256 _newCost) public onlyOwner {
	    cost = _newCost;
	}


    	function setmaxSupply(uint256 _newMaxSupply) public onlyOwner {
	    maxSupply = _newMaxSupply;
	}
	function setBaseURI(string memory _newBaseURI) public onlyOwner {
	    baseURI = _newBaseURI;
	}
	function setSaleStatus(bool _status) public onlyOwner {
	    status = _status;
	}
	function withdraw() public payable onlyOwner {
	(bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
	require(success);
	}
    function withdrawSome(uint256 _amount) public payable onlyOwner {
	(bool success, ) = payable(msg.sender).call{value: _amount}("");
	require(success);
	}

}