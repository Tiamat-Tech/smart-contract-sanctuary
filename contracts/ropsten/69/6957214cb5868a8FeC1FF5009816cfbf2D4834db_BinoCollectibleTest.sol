// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract BinoCollectibleTest is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    Ownable
{
    string public baseURI =
        "https://gateway.pinata.cloud/ipfs/QmVPSxxd55RuJfQrWgzksm3j7eEweSignpHJqNPzTww9s2/";
    uint256 public cost = 0.02 ether;
    uint256 public maxSupply = 10000;
    uint256 public maxMintAmount = 1;
    bool public salePaused = false;
    bool public publicSaleStarted = true;

    bytes32 public whitelistHashRoot;

    constructor() ERC721("Binotest", "BINOTEST") {}

    // override
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
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

    // internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    // public
    function mint(uint256 _mintAmount, bytes32[] memory _proof) public payable {
        uint256 supply = totalSupply();
        require(!salePaused, "Sale not start");
        require(_mintAmount > 0, "Mint Amount should > 0");
        require(_mintAmount <= maxMintAmount, "Max mint amount exceeded");
        require(supply + _mintAmount <= maxSupply, "Max supply exceeded");
        require(msg.value >= cost * _mintAmount, "Insufficient Balance");

        if (msg.sender != owner()) {
            if (publicSaleStarted != true) {
                require(
                    MerkleProof.verify(
                        _proof,
                        whitelistHashRoot,
                        keccak256(abi.encodePacked(msg.sender))
                    ),
                    "Not on whitelist"
                );
            }
        }

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(msg.sender, supply + i);
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

    function getCost() public view returns (uint256) {
        return cost;
    }

    //only owner
    function setCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function pause(bool _state) public onlyOwner {
        salePaused = _state;
    }

    function setWhitelistRoot(bytes32[] memory _root) public onlyOwner {
        whitelistHashRoot = _root[0];
    }

    function withdraw() public payable onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }
}