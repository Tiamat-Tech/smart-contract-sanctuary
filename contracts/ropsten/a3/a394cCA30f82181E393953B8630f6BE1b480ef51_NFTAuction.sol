import "@openzeppelin/contracts/token/erc721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.8.4;

contract NFTAuction is Ownable {
    // Params
    ERC721 public _nft;
    uint256 public _tokenId;
    uint256 public _biddingTime;
    address payable public _ownerAddr;

    // State
    bool isEnded;
    string public _name;
    string public _symbol;
    uint256 public _endTime;
    uint256 public _highestBid;
    address public _highestBidder;

    mapping(address => uint256) public pendingReturns;

    event AuctionEnded(address winner, uint256 amount);
    event HighestBidIncrease(address bidder, uint256 amount);

    constructor(
        ERC721 nft,
        uint256 tokenId,
        uint256 biddingTime,
        address payable ownerAddr
    ) {
        _nft = ERC721(nft);
        _name = _nft.name();
        _symbol = _nft.symbol();
        _tokenId = tokenId;
        _ownerAddr = ownerAddr;
        _biddingTime = biddingTime;
    }

    function bid() public payable {
        require(block.timestamp < _endTime, "The auction has already ended");
        require(!isEnded, "The auction has already ended");
        require(
            msg.value > _highestBid,
            "There is already a higher or equal bid"
        );

        if (_highestBid != 0) {
            pendingReturns[_highestBidder] += _highestBid;
        }

        _highestBid = msg.value;
        _highestBidder = msg.sender;

        emit HighestBidIncrease(_highestBidder, _highestBid);
    }

    function withdraw() public returns (bool) {
        uint256 amount = pendingReturns[msg.sender];

        if (amount > 0) {
            pendingReturns[msg.sender] = 0;

            if (!payable(msg.sender).send(amount)) {
                pendingReturns[msg.sender] = amount;
                return false;
            }
        }

        return true;
    }

    function startAuction() public onlyOwner {
        require(block.timestamp < _endTime, "The auction has already ended");
        require(!isEnded, "The function endAuction() has already been called");

        _endTime = _biddingTime;
        _nft.safeTransferFrom(_ownerAddr, address(this), _tokenId);
    }

    function endAuction() public onlyOwner {
        require(block.timestamp < _endTime, "The auction has already ended");
        require(!isEnded, "The function endAuction() has already been called");

        isEnded = true;
        _nft.safeTransferFrom(address(this), _highestBidder, _tokenId);
        _ownerAddr.transfer(_highestBid);

        emit AuctionEnded(_highestBidder, _highestBid);
    }
}