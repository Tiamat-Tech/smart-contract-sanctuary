// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract BadGifts is ERC721Enumerable, ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;

    mapping(uint256 => string) private _giftMessages;

    uint256 public mintPrice = 20000000000000000;
    uint256 public maxSupply = 6969;
    uint256 public maxMint = 10;
    bool public isMintOpen = true;
    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("Bad Gifts", "BG") {}

    function _baseURI() internal pure override returns (string memory) {
        return "https://badgifts.ciberchico.com";
    }

    function safeMint(address to, uint256 amount,string memory message) public payable nonReentrant {
        require(msg.value == mintPrice * amount, "Invalid price");
        mint(to, amount,message);
    }

    function mint(address to, uint256 amount,string memory message) private {
        require(amount <= maxMint, "Max amount exceeded");
        uint256 supply = totalSupply();
        uint256 afterSupply = supply + amount;
        require(afterSupply <= maxSupply, "Max supply would be reached");

        /// Important: check that all mint are succesful
        if (afterSupply == maxSupply) {
            isMintOpen = false;
        }

        for (uint256 i; i < amount; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(to, tokenId);
            _giftMessages[tokenId] = message;
        }
    }

    function getGiftMessage(uint256 tokenId) public view returns(string memory){
        return _giftMessages[tokenId];
    }

    /// @notice Changes the mint status. Its required to set a different status than the one in isMintingOpen
    function setMintStatus(bool newStatus) public onlyOwner {
        require(newStatus != isMintOpen, "New status is invalid");
        isMintOpen = newStatus;
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}