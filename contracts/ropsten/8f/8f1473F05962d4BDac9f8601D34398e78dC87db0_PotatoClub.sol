//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract PotatoClub is ERC721Enumerable, ERC721Burnable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 public constant maxSupply = 10000;
    uint256 public price = 0.001 * 10**18; // 10^18 is 1 ETH
    uint256 public maxMintAmount = 20;
    // uint256 public constant reveal_timestamp = 1627588800; // Thu Jul 29 2021 20:00:00 GMT+0000
    string public baseTokenURI;
    bool public paused = true;

    // constructor() ERC721("PotatoClub", "PC") {
    //     // setBaseURI(baseURI);
    // }

    constructor(string memory baseURI) ERC721("PotatoClub", "PC") {
        setBaseURI(baseURI);
    }

    function mint(address _to, uint256 _count) public payable {
        uint256 total = _tokenIds.current();
        require(!paused);
        require(_count > 0);
        require(_count <= maxMintAmount, "Exceeds mint number");
        require(total + _count <= maxSupply, "Max limit");
        require(total <= maxSupply, "Sale end");
        require(msg.value >= price * _count, "Value below price");
        // if (msg.sender != owner()) {
        //     require(msg.value >= price * _count, "Value below price");
        // }

        for (uint256 i = 0; i < _count; i++) {
            uint256 id = _tokenIds.current();
            _tokenIds.increment();
            _safeMint(_to, id);
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    // Only Owner
    function setCost(uint256 _newCost) public onlyOwner {
        price = _newCost;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseTokenURI = _newBaseURI;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function withdraw() public payable onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}