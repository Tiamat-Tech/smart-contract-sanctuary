// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Vox is ERC721, ERC721Enumerable, ERC721Burnable, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    using Strings for uint256;

    Counters.Counter private _tokenIdCounter;

    constructor(
        uint256 _saleStartTimestamp,
        uint256 _revealSupply,
        uint256 _maxSupply
    ) ERC721("CollectVox", "VOX") {
        saleStartTimestamp = _saleStartTimestamp;
        revealSupply = _revealSupply;
        maxSupply = _maxSupply;
    }

    string public constant PROVENANCE =
        "367ac30ed963e3807e6fe1de61099c51871e2b05cbcdeb8c6ddb33166565ad7d";

    uint256 public constant MAX_PURCHASE = 20;

    uint256 public constant PRICE = 0.001 * 10**18; // 0.1 ETH

    uint256 public saleStartTimestamp;
    uint256 public revealSupply;
    uint256 public maxSupply;

    uint256 public offsetBlock;
    uint256 public offset;

    function mintNFT(uint256 numberOfNfts) public payable {
        require(block.timestamp >= saleStartTimestamp, "Sale has not started");
        require(totalSupply() < maxSupply, "Sale has ended");
        require(numberOfNfts > 0, "Cannot buy 0");
        require(
            numberOfNfts <= MAX_PURCHASE,
            "You may not buy that many NFTs at once"
        );
        require(
            totalSupply().add(numberOfNfts) <= maxSupply,
            "Exceeds max supply"
        );
        require(
            PRICE.mul(numberOfNfts) == msg.value,
            "Ether value sent is not correct"
        );

        for (uint256 i = 0; i < numberOfNfts; i++) {
            uint256 mintIndex = totalSupply();
            _safeMint(msg.sender, mintIndex);
        }

        if (offsetBlock == 0 && totalSupply() >= revealSupply) {
            offsetBlock = block.number;
        }
    }

    function reveal() public {
        require(offset == 0, "Offset is already set");
        require(offsetBlock != 0, "Offset block must be set");

        offset = uint256(blockhash(offsetBlock)) % maxSupply;
        // Just a sanity case in the worst case if this function is called late (EVM only stores last 256 block hashes)
        if (block.number.sub(offsetBlock) > 255) {
            offset = uint256(blockhash(block.number - 1)) % maxSupply;
        }
        // Prevent default sequence
        if (offset == 0) {
            offset = offset.add(1);
        }
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        string memory baseURI = _baseURI();

        if (offset == 0) {
            return
                bytes(baseURI).length > 0
                    ? string(abi.encodePacked(baseURI, "mystery"))
                    : "";
        } else {
            uint256 voxId = tokenId.add(offset) % maxSupply;
            return
                bytes(baseURI).length > 0
                    ? string(abi.encodePacked(baseURI, voxId.toString()))
                    : "";
        }
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://tokens.gala.games/vox/townstar/";
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
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