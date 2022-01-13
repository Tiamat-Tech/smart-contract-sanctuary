// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BlackPunksMatterNFT is ERC721Enumerable, Ownable {
    using Strings for uint256;

    string public baseURI;
    string public baseExtension = ".json";
    uint256 public cost = .069 ether;
    uint256 public maxSupply = 4200;
    uint256 public maxAmountPerMint = 4;
    uint256 public maxMintPerAddress = 10;
    bool public publicEnabled = true;
    mapping(address => uint256) public addressMintCount;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI
    ) ERC721(_name, _symbol) {
        setBaseURI(_initBaseURI);
        mint(msg.sender, 10);
    }

    // internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    // public sale
    function mint(address _to, uint256 _mintAmount) public payable {
        uint256 supply = totalSupply();
        require(publicEnabled || msg.sender == owner());
        require(_mintAmount > 0);
        require(supply + _mintAmount <= maxSupply);

        if (msg.sender != owner()) {
            require(_mintAmount <= maxAmountPerMint);
            require((addressMintCount[_to] + _mintAmount) <= maxMintPerAddress);
            require(msg.value >= cost * _mintAmount);
        }

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(_to, supply + i);
        }
        addressMintCount[_to] = (addressMintCount[_to] + _mintAmount);
    }

    // public methods
    function walletOfOwner(address _owner) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }

    //only owner
    function setCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
    }

    function setMaxAmountPerMint(uint256 _newMaxAmountPerMint) public onlyOwner {
        maxAmountPerMint = _newMaxAmountPerMint;
    }

    function setMaxMintPerAddress(uint256 _newMaxMintPerAddress) public onlyOwner {
        maxMintPerAddress = _newMaxMintPerAddress;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
        baseExtension = _newBaseExtension;
    }

    function setPublicEnabled(bool _state) public onlyOwner {
        publicEnabled = _state;
    }

    function withdraw() public payable onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }
}