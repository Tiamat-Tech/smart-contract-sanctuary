// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./IATrollCity.sol";

contract ATrollCity is ERC721Enumerable, Pausable, Ownable, IATrollCity {

    using SafeMath for uint;
    using Strings for uint;
    using Address for address;

    uint public price;
    uint public immutable maxSupply;
    uint public supplyCap;
    bool public mintingEnabled;
    bool public whitelistEnabled = true;
    address private buyBackPool;
    address private lpPool;
    uint private randomNumber = 1;

    mapping(address => bool) public whitelist;

    mapping(uint256 => address) private _initialOwners;

    string private _baseURIPrefix;

    constructor(
        string memory _tokenName, 
        string memory _tokenSymbol, 
        uint _maxSupply, 
        uint _supplyCap, 
        uint _price,
        string memory _uri,
        address _buyBackPool,
        address _lpPool
    ) ERC721(_tokenName, _tokenSymbol) {
        maxSupply = _maxSupply;
        supplyCap = _supplyCap;
        price = _price;
        _baseURIPrefix = _uri;
        buyBackPool = _buyBackPool;
        lpPool = _lpPool;
        emit Constructed(
            _tokenName,
            _tokenSymbol,
            _maxSupply,
            _supplyCap,
            _price,
            _uri,
            _buyBackPool,
            _lpPool
        );
    }

    function pause() public override onlyOwner {
        _pause();
    }

    function unpause() public override onlyOwner {
        _unpause();
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseURIPrefix;
    }

    function setBaseURI(string memory newUri) external override onlyOwner {
        _baseURIPrefix = newUri;
        emit SetBaseURI(newUri);
    }

    function setWhitelist(address[] calldata newAddresses) external override onlyOwner {
        for (uint256 i = 0; i < newAddresses.length; i++)
            whitelist[newAddresses[i]] = true;
        emit SetWhiteList(newAddresses);
    }

    function removeWhitelist(address[] calldata currentAddresses) external override onlyOwner {
        for (uint256 i = 0; i < currentAddresses.length; i++)
            delete whitelist[currentAddresses[i]];
        emit RemoveWhiteList(currentAddresses);
    }

    function setPriceAndSupplyCap(uint256 newPrice, uint256 newSupplyCap) external override onlyOwner {
        price = newPrice;
        supplyCap = newSupplyCap;
        emit NewPriceAndSupplyCap();
    }

    function mintNFT() external payable override returns (uint) {
        require(totalSupply().add(1) <= maxSupply, "Max supply exceeded");
        require(totalSupply().add(1) <= supplyCap, "Supply cap exceeded");
        if (_msgSender() != owner()) {
            require(mintingEnabled, "Minting has not been enabled");
            if (whitelistEnabled && totalSupply() < 251)
                require(whitelist[_msgSender()], "Not whitelisted");
        }
        require(price < msg.value, "Insufficient balance");
        require(!_msgSender().isContract(), "Contracts are not allowed");

        uint tokenId = randomTokenId();

        _safeMint(_msgSender(), tokenId);
        _initialOwners[tokenId] = msg.sender;
        payable(buyBackPool).transfer((price.mul(7)).div(100));
        payable(lpPool).transfer((price.mul(3)).div(100));
        payable(owner()).transfer((price.mul(85)).div(100));
        emit NewNFT(tokenId);

        return tokenId;
    }

    function randomTokenId() internal virtual returns (uint){
        uint tokenId = randomNumber;
        tokenId = tokenId * 8 + 7;
        if(_exists(tokenId) || tokenId > 5001) {
            tokenId = tokenId.div(500);
            randomNumber = tokenId;
            randomTokenId();
        }
        return tokenId;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        if(_exists(tokenId))
            payable(_initialOwners[tokenId]).transfer((msg.value.mul(3)).div(100));
        super._beforeTokenTransfer(from, to, tokenId);
    }
}