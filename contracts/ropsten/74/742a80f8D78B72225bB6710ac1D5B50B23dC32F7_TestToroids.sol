// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/[email protected]/token/ERC721/ERC721.sol";
import "@openzeppelin/[email protected]/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/[email protected]/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/[email protected]/security/Pausable.sol";
import "@openzeppelin/[email protected]/access/Ownable.sol";
import "@openzeppelin/[email protected]/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/[email protected]/utils/Counters.sol";

contract TestToroids is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable, Ownable, ERC721Burnable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    uint256 public constant MAX_TOKENS = 1111;
    uint256 public constant MAX_TOKENS_PER_ADDRESS = 222;
    uint256 public constant PRICE = 0.1 ether;

    uint256 private constant mintLimit = 22;

    bool public isPresaleActive = false;
    bool public isSaleActive = false;

    mapping(address => uint256) public presaleList;

    string private mContractURI;
    string private mBaseURI;
    string private mRevealedBaseURI;

    event PresaleMint(address minter, uint256 amount);
    event SaleMint(address minter, uint256 amount);

    constructor() ERC721("TestToroids", "TTRDS") {
        _pause();
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://us-central1-toroids-by-lip.cloudfunctions.net/getMetadata?index=";
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function togglePresaleStatus() external onlyOwner {
        isPresaleActive = !isPresaleActive;
    }

    function toggleSaleStatus() external onlyOwner {
        isSaleActive = !isSaleActive;
    }

    function addPresaleList(
        address[] calldata _addrs,
        uint256[] calldata _limit
    ) external onlyOwner {
        require(_addrs.length == _limit.length);
        for (uint256 i = 0; i < _addrs.length; i++) {
            presaleList[_addrs[i]] = _limit[i];
        }
    }

    function presaleMint(uint256 amount) external payable {
        require(isPresaleActive, "Presale is not active");
        require(amount <= mintLimit, "Max mint 22 tokens at a time");

        uint256 senderLimit = presaleList[msg.sender];

        require(senderLimit > 0, "You have no tokens left");
        require(amount <= senderLimit, "Your max token holding exceeded");
        require(
            _tokenIdCounter.current() + amount < MAX_TOKENS,
            "Max token supply exceeded"
        );
        require(msg.value >= amount * PRICE, "Insufficient funds");

        for (uint256 i = 0; i < amount; i++) {
            _safeMint(msg.sender, _tokenIdCounter.current());
            _tokenIdCounter.increment();
            senderLimit -= 1;
        }

        presaleList[msg.sender] = senderLimit;
        emit PresaleMint(msg.sender, amount);
    }

    function mint(uint256 amount) external payable {
        require(isSaleActive, "Sale is not active");
        require(amount <= mintLimit, "Max mint 22 tokens at a time");
        require(
            balanceOf(msg.sender) + amount <= MAX_TOKENS_PER_ADDRESS,
            "Your max token holding exceeded"
        );
        require(
            _tokenIdCounter.current() + amount < MAX_TOKENS,
            "Max token supply exceeded"
        );
        require(msg.value >= amount * PRICE, "Insufficient funds");

        for (uint256 i = 0; i < amount; i++) {
            _safeMint(msg.sender, _tokenIdCounter.current());
            _tokenIdCounter.increment();
        }

        emit SaleMint(msg.sender, amount);
    }

    function gift(address to, uint256 amount) external onlyOwner {
        require(
            _tokenIdCounter.current() + amount < MAX_TOKENS,
            "Max token supply exceeded"
        );
        for (uint256 i = 0; i < amount; i++) {
            _safeMint(to, _tokenIdCounter.current());
            _tokenIdCounter.increment();
        }
    }

    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    // function setContractURI(string calldata URI) external onlyOwner {
    //     mContractURI = URI;
    // }

    // function setBaseURI(string calldata URI) external onlyOwner {
    //     mBaseURI = URI;
    // }

    // function setRevealedBaseURI(string calldata URI) external onlyOwner {
    //     mRevealedBaseURI = URI;
    // }

    // function contractURI() public view returns (string memory) {
    //     return mContractURI;
    // }
    
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
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
}