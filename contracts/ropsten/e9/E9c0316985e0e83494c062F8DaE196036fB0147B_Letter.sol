// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./RandomlyAssigned.sol";

contract Letter is ERC721, Ownable, RandomlyAssigned {
    using Strings for uint256;

    string private baseURI;
    string public notRevealedURI;
    string public baseExtension = ".json";
    uint256 public presaleStart;
    uint256 public saleStart;
    uint256 public cost = .01 ether;
    uint256 public maxMintAmount = 10;
    bool public paused = false;
    bool public revealed = false;

    mapping(address => bool) public whitelisted;

    constructor(
        uint256 _presaleStart,
        uint256 _saleStart
    ) ERC721("The Letter Collection", "TLNFT")
    RandomlyAssigned(30, 1)
    {
        setPresaleStart(_presaleStart);
        setSaleStart(_saleStart);
    }

    // internal
    function _baseURI() internal view virtual override returns (string memory) {

        return baseURI;
    }

    function _mintToken() internal {
        require(msg.value >= cost, "Not enough ether sent!");

        uint256 id = nextToken();
        _safeMint(msg.sender, id);
    }

    function _mintTokenByOwner() internal {
        uint256 id = nextToken();
        _safeMint(msg.sender, id);
    }

    // public
    function isSale() public view returns (bool) {
        return (block.timestamp > saleStart);
    }

    function isPresale() public view returns (bool) {
        return (block.timestamp > presaleStart && block.timestamp < saleStart);
    }

    function mint() public payable {
        require(!paused, "Contract is paused!");

        if(msg.sender != owner()){
            if(isPresale()){
                require(whitelisted[msg.sender], "User not in presale whitelist!");
                _mintToken();
            } else if(isSale()) {
                _mintToken();
            } else {
                require(isPresale(), "Presale has not yet started!");
            }
        } else {
            _mintTokenByOwner();
        }
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory)
    {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        if(revealed == false) {
            return notRevealedURI;
        }

        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
        : "";
    }

    //only owner
    function setPresaleStart(uint256 _presaleStart) public onlyOwner() {
        presaleStart = _presaleStart;
    }

    function setSaleStart(uint256 _saleStart) public onlyOwner() {
        saleStart = _saleStart;
    }

    function reveal() public onlyOwner() {
        revealed = true;
    }

    function setCost(uint256 _newCost) public onlyOwner() {
        cost = _newCost;
    }

    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner() {
        maxMintAmount = _newmaxMintAmount;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedURI = _notRevealedURI;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function setWhitelistedUsers(address[] memory _users) public onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            require(_users[i] != address(0), "Null address");
            require(!whitelisted[_users[i]], "Duplicate entry");
            whitelisted[_users[i]] = true;
        }
    }

    function removeWhitelistUser(address[] memory _users) public onlyOwner {
        for(uint256 i = 0; i < _users.length; i++){
            require(_users[i] != address(0), "Null address");
            whitelisted[_users[i]] = false;
        }
    }

    function withdraw() public payable onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }
}