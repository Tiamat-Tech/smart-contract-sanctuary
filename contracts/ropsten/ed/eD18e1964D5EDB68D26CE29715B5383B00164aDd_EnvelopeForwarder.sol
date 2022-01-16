// SPDX-License-Identifier: MIT.

pragma solidity ^0.8.11;

// import 'openzeppelin-solidity/contracts/token/ERC721/ERC721.sol';
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

//  These contracts work in concert to turn an Ethereum account to be an ERC721 token.
//  With this, various rights (ERC20, ERC721, Ownable contracts, etc) can be given to a
//  generic contract, and then that contract can be transferred as a single ERC721 token.
//
//  EnvelopeToken is a mintable, burnarble ERC721 token for addresses.  You can only mint
//  tokens whose low 160 bits are msg.sender and whose high 96 bits are the block number.
//  Additionally, the address which is the low 160 bits can burn the token.  This token is
//  meant to be used exclusively wih EnvelopeForwarder.
//
//  Upon contract creation, EnvelopeForwarder sets msg.sender to be the owner.  It exposes
//  execute() which executes a supplied transaction only if the sender owns the contract.
//  It also exposes seal(), which disables execute() and mints an EnvelopeToken to the
//  owner.  The owner of this token can tear(), which will burn the token and give them
//  ownership of the contract, allowing them to execute() arbitrary transactions.
//
//  In this way, the rights associated with an address can be frozen into an ERC721, used
//  as such, then restored.

contract EnvelopeToken is ERC721
{
    constructor() ERC721("EnvelopeToken", "ENV") {}
    
    function safeMint(address _to, uint256 _tokenId) public {
        // Could compute instead of requiring, but I'm worried someone
        // might use the forwarder with the wrong token contract
        require(_tokenId == (uint256(block.number) << uint256(160)) + uint256(uint160(address(msg.sender))));
        _safeMint(_to, _tokenId);
    }

    function burn(uint256 tokenId) public {
        require(msg.sender == address(uint160(tokenId)));
        _burn(tokenId);
    }
}

// Ownable code copied in because _setOwner is private in the original.
// The only change is to make _setOwner internal.

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

    function _setOwner(address newOwner) internal {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract EnvelopeForwarder is ERC721Holder, ERC1155Holder, Ownable {
    EnvelopeToken public token;
    uint256 public tokenId;
    
    constructor(address _token) {
        token = EnvelopeToken(_token);
    }
    
    function seal() public onlyOwner() {
        // Anything else we can add to make it more unique?
        tokenId = (uint256(block.number) << uint256(160)) + uint256(uint160(address(this)));
        _setOwner(address(0));
        token.safeMint(msg.sender, tokenId); // This crashes on failure, right?
    }
    
    function tear() public {
        require(msg.sender == token.ownerOf(tokenId));
        _setOwner(token.ownerOf(tokenId));
        token.burn(tokenId);
        tokenId = 0;
    }

    function execute(address _to, bytes calldata _data)
        public
        payable
        onlyOwner()
        returns (bytes memory)
    {
        (bool success, bytes memory returnValue) = _to.call{value: msg.value}(_data);
        require(success);
        return returnValue;
    }
}