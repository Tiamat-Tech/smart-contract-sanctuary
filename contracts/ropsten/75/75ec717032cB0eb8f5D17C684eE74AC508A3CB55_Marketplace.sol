//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

//import "hardhat/console.sol";
import "./Nft.sol";
import "./Auction.sol";

contract Marketplace is Nft, Auction {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct Tracker {
//        uint256 id;
//        string nft;
//        address user;
        string action;
        uint256 dateTime;
    }

    struct Nft {
        uint256 id;
        address owner;
        string nft;
        uint128 price;
        uint256 maxBid;
        address maxBidUser;
        uint256[] bidAmounts;
        address[] users;
        bool isListed;
//        uint256 mintedAt;
//        uint256 listedAt;
        bool isAuctionStarted;
        bool isAuctionEnded;
        Tracker[] tracker;
//        uint256 auctionStartedAt;
//        uint256 auctionEndedAt;
    }

    mapping (uint256 => Nft) public nfts;
    mapping (uint256 => Tracker) tracker;

    // this lets you look up a token by the uri (assuming there is only one of each uri for now)
    mapping (bytes32 => uint256) public uriToTokenId;

    function mintItem(string memory tokenURI) public returns (uint256) {

        bytes32 uriHash = keccak256(abi.encodePacked(tokenURI));

        _tokenIds.increment();

        uint256 id = _tokenIds.current();
        _mint(msg.sender, id);
        _setTokenURI(id, tokenURI);

        uriToTokenId[uriHash] = id;

        Nft storage nft = nfts[id];
        nft.id = id;
        nft.owner = msg.sender;
        nft.nft = tokenURI;
        nft.tracker.push(Tracker('minted', block.timestamp));

        return id;
    }

    function getNfts() public view returns (Nft[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;

        for (uint i = 0; i < totalItemCount; i++) {
            if (nfts[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        Nft[] memory items = new Nft[](itemCount);

        for (uint i = 0; i < totalItemCount; i++) {
            if (nfts[i + 1].owner == msg.sender) {
                uint currentId = i + 1;
                Nft storage currentItem = nfts[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return items;
    }

    function getTracker(uint256 _id) public view returns(Tracker[] memory)
    {
        return nfts[_id].tracker;
    }

    function createToken(
        address _nft,
        uint256 _tokenId,
        uint128 _price
    ) public {

        require(msg.sender != address(0), "Invalid Address");
        require(_nft != address(0), "Invalid Account");
        require(_price > 0, "Price should be more than 0");

        ERC721(_nft).safeTransferFrom(msg.sender, address(this), _tokenId);

        nfts[_tokenId].price = uint128(_price);
        nfts[_tokenId].maxBid = 0;
        nfts[_tokenId].maxBidUser = address(0);
        nfts[_tokenId].bidAmounts = new uint256[](0);
        nfts[_tokenId].users = new address[](0);
        nfts[_tokenId].isListed = true;
        nfts[_tokenId].tracker.push(Tracker('listed', block.timestamp));
    }

    function getTokenAuctionDetails(uint256 _tokenId) public view returns (Nft memory) {
        Nft memory auction = nfts[_tokenId];
        return auction;
    }

    function getListedItems(address _user) public view returns (Nft[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;
        address user = _user == address (0) ? msg.sender : _user;

        for (uint i = 0; i < totalItemCount; i++) {
            if (nfts[i + 1].owner == user) {
                itemCount += 1;
            }
        }

        Nft[] memory items = new Nft[](itemCount);

        for (uint i = 0; i < totalItemCount; i++) {
            if (nfts[i + 1].owner == user) {
                uint currentId = i + 1;
                Nft storage currentItem = nfts[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }
}