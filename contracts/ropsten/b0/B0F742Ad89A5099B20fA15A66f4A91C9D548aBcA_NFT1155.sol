// File: openzeppelin-contracts-master/contracts/introspection/IERC165.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";

// import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";

import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract NFT1155 is ERC1155Upgradeable, EIP712, AccessControlUpgradeable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    string private constant SIGNING_DOMAIN = "LazyNFT-Voucher";
    string private constant SIGNATURE_VERSION = "1";

    mapping (address => uint256) pendingWithdrawals;
    /// @notice Represents an un-minted NFT, which has not yet been recorded into the blockchain. A signed voucher can be redeemed for a real NFT using the redeem function.
    struct NFTVoucher {
        /// @notice The id of the token to be redeemed. Must be unique - if another token with this ID already exists, the redeem function will revert.
        uint256 tokenId;

        /// @notice The minimum price (in wei) that the NFT creator is willing to accept for the initial sale of this NFT.
        uint256 minPrice;

        /// @notice The metadata URI to associate with this token.
        string uri;

        /// @notice the EIP-712 signature of all other fields in the NFTVoucher struct. For a voucher to be valid, it must be signed by an account with the MINTER_ROLE.
        bytes signature;
    }
    
    event Supply(uint256 indexed tokenId, uint256 value);
    event Creators(uint256 indexed tokenId, address indexed value);

    mapping(uint256 => address) public creators;
    mapping(uint256 => uint256) public supply;
    mapping(uint256 => uint256) public minted;
    mapping(uint256 => string) private tokenURIs;
    
    /// @notice Redeems an NFTVoucher for an actual NFT, creating it in the process.
    /// @param redeemer The address of the account which will receive the NFT upon success.
    /// @param voucher A signed NFTVoucher that describes the NFT to be redeemed.
    function redeem(address redeemer, NFTVoucher calldata voucher, uint256 amount, uint256 maximum, bytes memory data) public payable returns (uint256) {
        // make sure signature is valid and get the address of the signer
        address signer = _verify(voucher);

        // make sure that the signer is authorized to mint NFTs
        require(hasRole(MINTER_ROLE, signer), "Signature invalid or unauthorized");

        // make sure that the redeemer is paying enough to cover the buyer's cost
        require(msg.value >= voucher.minPrice, "Insufficient funds to redeem");
        uint256 id = voucher.tokenId;
        if (supply[id] == 0) {
            _saveSupply(id, maximum);
            _saveCreator(id, _msgSender());
        }
        
        uint256 newMinted = amount + minted[id];
        require(newMinted <= supply[id], "more than supply");
        minted[id] = newMinted;

        // require(creators[id] == _msgSender(), "different creator");

        // first assign the token to the signer, to establish provenance on-chain

        _mint(signer, voucher.tokenId, amount, data);
        _setTokenURI(voucher.tokenId, voucher.uri);
        
        // transfer the token to the redeemer
        // _transfer(signer, redeemer, voucher.tokenId);
        _safeTransferFrom(signer, redeemer, voucher.tokenId, amount, data);
        // record payment to signer's withdrawal balance
        pendingWithdrawals[signer] += msg.value;

        return voucher.tokenId;
    }
    /// @notice Transfers all pending withdrawal balance to the caller. Reverts if the caller is not an authorized minter.
    function withdraw() public {
        require(hasRole(MINTER_ROLE, msg.sender), "Only authorized minters can withdraw");
        
        // IMPORTANT: casting msg.sender to a payable address is only safe if ALL members of the minter role are payable addresses.
        address payable receiver = payable(msg.sender);

        uint amount = pendingWithdrawals[receiver];
        // zero account before transfer to prevent re-entrancy attack
        pendingWithdrawals[receiver] = 0;
        receiver.transfer(amount);
    }
    /// @notice Retuns the amount of Ether available to the caller to withdraw.
    function availableToWithdraw() public view returns (uint256) {
        return pendingWithdrawals[msg.sender];
    }
    /// @notice Returns a hash of the given NFTVoucher, prepared using EIP712 typed data hashing rules.
    /// @param voucher An NFTVoucher to hash.
    function _hash(NFTVoucher calldata voucher) internal view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(
            keccak256("NFTVoucher(uint256 tokenId,uint256 minPrice,string uri)"),
            voucher.tokenId,
            voucher.minPrice,
            keccak256(bytes(voucher.uri))
        )));
    }

    /// @notice Returns the chain id of the current blockchain.
    /// @dev This is used to workaround an issue with ganache returning different values from the on-chain chainid() function and
    ///  the eth_chainId RPC method. See https://github.com/protocol/nft-website/issues/121 for context.
    function getChainID() external view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    /// @notice Verifies the signature for a given NFTVoucher, returning the address of the signer.
    /// @dev Will revert if the signature is invalid. Does not verify that the signer is authorized to mint NFTs.
    /// @param voucher An NFTVoucher describing an unminted NFT.
    function _verify(NFTVoucher calldata voucher) internal view returns (address) {
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, voucher.signature);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override (AccessControlUpgradeable, ERC1155Upgradeable) returns (bool) {
        return ERC1155Upgradeable.supportsInterface(interfaceId) || AccessControlUpgradeable.supportsInterface(interfaceId);
    }
    constructor(address payable minter)
    EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {
      _setupRole(MINTER_ROLE, minter);
    }
    function initialize(string memory _uri) public initializer {
        __ERC1155_init(_uri);
        __ERC1155_init_unchained(_uri);
        // __EIP712_init(SIGNING_DOMAIN, SIGNATURE_VERSION);
    }

    function _saveSupply(uint256 _tokenId, uint256 _supply) internal {
        require(supply[_tokenId] == 0);
        supply[_tokenId] = _supply;
        emit Supply(_tokenId, _supply);
    }

    function _saveCreator(uint256 _tokenId, address _creator) internal {
        creators[_tokenId] = _creator;
        emit Creators(_tokenId, _creator);
    }
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        return tokenURIs[tokenId];
    }
    function _setTokenURI(uint256 tokenId, string memory tokenUri) internal virtual {
        tokenURIs[tokenId] = tokenUri;
        emit URI(tokenUri, tokenId);
    }
}