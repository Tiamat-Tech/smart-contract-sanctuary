pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";


contract TrueAuction is IERC721Receiver {
    struct tokenDetails {
        address seller;
        uint128 price;
        uint256 duration;
        uint256 maxBid;
        address maxBidUser;
        bool isActive;
        uint256[] bidAmounts;
        address[] users;
    }

    mapping(address => mapping(uint256 => tokenDetails)) public tokenToTrueAuction;

    mapping(address => mapping(uint256 => mapping(address => uint256))) public bids;
    
    /**
       Seller puts the item on trueauction
    */
    function createTokenTrueAuction(
        address _nft,
        uint256 _tokenId,
        uint128 _price,
        uint256 _duration
    ) external {
        require(msg.sender != address(0), "Invalid Address");
        require(_nft != address(0), "Invalid Account");
        require(_price > 0, "Price should be more than 0");
        require(_duration > 0, "Invalid duration value");
        tokenDetails memory _trueauction = tokenDetails({
            seller: msg.sender,
            price: uint128(_price),
            duration: _duration,
            maxBid: 0,
            maxBidUser: address(0),
            isActive: true,
            bidAmounts: new uint256[](0),
            users: new address[](0)
        });
        address owner = msg.sender;
        ERC721(_nft).safeTransferFrom(owner, address(this), _tokenId);
        tokenToTrueAuction[_nft][_tokenId] = _trueauction;
    }
    /**
       Users bid for a particular nft, the max bid is compared and set if the current bid id highest
    */
    function bid(address _nft, uint256 _tokenId) external payable {
        tokenDetails storage trueauction = tokenToTrueAuction[_nft][_tokenId];
        require(msg.value >= trueauction.price, "bid price is less than current price");
        require(trueauction.isActive, "trueauction not active");
        require(trueauction.duration > block.timestamp, "Deadline already passed");
        if (bids[_nft][_tokenId][msg.sender] > 0) {
            (bool success, ) = msg.sender.call{value: bids[_nft][_tokenId][msg.sender]}("");
            require(success);
        }
        bids[_nft][_tokenId][msg.sender] = msg.value;
        if (trueauction.bidAmounts.length == 0) {
            trueauction.maxBid = msg.value;
            trueauction.maxBidUser = msg.sender;
        } else {
            uint256 lastIndex = trueauction.bidAmounts.length - 1;
            require(trueauction.bidAmounts[lastIndex] < msg.value, "Current max bid is higher than your bid");
            trueauction.maxBid = msg.value;
            trueauction.maxBidUser = msg.sender;
        }
        trueauction.users.push(msg.sender);
        trueauction.bidAmounts.push(msg.value);
    }
    /**
       Called by the seller when the trueauction duration is over the hightest bid user get's the nft and other bidders get eth back
    */
    function executeSale(address _nft, uint256 _tokenId) external {
        tokenDetails storage trueauction = tokenToTrueAuction[_nft][_tokenId];
        require(trueauction.duration <= block.timestamp, "Deadline did not pass yet");
        require(trueauction.seller == msg.sender, "Not seller");
        require(trueauction.isActive, "trueauction not active");
        trueauction.isActive = false;
        if (trueauction.bidAmounts.length == 0) {
            ERC721(_nft).safeTransferFrom(
                address(this),
                trueauction.seller,
                _tokenId
            );
        } else {
            (bool success, ) = trueauction.seller.call{value: trueauction.maxBid}("");
            require(success);
            for (uint256 i = 0; i < trueauction.users.length; i++) {
                if (trueauction.users[i] != trueauction.maxBidUser) {
                    (success, ) = trueauction.users[i].call{
                        value: bids[_nft][_tokenId][trueauction.users[i]]
                    }("");
                    require(success);
                }
            }
            ERC721(_nft).safeTransferFrom(
                address(this),
                trueauction.maxBidUser,
                _tokenId
            );
        }
    }

    /**
       Called by the seller if they want to cancel the trueauction for their nft so the bidders get back the locked eeth and the seller get's back the nft
    */
    function cancelTrueAuction(address _nft, uint256 _tokenId) external {
        tokenDetails storage trueauction = tokenToTrueAuction[_nft][_tokenId];
        require(trueauction.seller == msg.sender, "Not seller");
        require(trueauction.isActive, "trueauction not active");
        trueauction.isActive = false;
        bool success;
        for (uint256 i = 0; i < trueauction.users.length; i++) {
        (success, ) = trueauction.users[i].call{value: bids[_nft][_tokenId][trueauction.users[i]]}("");        
        require(success);
        }
        ERC721(_nft).safeTransferFrom(address(this), trueauction.seller, _tokenId);
    }

    function getTokenTrueAuctionDetails(address _nft, uint256 _tokenId) public view returns (tokenDetails memory) {
        tokenDetails memory trueauction = tokenToTrueAuction[_nft][_tokenId];
        return trueauction;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    )external override returns(bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

    receive() external payable {}
}