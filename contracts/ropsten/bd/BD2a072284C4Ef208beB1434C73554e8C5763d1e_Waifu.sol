//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Waifu is ERC721Enumerable, Ownable {
    using Strings for uint256;

    string baseURI;
    string public baseExtension = ".json";
    string public notRevealedUri;

    uint256 public cost = 0.06969 ether;
    uint256 public whitelistCost = 0.05 ether;
    uint256 public maxSupply = 6969;
    uint256 public maxMintAmount = 20;
    uint256 public maxWhitelistAmount = 3;

    bool public paused = true;
    bool public revealed = false;
    bool public onlyWhitelisted = true;

    address[] public whitelistedAddresses;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI,
        string memory _initNotRevealedUri
    ) ERC721(_name, _symbol) {
        setBaseURI(_initBaseURI);
        setNotRevealedURI(_initNotRevealedUri);
    }

    // internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    // public
    function mint(uint256 _mintAmount) public payable {
        require(!paused, "Minting is not open yet");
        uint256 supply = totalSupply();
        require(_mintAmount > 0, "Must mint atleast 1");
        require(_mintAmount <= maxMintAmount, "Mint amount too high");
        require(supply + _mintAmount <= maxSupply, "Max supply reached");

        uint256 actualCost = onlyWhitelisted ? whitelistCost : cost;

        if (msg.sender != owner()) {
            uint256 ownerTokenCount = balanceOf(msg.sender);
            if (onlyWhitelisted) {
                require(
                    isWhitelisted(msg.sender),
                    "Address is not whitelisted"
                );
                require(
                    ownerTokenCount + _mintAmount <= maxWhitelistAmount,
                    "The transaction succeeds the max amount"
                );
            } else {
                require(
                    ownerTokenCount + _mintAmount <= maxMintAmount,
                    "Sender has reached max amount"
                );
            }
            require(
                msg.value == actualCost * _mintAmount,
                "Sent insufficent funds"
            );
            for (uint256 i = 1; i <= _mintAmount; i++) {
                _safeMint(msg.sender, supply + i);
            }
        }
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

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (revealed == false) {
            return notRevealedUri;
        }

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

    function mintOwner() public onlyOwner {
        uint256 supply = totalSupply();
        for (uint i = 1; i <= 20; i++) {
            _safeMint(msg.sender, supply + i);
        }

    }

    //only owner
    function reveal() public onlyOwner {
        revealed = true;
    }

    function setCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
    }

    function setMaxWhitlistAmount(uint256 _newMaxAmount) public onlyOwner {
        maxWhitelistAmount = _newMaxAmount;
    }

    function setOnlyWhitelist(bool _state) public onlyOwner {
        onlyWhitelisted = _state;
    }

    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
        maxMintAmount = _newmaxMintAmount;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(string memory _newBaseExtension)
        public
        onlyOwner
    {
        baseExtension = _newBaseExtension;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function withdraw() public payable onlyOwner {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }

    function whitelistUser(address user) public onlyOwner {
        whitelistedAddresses.push(user);
    }

    function whitelistUsers(address[] calldata _addresses) public onlyOwner {
        delete whitelistedAddresses;
        whitelistedAddresses = _addresses;
    }

    function isWhitelisted(address _address) public view returns (bool) {
        for (uint256 i = 0; i < whitelistedAddresses.length; i++) {
            if (whitelistedAddresses[i] == _address) {
                return true;
            }
        }
        return false;
    }
}