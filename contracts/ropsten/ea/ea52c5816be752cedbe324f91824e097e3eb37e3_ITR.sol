// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./RandomlyAssigned.sol";
import './ERC2981ContractWideRoyalties.sol';

contract ITR is ERC721, Ownable, RandomlyAssigned, ERC2981ContractWideRoyalties {
    using Strings for uint256;

    string private baseURI;
    string public notRevealedURI;
    string public baseExtension = ".json";
    uint256 public presaleStart;
    uint256 public saleStart;
    uint256 public cost = .088 ether;
    uint256 public maxMintAmount = 3;
    bool public paused = false;
    bool public revealed = false;
    address payable private artist;
    address[] private teamMembers;

    mapping(address => bool) public whitelisted;
    mapping(address => uint256) public graylisted;

    constructor(
        address payable _artist,
        uint256 _presaleStart,
        uint256 _saleStart,
        string memory _baseURI,
        string memory _notRevealedURI
    ) ERC721("It Remains", "ITR")
    RandomlyAssigned(9002, 1) // sets the max supply to 8888 with randomly mintable tokens
    {
        artist = _artist;
        setPresaleStart(_presaleStart);
        setSaleStart(_saleStart);
        setBaseURI(_baseURI);
        setNotRevealedURI(_notRevealedURI);
    }

    // internal

    function _mintToken() internal {
        uint256 id = nextToken();
        _safeMint(msg.sender, id);
    }

    function _mintMiddleWare(uint256 _mintAmount) internal {
        if(msg.sender != owner()){
            require(msg.value >= cost * _mintAmount, "Not enough ether sent!");
        }

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _mintToken();
        } 
    }

    function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC721, ERC2981Base)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function setTeamMembers(address[] memory _members) external onlyOwner {
        teamMembers = _members;
    }

    // public
    function isSale() public view returns (bool) {
        return (block.timestamp > saleStart);
    }

    function isPresale() public view returns (bool) {
        return (block.timestamp > presaleStart && block.timestamp < saleStart);
    }

    function mint(uint256 _mintAmount) public payable {
        require(!paused, "Contract is paused!");

        if(msg.sender != owner()){
            if(isPresale()){
                require(whitelisted[msg.sender], "User not in presale whitelist!");
                require(_mintAmount <= maxMintAmount, "User cannot mint more than 3 nft at a time!");
                require(graylisted[msg.sender] + _mintAmount <= 3, "User cannot min more than 3 nft at presale!");

                graylisted[msg.sender] = graylisted[msg.sender] + _mintAmount;
                
                _mintMiddleWare(_mintAmount);
            } else if(isSale()) {
                _mintMiddleWare(_mintAmount);
            } else {
                require(isPresale(), "Presale has not yet started!");
            }
        } else {
            _mintMiddleWare(_mintAmount);
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
        ? string(abi.encodePacked(currentBaseURI, "/", tokenId.toString(), baseExtension))
        : "";
    }

    //only owner
    
    function initialMintToken(uint256 _amount) external onlyOwner {
        for (uint256 i = 0; i < _amount; i++) {
            uint256 id = nextToken();
            _safeMint(teamMembers[i], id);
        } 

        for (uint256 i = 0; i < 100 - _amount; i++) {
            uint256 id = nextToken();
            _safeMint(msg.sender, id);
        }
    }

    function setRoyalties(address recipient, uint256 value) public onlyOwner {
        _setRoyalties(recipient, value);
    }

    function setPresaleStart(uint256 _presaleStart) public onlyOwner {
        presaleStart = _presaleStart;
    }

    function setSaleStart(uint256 _saleStart) public onlyOwner {
        saleStart = _saleStart;
    }

    function reveal() public onlyOwner {
        revealed = true;
    }

    function setCost(uint256 _newCost) public onlyOwner {
        cost = _newCost * 10 ** 18;
    }

    function setMaxMintAmount(uint256 _maxMintAmount) public onlyOwner {
        maxMintAmount = _maxMintAmount;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedURI = _notRevealedURI;
    }

    function setBaseExtension(string memory _baseExtension) public onlyOwner {
        baseExtension = _baseExtension;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function setWhitelistedUsers(address[] calldata _users) external onlyOwner {
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