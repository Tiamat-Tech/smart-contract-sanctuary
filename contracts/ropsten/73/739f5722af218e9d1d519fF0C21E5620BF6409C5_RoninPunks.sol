// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./ERC721Pausable.sol";

contract RoninPunks is ERC721Enumerable, Ownable, ERC721Burnable, ERC721Pausable{
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdTracker;

    string private _baseTokenUri;

    uint256 public maxPunks = 6000;
    uint256 public maxPunksPresale = 1800;
    uint256 public punksPrice = 3 * 10 ** 16;
    uint256 public presaleStart;
    uint256 public presaleEnd;

    bool public presaleStatus;
    
    address financeAddress = 0xe17D01db63fCe85918656663E352564c8513b856;

    mapping(address => bool) private _whiteList;
    mapping(address => uint256) private _mintCount;

    event mintPunks(uint256 indexed id, address minter);

    constructor(string memory baseUri) ERC721("RoninPunks", "RPK"){
        setBaseUri(baseUri);
        pause(true);
    }

    function _totalSupply() internal view returns(uint){
        return _tokenIdTracker.current();
    }
    
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenUri;
    }

    function mintReservedPunks(uint256 quantity)public onlyOwner{
        require(_tokenIdTracker.current() <= 200,"RoninPunks: All reserved tokens are minted");

        for(uint256 index; index < quantity; index++){
            _mintAPunk(msg.sender);
        }
    }

    function massWhitelist(address[] memory users)public onlyOwner{
        for(uint8 index; index <= users.length; index++){
            if(_whiteList[users[index]] != true){
                _whiteList[users[index]] = true;
            }
        }
    }

    // function approveWhitelist(address _whitelisted)public onlyOwner{
    //     require(_whiteList[_whitelisted] != true, "RoninPunks: Address already whitelisted!");
    //     _whiteList[_whitelisted] = true;
    // }

    function revokeWhitelist(address _whitelisted)public onlyOwner{
        require(_whiteList[_whitelisted] != false, "RoninPunks: Address already revoked of whitelist!");
        _whiteList[_whitelisted] = false;
    }

    function setupPresale(uint256 _presaleStart, uint256 _presaleEnd) public onlyOwner{
        presaleStart = _presaleStart;
        presaleEnd = _presaleEnd;
    }

    function mint() public payable{
        uint256 totalSupply = _totalSupply();
        require(block.timestamp > presaleEnd, "RoninPunks: Presale hasn't ended yet! Please wait for presale to be finished!");
        require(totalSupply <= maxPunks, "RoninPunks: All Punks are minted!");
        require(msg.value >= punksPrice, "RoninPunks: Payment is below the Price!");

        payable(financeAddress).transfer(msg.value);
        _mintCount[msg.sender] = _mintCount[msg.sender] + 1;
        
        _mintAPunk(msg.sender);
    }

    function presaleMint()public payable{
        uint256 totalSupply = _totalSupply();
        require(block.timestamp > presaleStart, "RoninPunks: Presale hasn't started yet!");
        require(block.timestamp < presaleEnd, "RoninPunks: Presale has ended!");
        require(totalSupply <= maxPunksPresale, "RoninPunks: All presale Punks are minted!");
        require(_whiteList[msg.sender] == true, "RoninPunks: You are not whitelisted, wait for public sale!");
        require(_mintCount[msg.sender] < 2, "RoninPunks: You cannot mint more than 2 punks for presale!");
        require(msg.value >= punksPrice, "RoninPunks: Payment is below the Price!");
        
        payable(financeAddress).transfer(msg.value);
        _mintCount[msg.sender] = _mintCount[msg.sender] + 1;
        
        _mintAPunk(msg.sender);
    }

    function _mintAPunk(address _receiver) private{
        uint256 currId = _totalSupply();
        _safeMint(_receiver, currId);
        emit mintPunks(currId, _receiver);
        _tokenIdTracker.increment();
    }
    

    function setBaseUri(string memory baseUri) public onlyOwner{
        _baseTokenUri = baseUri;
    }
    


    function pause(bool isPaused)public onlyOwner{
        if(isPaused == true){
            _pause();
            return;
        }
        
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

     function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}