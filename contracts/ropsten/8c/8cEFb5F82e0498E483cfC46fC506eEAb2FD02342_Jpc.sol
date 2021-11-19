// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Jpc is ERC721, ERC721Enumerable, Pausable, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    uint256 public constant MAX_SUPPLY = 7777;
    uint256 public constant MAX_PER_MINT = 20;
    uint256 public constant JPC_PRICE = 0.04 ether;
    string public baseTokenURI;
    bool public _saleIsActive = false;
    uint256 public teamReserve = 100; // Reserve 100 for team & community

    mapping(uint256 => bytes32) public tokenIdToHash;

    constructor(string memory name, string memory symbol, string memory baseURI) ERC721(name, symbol) {
        setBaseURI(baseURI);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _totalSupply() internal view returns (uint) {
        return _tokenIdCounter.current();
    }

    function totalMint() public view returns (uint256) {
        return _totalSupply();
    }

    function mintTeamTokens(address _to, uint256 _reserveAmount) public onlyOwner {
        require(_reserveAmount > 0 && _reserveAmount <= teamReserve, "Not enough reserve left");

        for (uint256 i = 0; i < _reserveAmount; i++) {
            _mintAnElement(_to);
        }
        
        teamReserve = teamReserve.sub(_reserveAmount);
    }

    function mint(address _to, uint256 _count) public payable {
        uint256 total = _totalSupply();
        uint256 maxPublicSupply = MAX_SUPPLY.sub(teamReserve);
        require(_saleIsActive, "Sale paused");
        require(total + _count <= maxPublicSupply, "Not enough left to mint that many");
        require(total <= maxPublicSupply, "Sale is over");
        require(_count > 0, "Minimum of 1");
        require(_count <= MAX_PER_MINT, "Exceeds max per address");
        require(msg.value >= JPC_PRICE.mul(_count), "Below minimum price");

        for (uint256 i = 0; i < _count; i++) {
            _mintAnElement(_to);
        }
    }

    function _mintAnElement(address _to) private {
        uint id = _totalSupply();
        bytes32 tHash = keccak256(abi.encodePacked(id, block.number, blockhash(block.number - 1), _to));
        tokenIdToHash[id] = tHash;
        _tokenIdCounter.increment();
        _safeMint(_to, id);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    function walletOfOwner(address _owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokensId;
    }

    function saleIsActive(bool val) public onlyOwner {
        _saleIsActive = val;
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        address payable _to = payable(msg.sender);
        _to.transfer(balance);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    } 
}