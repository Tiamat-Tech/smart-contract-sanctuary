//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "hardhat/console.sol";
import './ERC2981ContractWideRoyalties.sol';
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./ERC2981Base.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract DoggyBulls is ERC721URIStorage, ERC2981ContractWideRoyalties, Ownable, AccessControl {
    using ECDSA for bytes32;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    mapping(address => uint256) pendingWithdrawals;

    // AbstraXio Main
    address payable AbstraXioMain = payable(0x4f59b6cfde2845cB76Ace0fDd4dDB362A8eb1630);

    // AbstraXio Hold
    address payable AbstraXioHold = payable(0xB09E16918bEe878Bd896043734E919831c8fc8aF);

    // AbstraXio Royalties
    address payable AbstraXioRoyalties = payable(0x1beeb69Bd2be894dc7E79FF3AbE91E5FF6Dc42B6);

    // address that signed the data
    address payable signedAddress = payable(0xBCf64cfe8a2a11E1B352F852722Afb959c26b30a);

    function contractURI() public pure returns (string memory) {
        return "https://ipfs.abstraxio.com/doggybulls/collectionMeta.json";
    }

    /// @notice Allows to set the royalties on the contract
    /// @dev This function in a real contract should be protected with a onlOwner (or equivalent) modifier
    /// @param recipient the royalties recipient
    /// @param value royalties value (between 0 and 10000)
    function setRoyalties(address recipient, uint256 value) public onlyOwner {
        _setRoyalties(recipient, value);
    }

    constructor() ERC721("DoggyBulls", "META") {
        _setupRole(MINTER_ROLE, signedAddress);
        _setRoyalties(AbstraXioRoyalties, 700);
    }

    /// @notice Represents an un-minted NFT, which has not yet been recorded into the blockchain. A signed voucher can be redeemed for a real NFT using the redeem function.
    struct NFTVoucher {
        /// @notice The id of the token to be redeemed. Must be unique - if another token with this ID already exists, the redeem function will revert.
        uint256 tokenId;

        /// @notice The minimum price (in wei) that the NFT creator is willing to accept for the initial sale of this NFT.
        uint256 minPrice;

        /// @notice The metadata URI to associate with this token.
        string uri;
    }

    event MintedToken (
        uint256 indexed tokenId,
        address buyer,
        uint256 price,
        uint256 fees
    );

    /// @notice Redeems an NFTVoucher for an actual NFT, creating it in the process.
    /// @param voucher An NFTVoucher that describes the NFT to be redeemed.
    /// @param signature A signature of the voucher, produced by the NFT creator.
    function redeem(NFTVoucher calldata voucher, bytes memory signature) public payable returns (uint256) {
        address redeemer = msg.sender;
        // make sure signature is valid and get the address of the signer
        address signer = _verify(voucher, signature);

        // make sure that the signer is authorized to mint NFTs
        // error : Signature invalid or unauthorized : 1
        require(hasRole(MINTER_ROLE, signer), "1");

        // make sure that the redeemer is paying enough to cover the buyer's cost
        // error : Insufficient funds to redeem : 2
        require(msg.value >= voucher.minPrice, "2");

        // first assign the token to the signer, to establish provenance on-chain
        _mint(redeemer, voucher.tokenId);
        _setTokenURI(voucher.tokenId, voucher.uri);

        // record payment to projectOwner's withdrawal balance
        pendingWithdrawals[AbstraXioMain] += msg.value * 20 / 100;

        // record payment to owner's withdrawal balance
        pendingWithdrawals[AbstraXioHold] += msg.value * 80 / 100;

        emit MintedToken(
            voucher.tokenId,
            redeemer,
            msg.value,
            msg.value * 20 / 100
        );

        return voucher.tokenId;
    }

    function withdraw(address payable receiver, address payable receiveMoney) public onlyOwner {
        uint amount = pendingWithdrawals[receiver];
        require(amount > 0, "noting to withdraw");
        // zero account before transfer to prevent re-entrancy attack
        pendingWithdrawals[receiver] = 0;
        receiveMoney.transfer(amount);
    }

    function availableToWithdraw(address receiver) public view onlyOwner returns (uint256)  {
        return pendingWithdrawals[receiver];
    }

    /// @notice Returns a hash of the given NFTVoucher
    /// @param voucher An NFTVoucher to hash.
    function _hash(NFTVoucher calldata voucher) internal pure returns (bytes32) {
        return keccak256(abi.encode(
                voucher.tokenId,
                voucher.minPrice,
                voucher.uri
            ));
    }

    function hashData(NFTVoucher calldata voucher) public pure returns (bytes32) {
        return _hash(voucher);
    }

    /// @notice Verifies the signature for a given NFTVoucher, returning the address of the signer.
    /// @dev Will revert if the signature is invalid. Does not verify that the signer is authorized to mint NFTs.
    /// @param voucher An NFTVoucher describing an unminted NFT.
    /// @param signature An EIP712 signature of the given voucher.
    function _verify(NFTVoucher calldata voucher, bytes memory signature) internal pure returns (address) {
        bytes32 digest = _hash(voucher);
        return digest.toEthSignedMessageHash().recover(signature);
    }

    function verifySignature(NFTVoucher calldata voucher, bytes memory signature) public pure returns (address) {
        return _verify(voucher, signature);
    }

    /// @inheritdoc	ERC165
    function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(AccessControl, ERC721, ERC2981Base)
    returns (bool)
    {
        return ERC721.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId) || super.supportsInterface(interfaceId);
    }

}