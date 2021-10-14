pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";


contract FexNFTAuction is IERC721Receiver {
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

    mapping(address => mapping(uint256 => tokenDetails)) public tokenToFexNFTAuction;

    mapping(address => mapping(uint256 => mapping(address => uint256))) public bids;
    
    /**
       Seller puts the item on fexnftauction
    */
    function createTokenFexNFTAuction(
        address _nft,
        uint256 _tokenId,
        uint128 _price,
        uint256 _duration
    ) external {
        require(msg.sender != address(0), "Invalid Address");
        require(_nft != address(0), "Invalid Account");
        require(_price > 0, "Price should be more than 0");
        require(_duration > 0, "Invalid duration value");
        tokenDetails memory _fexnftauction = tokenDetails({
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
        tokenToFexNFTAuction[_nft][_tokenId] = _fexnftauction;
    }
    /**
       Users bid for a particular nft, the max bid is compared and set if the current bid id highest
    */
    function bid(address _nft, uint256 _tokenId) external payable {
        tokenDetails storage fexnftauction = tokenToFexNFTAuction[_nft][_tokenId];
        require(msg.value >= fexnftauction.price, "bid price is less than current price");
        require(fexnftauction.isActive, "fexnftauction not active");
        require(fexnftauction.duration > block.timestamp, "Deadline already passed");
        if (bids[_nft][_tokenId][msg.sender] > 0) {
            (bool success, ) = msg.sender.call{value: bids[_nft][_tokenId][msg.sender]}("");
            require(success);
        }
        bids[_nft][_tokenId][msg.sender] = msg.value;
        if (fexnftauction.bidAmounts.length == 0) {
            fexnftauction.maxBid = msg.value;
            fexnftauction.maxBidUser = msg.sender;
        } else {
            uint256 lastIndex = fexnftauction.bidAmounts.length - 1;
            require(fexnftauction.bidAmounts[lastIndex] < msg.value, "Current max bid is higher than your bid");
            fexnftauction.maxBid = msg.value;
            fexnftauction.maxBidUser = msg.sender;
        }
        fexnftauction.users.push(msg.sender);
        fexnftauction.bidAmounts.push(msg.value);
    }
    /**
       Called by the seller when the fexnftauction duration is over the hightest bid user get's the nft and other bidders get eth back
    */
    function executeSale(address _nft, uint256 _tokenId) external {
        tokenDetails storage fexnftauction = tokenToFexNFTAuction[_nft][_tokenId];
        require(fexnftauction.duration <= block.timestamp, "Deadline did not pass yet");
        require(fexnftauction.seller == msg.sender, "Not seller");
        require(fexnftauction.isActive, "fexnftauction not active");
        fexnftauction.isActive = false;
        if (fexnftauction.bidAmounts.length == 0) {
            ERC721(_nft).safeTransferFrom(
                address(this),
                fexnftauction.seller,
                _tokenId
            );
        } else {
            (bool success, ) = fexnftauction.seller.call{value: fexnftauction.maxBid}("");
            require(success);
            for (uint256 i = 0; i < fexnftauction.users.length; i++) {
                if (fexnftauction.users[i] != fexnftauction.maxBidUser) {
                    (success, ) = fexnftauction.users[i].call{
                        value: bids[_nft][_tokenId][fexnftauction.users[i]]
                    }("");
                    require(success);
                }
            }
            ERC721(_nft).safeTransferFrom(
                address(this),
                fexnftauction.maxBidUser,
                _tokenId
            );
        }
    }

    /**
       Called by the seller if they want to cancel the fexnftauction for their nft so the bidders get back the locked eeth and the seller get's back the nft
    */
    function cancelFexNFTAuction(address _nft, uint256 _tokenId) external {
        tokenDetails storage fexnftauction = tokenToFexNFTAuction[_nft][_tokenId];
        require(fexnftauction.seller == msg.sender, "Not seller");
        require(fexnftauction.isActive, "fexnftauction not active");
        fexnftauction.isActive = false;
        bool success;
        for (uint256 i = 0; i < fexnftauction.users.length; i++) {
        (success, ) = fexnftauction.users[i].call{value: bids[_nft][_tokenId][fexnftauction.users[i]]}("");        
        require(success);
        }
        ERC721(_nft).safeTransferFrom(address(this), fexnftauction.seller, _tokenId);
    }

    function getTokenFexNFTAuctionDetails(address _nft, uint256 _tokenId) public view returns (tokenDetails memory) {
        tokenDetails memory fexnftauction = tokenToFexNFTAuction[_nft][_tokenId];
        return fexnftauction;
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