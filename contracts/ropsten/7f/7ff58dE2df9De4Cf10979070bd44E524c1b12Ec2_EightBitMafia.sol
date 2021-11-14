// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EightBitMafia is ERC721Enumerable, Ownable {
    using Strings for uint256;

    string public baseURI;
    string public baseExtension = ".json";
    string public notRevealedUri;

    uint256 public cost = 0.055 ether;
    uint256 public bulkCost = 0.047 ether;
    uint256 public maxSupply = 8888;
    uint256 public initialSupply = 4444;
    uint256 public maxMintAmount = 6;

    bool public supplyReleased = false;
    bool public paused = true;
    bool public revealed = false;
    bool public contractBurned = false;

    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
    {}

    // internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function initialMint() public onlyOwner {
        _safeMint(msg.sender, 1);
        _safeMint(msg.sender, 2);
        _safeMint(msg.sender, 3);
        _safeMint(msg.sender, 4);
        _safeMint(msg.sender, 5);
        _safeMint(msg.sender, 6);
        _safeMint(msg.sender, 7);
        _safeMint(msg.sender, 8);
        _safeMint(msg.sender, 9);
        _safeMint(msg.sender, 10);
        _safeMint(msg.sender, 11);
        _safeMint(msg.sender, 12);
        _safeMint(msg.sender, 13);
        _safeMint(msg.sender, 14);
        _safeMint(msg.sender, 15);
        _safeMint(msg.sender, 16);
        _safeMint(msg.sender, 17);
        _safeMint(msg.sender, 18);
        _safeMint(msg.sender, 19);
        _safeMint(msg.sender, 20);
    }

    function secondMint() public onlyOwner {
        _safeMint(msg.sender, 21);
        _safeMint(msg.sender, 22);
        _safeMint(msg.sender, 23);
        _safeMint(msg.sender, 24);
        _safeMint(msg.sender, 25);
        _safeMint(msg.sender, 26);
        _safeMint(msg.sender, 27);
        _safeMint(msg.sender, 28);
        _safeMint(msg.sender, 29);
        _safeMint(msg.sender, 30);
        _safeMint(msg.sender, 31);
        _safeMint(msg.sender, 32);
        _safeMint(msg.sender, 33);
        _safeMint(msg.sender, 34);
        _safeMint(msg.sender, 35);
    }

    function thirdMint() public onlyOwner {
        _safeMint(msg.sender, 36);
        _safeMint(msg.sender, 37);
        _safeMint(msg.sender, 38);
        _safeMint(msg.sender, 39);
        _safeMint(msg.sender, 40);
        _safeMint(msg.sender, 41);
        _safeMint(msg.sender, 42);
        _safeMint(msg.sender, 43);
        _safeMint(msg.sender, 44);
        _safeMint(msg.sender, 45);
        _safeMint(msg.sender, 46);
        _safeMint(msg.sender, 47);
        _safeMint(msg.sender, 48);
        _safeMint(msg.sender, 49);
        _safeMint(msg.sender, 50);
    }

    function fourthMint() public onlyOwner {
        _safeMint(msg.sender, 51);
        _safeMint(msg.sender, 52);
        _safeMint(msg.sender, 53);
        _safeMint(msg.sender, 54);
        _safeMint(msg.sender, 55);
        _safeMint(msg.sender, 56);
        _safeMint(msg.sender, 57);
        _safeMint(msg.sender, 58);
        _safeMint(msg.sender, 59);
        _safeMint(msg.sender, 60);
        _safeMint(msg.sender, 61);
        _safeMint(msg.sender, 62);
        _safeMint(msg.sender, 63);
        _safeMint(msg.sender, 64);
        _safeMint(msg.sender, 65);
        _safeMint(msg.sender, 66);
        _safeMint(msg.sender, 67);
        _safeMint(msg.sender, 68);
        _safeMint(msg.sender, 69);
        _safeMint(msg.sender, 70);
    }

    // public
    function mint(address _to, uint256 _mintAmount) public payable {
        uint256 supply = totalSupply();
        uint256 currentMaxSupply = supplyReleased ? maxSupply : initialSupply;

        require(!contractBurned); //This makes it impossible to mint extra EBM tokens, ever.
        require(!paused); //Toggle to make sure nobody mints outside of our WhitelistPeriods
        require(_mintAmount > 0);
        require(supply + _mintAmount <= currentMaxSupply);

        if (_mintAmount >= 3) {
            require(msg.value >= bulkCost * _mintAmount);
        } else {
            require(msg.value >= cost * _mintAmount);
        }

        require(_mintAmount <= maxMintAmount);

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(_to, supply + i);
        }
    }

    function make4DigitStringFromInt(uint256 tokenId)
        public
        pure
        returns (string memory)
    {
        if (tokenId >= 1000)
            return string(abi.encodePacked(tokenId.toString()));

        if (tokenId >= 100)
            return string(abi.encodePacked("0", tokenId.toString()));

        if (tokenId >= 10)
            return string(abi.encodePacked("00", tokenId.toString()));

        return string(abi.encodePacked("000", tokenId.toString()));
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
                        make4DigitStringFromInt(tokenId),
                        baseExtension
                    )
                )
                : "";
    }

    //only owner
    function reveal() public onlyOwner {
        revealed = true;
    }

    function releaseExtraSupply() public onlyOwner {
        supplyReleased = true;
    }

    function burnContract() public onlyOwner {
        contractBurned = true;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function withdraw() public payable onlyOwner {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }

    function burn(uint256 tokenId) public virtual {
        //solhint-disable-next-line max-line-length
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721Burnable: caller is not owner nor approved"
        );
        _burn(tokenId);
    }
}