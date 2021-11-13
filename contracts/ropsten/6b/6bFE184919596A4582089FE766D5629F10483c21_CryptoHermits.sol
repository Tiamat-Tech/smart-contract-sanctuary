// SPDX-License-Identifier: GPL-3.0

// Created by HashLips
// The Nerdy Coder Clones

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CryptoHermits is ERC721Enumerable, Ownable {
    using Strings for uint256;

    // baseURI for example: https://cryptohermitsnft.com/
    string public baseURI;
    // set baseExtension to .json
    // you need this since ipfs is adding it when ipfs is hosting the NFT json
    // https://gateway.pinata.cloud/ipfs/QmYrVgtkHnXDw9KURzgSbmejgzpEcje6FV5AofEmBx98kz/1.json
    string public baseExtension = ".json";
    // cost for each nft
    uint256 public cost = 0.01 ether;
    // max supply of NFT tokens
    uint256 public maxSupply = 1000;
    // max amount a wallet can mint
    uint256 public maxMintAmount = 3;
    // paused boolean for pausing the smart contract
    bool public paused = false;

    event printNewTokenId(uint256 _newTokenId);

    constructor(string memory _name, string memory _symbol, string memory _initBaseURI) ERC721(_name, _symbol) {
        mint(5);
        setBaseURI(_initBaseURI);
    }

    // internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    // public
    function mint(uint256 _mintAmount) public payable {
        uint256 supply = totalSupply();
        // contract cannot be paused
        require(!paused, "Contract cannot be paused.");
        // mint amount greater then 0
        require(_mintAmount > 0, "Mint amount has to be greater then 0.");
        // current supply + mintAmount has to be less then maxSupply
        require(supply + _mintAmount <= maxSupply, "The current supply plus your mint amount has to be less then or equal to the max supply.");

        // if msg.sender is not the owner
        if (msg.sender != owner()) {
            // the balance of the sender plus the amount they want to mint has to be less then the max mint amount
            require(balanceOf(msg.sender) + _mintAmount <= maxMintAmount, "You can only purchase 3 tokens");
            // charge them
            require(msg.value >= cost * _mintAmount);
        }

        // supply starts at 0 and goes up by 1 each time
        // i starts at 1 for each minting round
        // for example, if the first buyer only bought 1, it would be supply(0) + i(1) = 1 --> 1 for the token tokenId
        // next round, the buyer buys 2, it would be supply(1) + i(1) && supply(1) + i(2) --> 2 and 3 for the tokenIds
        for (uint256 i = 1; i <= _mintAmount; i++) {
            uint256 newTokenId = supply + i;
            _safeMint(msg.sender, newTokenId);
            emit printNewTokenId(newTokenId);
        }
    }

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
        return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension)): "";
    }

    function renounceOwnership() public override pure {
        revert("Can't renounce ownership here");
    }

    // only owner
    function setCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
    }

    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
        maxMintAmount = _newmaxMintAmount;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
        baseExtension = _newBaseExtension;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function getBalance() public view onlyOwner returns (uint) {
        return address(this).balance;
    }

    function withdraw() public payable onlyOwner {
        payable(owner()).transfer(getBalance());
    }
}