//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// implements the ERC721 standard
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract RaffleNFT is ERC721URIStorage, ERC721Enumerable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address payable private _owner;
    
    uint256 private _maxSupply;

    uint256 private randNonce = 0;

    uint256[] private _tickets;

    constructor(uint256 maxTickets) ERC721("RaffleNFT", "RFT") {
        _owner = payable(msg.sender);
        _maxSupply = maxTickets;
    }

    function BuyTicket() public payable returns (uint256) {
        require(totalSupply() < _maxSupply, "Sold Out");
        require(msg.value > 0.01 ether, "Need to send at least 0.01  ether");

        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        uint256 ticket = addIfNotPresent(pick() + 1);

        string memory id = Strings.toString(ticket);
        string memory metadata = "/metadata.json";
        string memory url = string(
            abi.encodePacked(
                "https://ipfs.io/ipfs/QmTxpZmNv5YfB8Di92CqBWhtHvnk6mE6ZKAycBhiAe1wFh/",
                id,
                metadata
            )
        );

        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, url);

        _owner.transfer(msg.value);

        return newItemId;
    }

    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }

    function addIfNotPresent(uint256 num) private returns (uint256) {
        uint256 arrayLength = _tickets.length;
        bool found = false;
        for (uint256 i = 0; i < arrayLength; i++) {
            if (_tickets[i] == num) {
                found = true;
                break;
            }
        }

        if (!found) {
            _tickets.push(num);
            return (num);
        } else {
            addIfNotPresent(pick() + 1);
        }
        return (0);
    }

    function pick() internal returns (uint256) {
        randNonce++;
        return
            uint256(
                keccak256(
                    abi.encodePacked(block.timestamp, msg.sender, randNonce)
                )
            ) % _maxSupply;
    }

    function tokensOfOwner(address owner)
        external
        view
        returns (string[] memory ownerTokens)
    {
        uint256 tokenCount = balanceOf(owner);

        if (tokenCount == 0) {
            // Return an empty array
            return new string[](0);
        } else {
            string[] memory result = new string[](tokenCount);
            uint256 totalTickets = totalSupply();
            uint256 resultIndex = 0;

            uint256 Id;

            for (Id = 1; Id <= totalTickets; Id++) {
                if (ownerOf(Id) == owner) {
                    result[resultIndex] = tokenURI(Id);
                    resultIndex++;
                }
            }

            return result;
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);

        require(to == msg.sender, "Tickets are not transferable");
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
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