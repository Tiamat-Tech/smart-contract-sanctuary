// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC721.sol";

contract Alt721 is ERC721, Ownable {
    address public rootNft;
    uint public price;
    string public baseUri;
    mapping(uint => bool) public unlocked;

    constructor(
        address _rootNft,
        string memory _name,
        string memory _symbol,
        uint _price,
        string memory _baseUri
    ) ERC721(_name, _symbol){
        // store original contract
        rootNft = _rootNft;
        price = _price;
        baseUri = _baseUri;
    }

    function mint(uint tokenId) payable public {
        // only owner of original
        require(IERC721(rootNft).ownerOf(tokenId) == msg.sender, "Only root NFT owner can mint");
        require(msg.value >= price, "Not enough payment for mint");
        // safeMint
        super._safeMint(msg.sender, tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address,
        uint256 tokenId
    ) internal override view {
        // check that we handle burn correctly
        if (from == address(0)) {
            return;
        }
        require(unlocked[tokenId], "Can not transfer locked token");
    }

    function unlock(uint tokenId) public {
        require(IERC721(rootNft).ownerOf(tokenId) == msg.sender, "Only owner can unlock");
        unlocked[tokenId] = true;
        _owners[tokenId] = msg.sender;
    }

    function lock(uint tokenId) public {
        require(Alt721.ownerOf(tokenId) == IERC721(rootNft).ownerOf(tokenId), "Must own root and alt to lock");
        require(IERC721(rootNft).ownerOf(tokenId) == msg.sender, "Only owner can lock");
        unlocked[tokenId] = false;
    }

    function ownerOf(uint tokenId) public view override returns (address){
        if(!unlocked[tokenId]) {
            return IERC721(rootNft).ownerOf(tokenId);
        }
        return _owners[tokenId];
    }

    function withdraw() onlyOwner() public {
        payable(owner()).transfer(address(this).balance);
    }

    function updatePrice(uint _price) onlyOwner()  public {
        price = _price;
    }

    function updateBaseUri(string memory _baseUri) onlyOwner() public {
        baseUri = _baseUri;
    }
}