// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MintPass is ERC721, ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    uint256 public maxTokenSupply;
    uint256 public mintPrice = 69000000 gwei;
    bool public saleIsActive = false;

    string public baseURI;
    mapping(address => bool) private _minters;

    constructor(
        string memory name,
        string memory symbol,
        uint256 maxMintPassSupply
    ) ERC721(name, symbol) {
        maxTokenSupply = maxMintPassSupply;
    }

    function setMaxTokenSupply(uint256 maxMintPassSupply) public onlyOwner {
        maxTokenSupply = maxMintPassSupply;
    }

    function setMintPrice(uint256 newPrice) public onlyOwner {
        mintPrice = newPrice;
    }

    // TODO WITHDRAW FUNCTION

    function reserveMint(uint256 reservedAmount) public onlyOwner {
        uint256 supply = _tokenIdCounter.current();
        for (uint256 i = 1; i <= reservedAmount; i++) {
            _safeMint(msg.sender, supply + i);
            _tokenIdCounter.increment();
        }
    }

    function reserveMint(uint256 reservedAmount, address mintAddress)
        public
        onlyOwner
    {
        uint256 supply = _tokenIdCounter.current();
        for (uint256 i = 1; i <= reservedAmount; i++) {
            _safeMint(mintAddress, supply + i);
            _tokenIdCounter.increment();
        }
    }

    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }

    function canMint(address owner) public view returns (bool) {
        return !_minters[owner];
    }

    function mintTicket() public payable {
        require(saleIsActive, "Sale is closed.");
        require(
            _tokenIdCounter.current() + 1 <= maxTokenSupply,
            "Purchase would exceed max supply."
        );
        require(mintPrice <= msg.value, "Incorrect funds sent");
        require(!_minters[msg.sender], "You can only mint 1 ticket per wallet");

        _minters[msg.sender] = true;
        _safeMint(msg.sender, _tokenIdCounter.current() + 1);
        _tokenIdCounter.increment();
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory newBaseURI) public onlyOwner {
        baseURI = newBaseURI;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
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

    // function burn(uint256 tokenId) external {
    //     //solhint-disable-next-line max-line-length
    //     require(_isApprovedOrOwner(tx.origin, tokenId) && msg.sender == _torContractAddress, "Caller is not owner nor approved");
    //     _burn(tokenId);
    // }
}