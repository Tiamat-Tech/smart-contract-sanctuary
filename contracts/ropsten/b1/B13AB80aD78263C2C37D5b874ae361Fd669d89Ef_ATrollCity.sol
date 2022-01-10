// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract ATrollCity is ERC721Enumerable, ERC721URIStorage, Pausable, Ownable {

    using SafeMath for uint;
    using Strings for uint;
    using Address for address;

    uint public price;
    uint public immutable maxSupply;
    uint public supplyCap;
    bool public mintingEnabled;
    bool public whitelistEnabled = true;
    mapping(address => bool) public whitelist;

    constructor(
        string memory _name, 
        string memory _symbol, 
        uint _maxSupply, 
        uint _supplyCap, 
        uint _price
    ) ERC721(_name, _symbol) {
        maxSupply = _maxSupply;
        supplyCap = _supplyCap;
        price = _price;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function setWhitelist(address[] calldata newAddresses) external onlyOwner {
        for (uint256 i = 0; i < newAddresses.length; i++)
            whitelist[newAddresses[i]] = true;
    }

    function removeWhitelist(address[] calldata currentAddresses) external onlyOwner {
        for (uint256 i = 0; i < currentAddresses.length; i++)
            delete whitelist[currentAddresses[i]];
    }

    function setPrice(uint256 newPrice) external onlyOwner {
        price = newPrice;
    }

    function setSupplyCap(uint256 newSupplyCap) external onlyOwner {
        supplyCap = newSupplyCap;
    }

    function mintNFTs(uint256 quantity) external payable {
        require(totalSupply().add(quantity) <= maxSupply, "Max supply exceeded");
        require(totalSupply().add(quantity) <= supplyCap, "Supply cap exceeded");
        if (_msgSender() != owner()) {
            require(mintingEnabled, "Minting has not been enabled");
            
            if (whitelistEnabled)
                require(whitelist[_msgSender()], "Not whitelisted");
        }
        require(quantity > 0, "Invalid quantity");
        require(price.mul(quantity) == msg.value, "Incorrect ETH value");
        require(!_msgSender().isContract(), "Contracts are not allowed");

        for (uint i = 0; i < quantity; i++) {
            _safeMint(_msgSender(), totalSupply().add(1));
        }
    }

    function safeMint(address to, uint256 tokenId, string memory uri)
        public
        onlyOwner
    {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}