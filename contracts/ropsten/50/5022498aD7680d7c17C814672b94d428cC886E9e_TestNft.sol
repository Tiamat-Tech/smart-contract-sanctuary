//SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "ERC721.sol";
import "ERC721Enumerable.sol";
import "ERC721Burnable.sol";
import "ERC721Pausable.sol";
import "ERC721URIStorage.sol";
import "AccessControlEnumerable.sol";
import "ECDSA.sol";
import "Context.sol";
import "Counters.sol";


interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract TestNft is Context, AccessControlEnumerable, ERC721Enumerable, ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter public _tokenIdTracker;
    using ECDSA for bytes32;

    string private _baseTokenURI;
    uint256 private _price;
    uint256 private _multiPercentage = 23;
    uint256 private _multiNonTransferred;
    uint256 private _max;
    address private _admin;
    address private _signer;
    address private _multiD;
    address private _multiN;
    mapping(uint256 => bool) internal slots;


    event signerChanged(address newSigner);
    event multiDChanged(address newMultiD);
    event multiNChanged(address newMultiN);
    event mintPriceChanged(uint256 newPrice);


    constructor(
        string memory name, string memory symbol, string memory baseTokenURI, uint256 mintPrice, uint256 max,
        address admin, address multiD, address multiN, address signer
    ) ERC721(name, symbol) {
        _baseTokenURI = baseTokenURI;
        _price = mintPrice;
        _max = max;
        _admin = admin;
        _multiD = multiD;
        _multiN = multiN;
        _signer = signer;
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseTokenURI = baseURI;
    }

    function setTokenURI(uint256 tokenId, string memory _tokenURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setTokenURI(tokenId, _tokenURI);
    }

    function setPrice(uint256 mintPrice) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _price = mintPrice;
        emit mintPriceChanged(_price);
    }

    function price() public view returns (uint256) {
        return _price;
    }

    function mint(uint256 amount, uint256 slotId, bytes memory signature) external payable {
        require(_canMint(msg.sender, amount, slotId, signature), "TestNft: must have valid signing");
        require(_tokenIdTracker.current() + amount <= _max, "TestNft: total amount must not be over the max");
        require(amount <= 5, "TestNft: must be less than 5 per transaction");
        require(msg.value >= (amount * _price), "TestNft: Insufficient eth sent");
        require(slots[slotId] == false, "TestNft: Slot already used");


        _log_mint(amount);
        _mintMultiple(msg.sender, amount);
        slots[slotId] = true;
    }

    function fiatBatchMint(address[] memory accounts, uint256[] memory amounts) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(accounts.length == amounts.length, "Incorrect length match for accounts and amounts");

        uint256 totalFiatAmount = 0;

        for (uint256 i = 0; i < amounts.length; i++) {
            totalFiatAmount += amounts[i];
        }

        require((_tokenIdTracker.current() + totalFiatAmount) <= _max, "TestNft: Minting over max total supply");

        for (uint256 i = 0; i < accounts.length; i++) {
            _mintMultiple(accounts[i], amounts[i]);
        }
    }

    function _mintMultiple(address account, uint256 amount) internal {
        require((_tokenIdTracker.current() + amount) <= _max, "TestNft: total amount must not be over the max");

        for (uint256 i = 0; i < amount; i++) {
            _safeMint(account, _tokenIdTracker.current());
            _tokenIdTracker.increment();
        }
    }

    function _log_mint(uint256 amount) internal {
        uint256 totalAmount = amount * _price;
        uint256 share = totalAmount / 100 * _multiPercentage;
        _multiNonTransferred = _multiNonTransferred + share;
    }

    function operateD() external {
        require(_multiD == _msgSender(), "TestNft: Only D operator can run");
        uint256 transferAmount = _multiNonTransferred;
        require(transferAmount > 0, "TestNft: D operation must be greater than 0");
        _multiNonTransferred = 0;
        payable(_multiD).transfer(transferAmount);
    }

    function operateN() external {
        require(_multiN == _msgSender(), "TestNft: Only N operator can run");
        uint256 transferAmount = address(this).balance - _multiNonTransferred;
        require(transferAmount > 0, "TestNft: N operation must be greater than 0");
        payable(_multiN).transfer(transferAmount);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        return ERC721URIStorage._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory){
        return ERC721URIStorage.tokenURI(tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControlEnumerable, ERC721, ERC721Enumerable) returns (bool){
        return super.supportsInterface(interfaceId);
    }

    function changeSigner(address newSigner) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _signer = newSigner;
        emit signerChanged(_signer);
    }

    function changeMultiN(address newMultiN) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _multiN = newMultiN;
        emit multiNChanged(_multiN);
    }

    function changeMultiD(address newMultiD) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _multiD = newMultiD;
        emit multiDChanged(_multiD);
    }

    function _getSigner(bytes32 hash, bytes memory signature) internal pure returns (address){
        return hash.toEthSignedMessageHash().recover(signature);
    }

    function _verifySignature(address minter, uint256 amount, uint256 slotId, bytes memory signature) internal view returns (bool) {
        return _getSigner(keccak256(abi.encodePacked(minter, amount, slotId)), signature) == _signer;
    }

    function _canMint(address minter, uint256 amount, uint256 slotId, bytes memory signature) internal view returns (bool) {
        return  _verifySignature(minter, amount, slotId, signature);
    }

    function rescueERC721(IERC721 tokenToRescue, uint256 n) external onlyRole(DEFAULT_ADMIN_ROLE)  {
        tokenToRescue.safeTransferFrom(address(this), _admin, n);
    }

    function rescueERC20(IERC20 tokenToRescue) external onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenToRescue.transfer(_admin, tokenToRescue.balanceOf(address(this)));
    }

    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        payable(msg.sender).transfer(address(this).balance);
    }
}