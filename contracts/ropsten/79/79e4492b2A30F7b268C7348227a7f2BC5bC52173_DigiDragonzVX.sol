// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

contract DigiDragonzVX is ERC721, EIP712, Ownable {
    using Counters for Counters.Counter;
    using Strings for uint;

    Counters.Counter private _tokenIds;
    
    enum SaleStatus{ PAUSED, PRESALE, PUBLIC, GENESISONE }

    uint public constant COLLECTION_SIZE = 5015;
    uint public constant WHITELIST_COUNT = 2500;
    uint public constant GENESIS_ONE_COUNT = 1500;

    uint public constant WHITELIST_TOKENS_MAX = 2;
    uint public constant PUBLIC_TOKENS_MAX = 5;
    
    uint public constant WHITELIST_PRICE = 0.03 ether;
    uint public constant PUBLIC_PRICE = 0.1 ether;

    SaleStatus public saleStatus = SaleStatus.PAUSED;
    bool public canReveal = false;

    uint private _whitelistMintedCount;
    
    string private _placeholderURI;
    string private _baseUri;
    address private immutable _txSigner;

    mapping(address => bool) private _genesisOneMintedMap;
    mapping(address => uint) private _whitelistMintedMap;
    mapping(address => uint) private _publicMintedMap;

    constructor(
        string memory placeholderURI,
        string memory baseUri,
        address txSigner,
        uint reserveCount
    )
    ERC721("DigiDragonzVX", "DDVX")
    EIP712("DigiDragonzVX", "1")
    {
        _placeholderURI = placeholderURI;
        _baseUri = baseUri;
        _txSigner = txSigner;

        if(reserveCount > 0) {
            _mintTokens(msg.sender, reserveCount);
        }
    }

    struct NFTVoucher {
        address redeemer;
        bool whitelisted;
        bool genesisOne;
        uint numberOfTokens;
    }

    function totalSupply() external view returns (uint) {
        return _tokenIds.current();
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseUri;
    }

    /// @notice Set placeholder uri
    function setHiddenUri(string memory uri) external onlyOwner {
        _placeholderURI = uri;
    }

    /// @notice Set sales status
    function setSaleStatus(SaleStatus status) external onlyOwner {
        saleStatus = status;
    }

    /// @notice Reveal metadata for all the tokens
    function reveal() external onlyOwner {
        canReveal = true;
    }

    /// @notice Get token's URI. In case of delayed reveal we give user the json of the placeholer metadata.
    /// @param tokenId token ID
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        return canReveal 
            ? string(abi.encodePacked(_baseURI(), tokenId.toString(), ".json"))
            : _placeholderURI;
    }

    /// @notice Withdraw contract balance to the owner's address
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance");

        payable(owner()).transfer(balance);
    }

    // function getGenesisOneHolderTokenAllowance(address hodler) external returns (uint){
    //     return 0;
    // }

    /// @notice redeem free VX for Genesis One holders
    function genesisOneRedeem(NFTVoucher calldata voucher, address signer, bytes memory signature) external {
        validateCommon(voucher, signer, signature, 0, voucher.numberOfTokens);

        require(saleStatus == SaleStatus.GENESISONE, "Genesis One sale is off");
        require(voucher.genesisOne, "You are not a genesis one holder");
        require(_genesisOneMintedMap[voucher.redeemer] == false, "You've already redeemed your Genesis One VX");

        _mintTokens(voucher.redeemer, voucher.numberOfTokens);
        _genesisOneMintedMap[voucher.redeemer] = true;
    }

    /// @notice whitelist mint
    function whitelistRedeem(NFTVoucher calldata voucher, address signer, bytes memory signature) external payable {
        validateCommon(voucher, signer, signature, WHITELIST_PRICE, voucher.numberOfTokens);

        require(saleStatus == SaleStatus.PRESALE, "Whitelist sale is off");
        require(voucher.whitelisted, "Wallet is not whitelisted");
        require(_whitelistMintedMap[voucher.redeemer] + voucher.numberOfTokens <= WHITELIST_TOKENS_MAX, "Token quantity exceeds allowance (2)");

        _mintTokens(voucher.redeemer, voucher.numberOfTokens);
        _whitelistMintedMap[voucher.redeemer] += voucher.numberOfTokens;
        _whitelistMintedCount += voucher.numberOfTokens;
    }

    /// @notice public mint
    function redeem(NFTVoucher calldata voucher, address signer, bytes memory signature) external payable {
        validateCommon(voucher, signer, signature, PUBLIC_PRICE, voucher.numberOfTokens);
        require(saleStatus == SaleStatus.PUBLIC, "Public sale is off");

        uint remainingTokens = COLLECTION_SIZE - GENESIS_ONE_COUNT - _whitelistMintedCount;

        require(_tokenIds.current() + voucher.numberOfTokens <= remainingTokens, "Token quantity exceeds collection size");
        require(_publicMintedMap[voucher.redeemer] + voucher.numberOfTokens <= PUBLIC_TOKENS_MAX, "Token quantity exceeds allowance (5)");

        _mintTokens(voucher.redeemer, voucher.numberOfTokens);
        _publicMintedMap[voucher.redeemer] += voucher.numberOfTokens;
    }

    /// @dev perform common validations
    function validateCommon(NFTVoucher calldata voucher, address signer, bytes memory signature, uint price, uint tokenCount) internal {
        require(_verify(signer, _hash(voucher), signature), "Transaction is not authorized (invalid signature)");
        require(saleStatus != SaleStatus.PAUSED, "Sale is off");
        require(msg.value >= voucher.numberOfTokens * price, "Ether value sent is incorrect");
        require(tokenCount > 0, "Number of tokens in incorrect");
    }

    function _mintTokens(address to, uint count) internal {
        for(uint index = 0; index < count; index++) {

            _tokenIds.increment();
            uint newItemId = _tokenIds.current();

            _safeMint(to, newItemId);
        }
    }

    /// @notice Returns a hash of the given NFTVoucher, prepared using EIP712 typed data hashing rules.
    /// @param voucher An NFTVoucher to hash.
    function _hash(NFTVoucher calldata voucher)
    internal view returns (bytes32)
    {
        return _hashTypedDataV4(keccak256(abi.encode(
            keccak256("NFTVoucher(address redeemer,bool whitelisted,bool genesisOne,uint numberOfTokens)"),
            voucher.redeemer,
            voucher.whitelisted,
            voucher.genesisOne,
            voucher.numberOfTokens
        )));
    }

    function _verify(address signer, bytes32 digest, bytes memory signature)
    internal view returns (bool)
    { 
        return _txSigner == signer && SignatureChecker.isValidSignatureNow(signer, digest, signature);
    }
}