//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Waifu is ERC721, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private supply;
    
    string public uriPrefix = "";
    string public uriSuffix = ".json";
    string public hiddenMetadataUri;

    uint256 public cost = 0.02 ether;
    uint256 public whitelistCost = 0.01 ether;
    uint256 public maxSupply = 6969;
    uint256 public maxMintAmountPerTx = 20;
    uint256 public maxWhitelistAmount = 3;
    uint256 private ownerMinted = 0;

    bool public paused = true;
    bool public revealed = false;
    bool public onlyWhitelisted = true;
    
    mapping(address => bool) whitelistedAddresses;

    address private a1 = 0x943405d0d429C865affcC487270A1cFE3a6B9A71;
    address private a2 = 0x38482Dc0050Dc32c66e41b9D5ae8b7383EC3bb49;
    address private a3 = 0xE9Cd9e74dA2c357B3A0423a06a33d5157B7280AE;

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
        setHiddenMetadataUri("ipfs://__CID__/hidden.json");
    }


    modifier mintCompliance(uint256 _mintAmount) {
        uint256 actualMaxMintAmount = onlyWhitelisted ? maxWhitelistAmount : maxMintAmountPerTx;
        require(_mintAmount > 0 && _mintAmount <= actualMaxMintAmount, "Invalid mint amount!");
        require(supply.current() + _mintAmount <= maxSupply, "Max supply exceeded!");
        _;
    }

    function totalSupply() public view returns (uint256) {
        return supply.current();
    }

    function mint(uint256 _mintAmount) public payable mintCompliance(_mintAmount) {
        require(!paused, "Minting is not live yet");
        if (onlyWhitelisted) {
            require(isWhitelisted(msg.sender), "Address is not whitelisted");
        }
        uint256 actualCost = onlyWhitelisted ? whitelistCost : cost;
        require(msg.value >= actualCost * _mintAmount, "Insufficient funds!");

        _mintLoop(msg.sender, _mintAmount);
    }
  
    function mintForAddress(uint256 _mintAmount, address _receiver) public onlyOwner {
        _mintLoop(_receiver, _mintAmount);
    }

    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
        uint256 currentTokenId = 1;
        uint256 ownedTokenIndex = 0;

        while (ownedTokenIndex < ownerTokenCount && currentTokenId <= maxSupply) {
        address currentTokenOwner = ownerOf(currentTokenId);

        if (currentTokenOwner == _owner) {
            ownedTokenIds[ownedTokenIndex] = currentTokenId;

            ownedTokenIndex++;
        }

        currentTokenId++;
        }

        return ownedTokenIds;
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
        _exists(_tokenId),
        "ERC721Metadata: URI query for nonexistent token"
        );

        if (revealed == false) {
            return hiddenMetadataUri;
        }

        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0
            ? string(abi.encodePacked(currentBaseURI, _tokenId.toString(), uriSuffix))
            : "";
    }

    //only owner
    function setRevealed(bool _state) public onlyOwner {
        revealed = _state;
    }

    function setCost(uint256 _cost) public onlyOwner {
        cost = _cost;
    }

    function setMaxMintAmountPerTx(uint256 _maxMintAmountPerTx) public onlyOwner {
        maxMintAmountPerTx = _maxMintAmountPerTx;
    }

    function setHiddenMetadataUri(string memory _hiddenMetadataUri) public onlyOwner {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    function setUriPrefix(string memory _uriPrefix) public onlyOwner {
        uriPrefix = _uriPrefix;
    }

    function setUriSuffix(string memory _uriSuffix) public onlyOwner {
        uriSuffix = _uriSuffix;
    }

    function setPaused(bool _state) public onlyOwner {
        paused = _state;
    }

    function setMaxWhitlistAmount(uint256 _newMaxAmount) public onlyOwner {
        maxWhitelistAmount = _newMaxAmount;
    }

    function setOnlyWhitelist(bool _state) public onlyOwner {
        onlyWhitelisted = _state;
    }

    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
        maxMintAmountPerTx = _newmaxMintAmount;
    }

    function withdraw() public payable onlyOwner {
        (bool hs, ) = payable(a1).call{value: address(this).balance * 5500 / 10000}("");
        require(hs);
        (bool os, ) = payable(a2).call{value: address(this).balance * 2250 / 10000}("");
        require(os);
        (bool ls, ) = payable(a3).call{value: address(this).balance * 2250 / 10000}("");
        require(ls);
    }

    function whitelistUser(address _address) public onlyOwner {
        whitelistedAddresses[_address] = true;
    }

    function whitelistUsers(address[] calldata _addresses) public onlyOwner {
        for (uint256 i = 0; i < _addresses.length - 1; i++) {
            whitelistedAddresses[_addresses[i]] = true;
        }
    }

    function isWhitelisted(address _address) public view returns (bool) {
        return whitelistedAddresses[_address];
    }

    function _mintLoop(address _receiver, uint256 _mintAmount) internal {
        for (uint256 i = 0; i < _mintAmount; i++) {
        supply.increment();
        _safeMint(_receiver, supply.current());
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return uriPrefix;
    }
}