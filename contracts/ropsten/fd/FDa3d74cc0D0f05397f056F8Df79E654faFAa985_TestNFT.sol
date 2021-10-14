// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./ERC721Pausable.sol";
contract TestNFT is ERC721Enumerable, Ownable, ERC721Burnable, ERC721Pausable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdTracker;
		
    uint256 public constant MAX_NERDZ_AVAILABLE = 6900;
    //uint256 public constant COST_PER_NERD = 69 * 10**15;		
    uint256 public constant COST_PER_NERD = 69 * 10**12;		
    uint256 public constant MAX_NERDS_PER_MINT = 20;	
    //uint256 public constant REVEAL_THE_NERDZ = 1627588800; 
    address public constant creatorAddress = 0x477cDfc8c7E5E8689e04A8cBb543a93648c0F388;
    string public baseTokenURI;
	
    event CreateNerdz(uint256 indexed id);
    constructor(string memory baseURI) ERC721("TestNFT", "TNFT") {
        setBaseURI(baseURI);
        pause(true);
    }

    modifier saleIsOpen {
        require(_totalSupply() <= MAX_NERDZ_AVAILABLE, "Sale end");
        if (_msgSender() != owner()) {
            require(!paused(), "Pausable: paused");
        }
        _;
    }
    function _totalSupply() internal view returns (uint) {
        return _tokenIdTracker.current();
    }
    function totalMint() public view returns (uint256) {
        return _totalSupply();
    }
    function mint(address _to, uint256 _count) public payable saleIsOpen {
        uint256 total = _totalSupply();
        require(total + _count <= MAX_NERDZ_AVAILABLE, "Max limit");
        require(total <= MAX_NERDZ_AVAILABLE, "Sale end");
        require(_count <= MAX_NERDS_PER_MINT, "Exceeds number");
        require(msg.value >= costForNerds(_count), "Value below costForNerds");

        for (uint256 i = 0; i < _count; i++) {
            _mintMyNerd(_to);
        }
    }
    function _mintMyNerd(address _to) private {
        uint id = _totalSupply();
        _tokenIdTracker.increment();
        _safeMint(_to, id);
        emit CreateNerdz(id);
    }
    function costForNerds(uint256 _count) public pure returns (uint256) {
        return COST_PER_NERD.mul(_count);
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

    function pause(bool val) public onlyOwner {
        if (val == true) {
            _pause();
            return;
        }
        _unpause();
    }

    function withdrawAll() public payable onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0);        
        _widthdraw(creatorAddress, address(this).balance);
    }

    function _widthdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{value: _amount}("");
        require(success, "Transfer failed.");
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