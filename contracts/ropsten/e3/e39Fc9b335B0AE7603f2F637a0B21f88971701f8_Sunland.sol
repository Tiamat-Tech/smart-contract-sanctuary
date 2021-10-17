// Contract created by Carton and owned by Sunland.
// Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Sunland is ERC721Enumerable, Ownable {
    using Strings for uint256;

    uint256 public price = 1000000000000000000; // Default price of 1 ETH, may change at release date

    string public baseURI = "";

    bool public isSaleActive = false;

    mapping(uint256 => address) private userOwnedTokens;

    mapping(uint256 => string) private _tokenURIs;

    constructor() ERC721("Sunland", "Sunland") {}

    function launch(string memory _base) public onlyOwner {
        baseURI = _base;
        isSaleActive = true;
    }

    function flipSaleStatus() public onlyOwner {
        isSaleActive = !isSaleActive;
    }

    function setPrice(uint256 _newPrice) public onlyOwner {
        price = _newPrice;
    }

    function withdraw(uint256 value) public onlyOwner {
        address payable ownerAdr = payable(msg.sender);
        ownerAdr.transfer(value);
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }

    function mint() public payable {
        require(isSaleActive, "Sunland mintage is not yet enable" );
        require(msg.value >= price, "Insuffisant Eth");

        uint256 newItemId = totalSupply() + 1;

        require(newItemId <= 177, "Exceeds maximum tokens available for purchase");
        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, baseURI);

        userOwnedTokens[newItemId] = msg.sender;
    }

    function tokensByOwner(address _owner) external view returns(uint256[] memory ) {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 index;
            for (index = 0; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }
            return result;
        }
    }

    function getAllOwnerAndToken() public view returns(address[] memory) {
        address[] memory adrs = new address[](totalSupply() + 1);
        address defaut;
        adrs[0] = defaut;
        for (uint i = 1; i <= totalSupply(); i++) {
            adrs[i] = userOwnedTokens[i];
        }
        return adrs;
    }
}