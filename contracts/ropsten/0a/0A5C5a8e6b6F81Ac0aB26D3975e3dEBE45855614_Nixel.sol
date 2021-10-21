// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Nixel is ERC721Enumerable, Ownable {
    using Strings for uint256;
    event MintNixel(
        address indexed sender,
        uint256 startWith,
        int256 location_x,
        int256 location_y
    );

    //supply counters
    uint256 public totalBlocks;
    uint256 public totalCount = 10000;
    //token Index tracker


    mapping(uint256 => string) public _tokenURI;

    uint256 public priceLuxury = 150000000000000000;
    uint256 public pricePremium = 100000000000000000;
    uint256 public priceEconomy = 10000000000000000;

    //string
    string public baseURI;

    //bool
    bool private started;

    //constructor args
    constructor() ERC721("Nixel", "NIXEL") {
        baseURI = "https://ipfs.io/ipfs/";
    }

    //basic functions.

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newURI) public onlyOwner {
        baseURI = _newURI;
    }

    function setTokenURI(uint256 tokenId, string memory _newURI) public {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token."
        );
        require(ownerOf(tokenId) == _msgSender(), "Not owner of NFT");
        _tokenURI[tokenId] = _newURI;
    }

    function getBlockPrice(int256 x_pos, int256 y_pos) public view virtual returns (uint256){
        if (y_pos >= -5 && x_pos >= -5 && y_pos <= 5 && x_pos <= 5) {
            return priceLuxury;
        } else {
            if (y_pos >= -21 && x_pos >= -21 && y_pos <= 21 && x_pos <= 21) {
                return pricePremium;
            } else {
                if (
                    y_pos >= -50 && x_pos >= -50 && y_pos <= 50 && x_pos <= 50
                ) {
                    return priceEconomy;
                } else {
                    return 0;
                }
            }
        }
    }

    //erc721
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token."
        );
        return string(abi.encodePacked(baseURI, _tokenURI[tokenId]));
    }

    function setStart(bool _start) public onlyOwner {
        started = _start;
    }

    function tokensOfOwner(address owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 count = balanceOf(owner);
        uint256[] memory ids = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            ids[i] = tokenOfOwnerByIndex(owner, i);
        }
        return ids;
    }

    function mint(int256 x_pos, int256 y_pos) public payable {
        require(started, "not started");
        require(blockOwner(x_pos, y_pos) == address(0), "block already minted");
        require(totalBlocks + 1 <= totalCount, "max supply reached!");
        require(
            (y_pos > -50 && y_pos < 50 && x_pos > -50 && x_pos < 50) == true,
            "out of bounds"
        );
        if (y_pos >= -5 && x_pos >= -5 && y_pos <= 5 && x_pos <= 5) {
            require(
                msg.value == priceLuxury,
                "value error, please check price."
            );
        } else {
            if (y_pos >= -21 && x_pos >= -21 && y_pos <= 21 && x_pos <= 21) {
                require(
                    msg.value == pricePremium,
                    "value error, please check price."
                );
            } else {
                if (
                    y_pos >= -50 && x_pos >= -50 && y_pos <= 50 && x_pos <= 50
                ) {
                    require(
                        msg.value == priceEconomy,
                        "value error, please check price."
                    );
                }
            }
        }

        payable(owner()).transfer(msg.value);
        _blockOwner[x_pos][y_pos] = _msgSender();
        _blockTokenId[x_pos][y_pos] = totalBlocks + 1; 
        _blockLocation[totalBlocks + 1] = [x_pos,y_pos];
        emit MintNixel(_msgSender(), totalBlocks + 1, x_pos, y_pos);
        _mint(_msgSender(), 1 + totalBlocks++);
    }
}