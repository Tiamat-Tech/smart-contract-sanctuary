// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./fuzz.sol";

/**
 * FaceMASK Nft Collection.
 */
contract FaceMask is ERC721, ERC721Enumerable, Ownable {

    using SafeMath for uint256;

    uint256 public constant MAX_SUPPLY = 1000;
    uint256 public constant MAX_NFT_PER_WALLET = 20;
    uint256 public constant MAX_NFT_PER_TX = 5;
    uint256 private _price = 0.01 ether;
    uint256 private _reserved = 0;

    // The hashed mint pass.
    bytes32 private hashedSecret;
    bytes32 private _salt;

    // Use the mint pass ?
    bool private _use_secret = true;

    bool private _saleStarted;
    string public baseURI;

    address public  withdrawAddress = address(0);

    constructor() ERC721("FaceMask", "MASK") {
        _saleStarted = false;
        _salt = keccak256(type(fuzz).creationCode);
    }

    modifier whenSaleStarted() {
        require(_saleStarted, "The mint has not started.");
        _;
    }

    function mint(uint256 _nbTokens) external payable whenSaleStarted {
        require(!_use_secret, "A mintPass is required !");
        
        _mint(_nbTokens);
    }

    // Override with mintPass usage.
    function mintWithPass(uint256 _nbTokens, bytes32 hash) external payable whenSaleStarted {
        require(verifiyHashSignature(hash), "Wrong mintPass !");

        _mint(_nbTokens);
    }

    function _mint(uint256 _nbTokens) private {
        uint256 supply = totalSupply();
        require(_nbTokens < MAX_NFT_PER_TX, "You cannot mint that much tokens at once!");
        require(supply + _nbTokens <= MAX_SUPPLY - _reserved, "Not enough Tokens left.");
        require(_nbTokens * _price <= msg.value, "Inconsistent amount sent!");

        for (uint256 i; i < _nbTokens; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }

    function flipSaleStarted() external onlyOwner {
        _saleStarted = !_saleStarted;
    }

    function setWithdrawAddress(address addr) external onlyOwner {
        withdrawAddress = addr;
    }

    function saleStarted() public view returns(bool) {
        return _saleStarted;
    }

    function setBaseURI(string memory _URI) external onlyOwner {
        baseURI = _URI;
    }

    function _baseURI() internal view override(ERC721) returns(string memory) {
        return baseURI;
    }

    // Make it possible to change the price: just in case
    function setPrice(uint256 _newPrice) external onlyOwner {
        _price = _newPrice;
    }

    function getPrice() public view returns (uint256){
        return _price;
    }

    function getReservedLeft() public view returns (uint256) {
        return _reserved;
    }

    // Helper to list all the NFT of a wallet
    function walletOfOwner(address _owner) public view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for(uint256 i; i < tokenCount; i++){
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    function claimReserved(uint256 _number, address _receiver) external onlyOwner {
        require(_number <= _reserved, "That would exceed the max reserved.");

        uint256 _tokenId = totalSupply();
        for (uint256 i; i < _number; i++) {
            _safeMint(_receiver, _tokenId + i);
        }

        _reserved = _reserved - _number;
    }

    function withdraw() public onlyOwner {
        uint256 _balance = address(this).balance;
        require(withdrawAddress != address(0), "Withdrawal address not set !");
        require(payable(withdrawAddress).send(_balance));
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // mintPass related.
    function encode(string memory code) public view returns(bytes32) {
        return keccak256(abi.encodePacked(code, _salt));
    }

    function setHashedSecret(bytes32 hash) external onlyOwner  {
        hashedSecret = hash;
    }

    function verifiyHashSignature(bytes32 hash) private view returns (bool) {
        return hash == keccak256(abi.encodePacked(msg.sender, hashedSecret));
    }

    function generateHashSignature(string memory code) public view returns(bytes32) {
        return keccak256(abi.encodePacked(msg.sender, encode(code)));
    }

    function toggleMintPassRequirement() external onlyOwner {
        _use_secret = !_use_secret;
    }

    function mintPassRequired() public view returns(bool) {
        return _use_secret;
    }
}