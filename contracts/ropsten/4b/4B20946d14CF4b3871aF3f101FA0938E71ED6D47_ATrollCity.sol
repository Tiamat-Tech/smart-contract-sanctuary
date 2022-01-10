// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract ATrollCity is ERC721Enumerable, Pausable, Ownable {

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
        string memory _name, 
        string memory _symbol, 
        uint _maxSupply, 
        uint _supplyCap, 
        uint _price,
        string memory _uri,
        address _buyBackPool,
        address _lpPool
    ) ERC721(_name, _symbol) {
        maxSupply = _maxSupply;
        supplyCap = _supplyCap;
        price = _price;
        _baseURIPrefix = _uri;
        buyBackPool = _buyBackPool;
        lpPool = _lpPool;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseURIPrefix;
    }

    function setBaseURI(string memory newUri) external onlyOwner {
        _baseURIPrefix = newUri;
    }

    function setWhitelist(address[] calldata newAddresses) external onlyOwner {
        for (uint256 i = 0; i < newAddresses.length; i++)
            whitelist[newAddresses[i]] = true;
    }

    function removeWhitelist(address[] calldata currentAddresses) external onlyOwner {
        for (uint256 i = 0; i < currentAddresses.length; i++)
            delete whitelist[currentAddresses[i]];
    }

    function setPriceAndSupplyCap(uint256 newPrice, uint256 newSupplyCap) external onlyOwner {
        price = newPrice;
        supplyCap = newSupplyCap;
    }

    function mintNFT() external payable returns (uint) {
        require(totalSupply().add(1) <= maxSupply, "Max supply exceeded");
        require(totalSupply().add(1) <= supplyCap, "Supply cap exceeded");
        if (_msgSender() != owner()) {
            require(mintingEnabled, "Minting has not been enabled");
            if (whitelistEnabled)
                require(whitelist[_msgSender()], "Not whitelisted");
        }
        require(price < msg.value, "Insufficient balance");
        require(!_msgSender().isContract(), "Contracts are not allowed");

        uint tokenId = randomTokenId();

        _safeMint(_msgSender(), totalSupply().add(1));
        _initialOwners[tokenId] = msg.sender;
        payable(buyBackPool).transfer((price.mul(7)).div(100));
        payable(lpPool).transfer((price.mul(3)).div(100));
        payable(owner()).transfer((price.mul(85)).div(100));

        return tokenId;
    }

    function randomTokenId() internal virtual returns (uint){
        uint tokenId;
        if(_exists(tokenId) && tokenId < 501) {
            tokenId = tokenId*8 + 7;
        }
        else{
            randomTokenId();
        }
        return tokenId;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        payable(_initialOwners[tokenId]).transfer((msg.value.mul(3)).div(100));
        super._beforeTokenTransfer(from, to, tokenId);
    }
}