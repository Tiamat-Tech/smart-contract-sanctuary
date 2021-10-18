// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Minter is Ownable, PaymentSplitter, ERC721Enumerable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    string private _apiURI = "";
    uint256 public _maxSupply = 1337;
    uint256 public _maxAmountToMint = 5;
    bool public isMintingAllowed = false;

    uint256[] private _shares = [40, 30, 30];
    address[] private _shareholders = [
        0x92A192adbE4fBd70FF515A85fE86dEf0EB1B2c60,
        0x5DFF7F738038c138F69b64d20d516D0aec635Cc7,
        0x2543DAb2634940860B2dc1749f2de16b68b61D4D
    ];

    modifier mintingAllowed() {
        require(isMintingAllowed, "Minting not allowed");
        _;
    }

    modifier onlyEOA() {
        require(msg.sender == tx.origin, "Must use EOA");
        _;
    }

    modifier limitTokens(uint256 _amountToMint) {
        require(_amountToMint <= _maxAmountToMint, "Too many tokens at once");
        _;
    }

    modifier limitSupply(uint256 _amountToMint) {
        require(
            _maxSupply >= _tokenIds.current().add(_amountToMint),
            "The purchase would exceed max tokens supply"
        );
        _;
    }

    constructor()
        PaymentSplitter(_shareholders, _shares)
        ERC721("Strangers", "STRG")
    {}

    function _mintMultiple(uint256 _amountToMint) private {
        for (uint256 i = 0; i < _amountToMint; i++) {
            _tokenIds.increment();
            _safeMint(msg.sender, _tokenIds.current());
        }
    }

    function mintMultiple(uint256 _amountToMint)
        public
        payable
        onlyEOA
        mintingAllowed
        limitSupply(_amountToMint)
        limitTokens(_amountToMint)
    {
        _mintMultiple(_amountToMint);
    }

    function _baseURI() internal view override returns (string memory) {
        return _apiURI;
    }

    function setBaseURI(string memory _uri) public onlyOwner {
        _apiURI = _uri;
    }

    function toggleMintingStatus() public onlyOwner {
        isMintingAllowed = !isMintingAllowed;
    }

    function setMaxAmountToMint(uint256 maxAmountToMint) public onlyOwner {
        _maxAmountToMint = maxAmountToMint;
    }

    function setMaxSupply(uint256 _supply) public onlyOwner {
        _maxSupply = _supply;
    }

    /**
        @dev Transfer balance money to shareholders based on number of shares
     */
    function releaseAll() public onlyOwner {
        for (uint256 sh = 0; sh < _shareholders.length; sh++) {
            address payable wallet = payable(_shareholders[sh]);
            release(wallet);
        }
    }
}