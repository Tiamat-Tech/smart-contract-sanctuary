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
        mint(msg.sender, 50);
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