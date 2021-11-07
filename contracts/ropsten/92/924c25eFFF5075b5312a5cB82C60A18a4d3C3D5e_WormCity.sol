// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../@openzeppelin/contracts/access/Ownable.sol";
import "../@openzeppelin/contracts/utils/Counters.sol";
import "../@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../traits/Presale.sol";

contract WormCity is ERC721, ERC721Enumerable, Presale, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _wormId;

    event Minted(address account, uint256 amount);
    event MayorMinted(address account);
    event MintedOnPresale(address account, uint256 amount);
    event MintedReserved(address account, uint256 amount);

    uint256 public wormPrice = 80000000000000000; // 0.08 ETH
    uint256 public constant maxWormsForPurchase = 30;
    uint256 public constant maxWormsForWhitelistedPurchase = 10;
    uint256 public constant maxWormsForWhitelistedAccount = 10;
    uint256 public constant MAX_WORMS = 11110;
    uint256 public RESERVED_WORMS = 0;
    uint256 public RESERVED_MINTED = 0;
    uint256 public MAYOR_ID = 11111;

    constructor() ERC721("TestContract", "TSTC") {}

    function _baseURI() internal pure override returns (string memory) {
        return "https://example.com/metadata/";
    }

    function mintMayor(address account) public onlyOwner {
        _safeMint(account, MAYOR_ID);

        emit MayorMinted(account);
    }

    function mayorOwner() public whenMayorMinted view virtual returns (address) {
        return ownerOf(MAYOR_ID);
    }

    function mayorMinted() public view virtual returns (bool) {
        return _exists(MAYOR_ID);
    }

    modifier whenMayorMinted() {
        require(mayorMinted(), "Mayor is not minted");
        _;
    }

    function startPresale() public onlyOwner {
        _startPresale();
    }

    function stopPresale() public onlyOwner {
        _stopPresale();
    }

    function startSale() public onlyOwner {
        _startSale();
    }

    function stopSale() public onlyOwner {
        _stopSale();
    }

    function fromPresaleToSale() public onlyOwner {
        stopPresale();
        startSale();
    }

    function whitelist(address account) public onlyOwner {
        _whitelist(account);
    }

    function removeFromWhitelist(address account) public onlyOwner {
        _removeFromWhitelist(account);
    }

    function safeMint(address to, uint256 amount) public onlyOwner {
        uint256 i;
        for (i = 0; i < amount; i++) {
            _safeMint(to, _wormId.current());
            _wormId.increment();
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function reserve(uint256 amount) public onlyOwner {
        require(amount < MAX_WORMS, "Cannot reserve more than total supply");

        RESERVED_WORMS = amount;
    }

    function getReservedAmount() public view returns (uint256) {
        return RESERVED_WORMS;
    }

    function getMintedReservedAmount() public view returns (uint256) {
        return RESERVED_MINTED;
    }

    function mintReserved(uint256 amount, address to) public onlyOwner {
        require(
            RESERVED_MINTED.add(amount) <= RESERVED_WORMS,
            "Minting would exceed max supply of reserved worms"
        );

        RESERVED_MINTED += amount;

        _mintMultiple(amount, to);

        emit MintedReserved(to, amount);
    }

    function presale(uint256 amount) public payable whenPresaleStarted whenWhitelisted {
        require(
            totalSupply().add(amount) <= MAX_WORMS - RESERVED_WORMS,
            "Purchase would exceed max supply of Worms"
        );

        require(
            amount <= maxWormsForWhitelistedPurchase,
            "Only 10 tokens could be minted at a time"
        );

        require(
            balanceOf(_msgSender()).add(amount) <= maxWormsForWhitelistedAccount,
            "Only 10 tokens could be minted for whitelisted account"
        );

        _mintPayedMultiple(amount);

        emit MintedOnPresale(_msgSender(), amount);
    }

    function mint(uint256 amount) public payable whenSaleStarted {
        require(
            amount <= maxWormsForPurchase,
            "Can mint only 30 worms at a time"
        );

        require(
            totalSupply().add(amount) <= MAX_WORMS - RESERVED_WORMS,
            "Purchase would exceed max supply of Worms"
        );

        _mintPayedMultiple(amount);

        emit Minted(_msgSender(), amount);
    }

    function _mintPayedMultiple(uint256 amount) internal {
        require(
            wormPrice.mul(amount) <= msg.value,
            "Ether value sent is not correct"
        );

        _mintMultiple(amount, _msgSender());
    }

    function _mintMultiple(uint256 amount, address to) internal {
        uint256 mintIndex = totalSupply();
        uint256 i;
        for (i = 0; i < amount; i++) {
            if (mintIndex + i < MAX_WORMS) {
                _safeMint(to, _wormId.current());

                _wormId.increment();
            }
        }
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;

        payable(owner()).transfer(balance);
    }

    /*
     * Only for test purposes
     */
    function destroySmartContract() public onlyOwner {
        selfdestruct(payable(owner()));
    }
}