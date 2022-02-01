pragma solidity ^0.7.6;
pragma abicoder v2;

import "./../tokens/@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "./IGlipERC721Lazy.sol";
import "./../tokens/@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "hardhat/console.sol";
import "./AuctionValidator.sol";
import "./../tokens/@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "./../tokens/@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./LibLazyBidERC721.sol";
import "./LibLazyAuctionERC721.sol";
import "./../tokens/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "./../roles/IAuctioneerUpgradeable.sol";

contract Auction is
    OwnableUpgradeable,
    IERC721ReceiverUpgradeable,
    AuctionValidator
    {
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    // users who want to buy art work first stake eth before bidding
    struct tokenDetails {
        address seller;
        uint128 price;
        uint256 duration;
        bool isActive;
    }

    mapping(address => uint256) public stake;

    address public auctioneer;
    uint96 public platformFee;


    event AuctionMatched(
        address indexed maker, // maker address of the initial bid order
        address indexed taker, // sender address for the taker ask order
        address indexed token,
        uint256 tokenId, // tokenId transferred
        uint min
    );

    event BidMatched(
        address indexed maker, // maker address of the initial bid order
        address indexed taker, // sender address for the taker ask order
        address indexed token,
        address auctioneer,
        uint256 tokenId, // tokenId transferred
        uint value
    );

    function __Auction_init(uint96 _platformFee, address _auctioneer)
        external
        initializer
    {
        __Ownable_init();
        __AuctionValidator_init_unchained();
        platformFee = _platformFee;
        auctioneer = _auctioneer;
    }

    function setPlatformFee(uint96 _platformFee) external onlyOwner {
        platformFee = _platformFee;
    }

    function getStake(address addr) public view virtual returns (uint256) {
        return stake[addr];
    }

    /**
      Before making off-chain stakes potential bidders need to stake eth and either they will get it back when the auction ends or they can withdraw it any anytime.
    */
    function putStake() external payable virtual {
        require(msg.sender != address(0));
        stake[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdrawStake(uint256 _amount) external virtual {
        require(msg.sender != address(0));
        require(
            stake[msg.sender] >= _amount,
            "Total staked value is lower than requested"
        );
        stake[msg.sender] -= _amount;
        AddressUpgradeable.sendValue(msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }

    function withdrawOnBehalf(address _address) public onlyOwner {
        require(_address != address(0));
        require(
            stake[_address] == 0,
            "No staked amount"
        );
        uint _amount = stake[_address];
        stake[_address] = 0;
        AddressUpgradeable.sendValue(payable(_address), _amount);
        emit Withdraw(_address, _amount);
    }


    function verifyOrderMatch(LibLazyBidERC721.Bid memory _bid,
        LibLazyAuctionERC721.Auction memory _auction) public virtual returns (IGlipERC721Lazy.DecodedMintData memory, uint96) {

            // Verify lazy asset signature from the contract - existance, asset signer, token address
        // Verifies token address in bid and asset
        IGlipERC721Lazy.DecodedMintData memory _tokenData = IGlipERC721Lazy(_bid.token).decodeLazyMintData(_bid.tokenData);

        // Verify token address in bid and auction
        require(
            _bid.token == _auction.token,
            "Bid and auction token don't match"
        );

        // Verify if bid is signed by bid.maker
        bytes32 _bidHash = LibLazyBidERC721.hash(_bid);
        validate(_bid.maker, _bidHash, _bid.signature);

        // Verify if auction was signed by auctioneer from asset contract function call
        //      to prevent anyone else starting the auction and
        //      to allow asset data contract to have arbitrary auctioneer logic
        bytes32 _auctionHash = LibLazyAuctionERC721.hash(_auction);
        address _signer = validate(
            _auction.maker,
            _auctionHash,
            _auction.signature
        );

        // Verify if auctioneer is approved and get auctioneer fee
        uint96 auctioneerFee = IAuctioneerUpgradeable(auctioneer).getFee(
            _bid.token,
            _tokenData.minter.account,
            _signer
        );

        // Verify that the auctioneer collected the bids
        require(
            _bid.auctioneer == _auction.maker,
            "Ensure auctioneer collected the signed bid"
        );

        // Verify token ids in bid, auction and asset
        require(
            _tokenData.tokenId == _bid.tokenId,
            "Bid token id does not match asset token id"
        );
        require(
            _tokenData.tokenId == _auction.tokenId,
            "Auction token id does not match asset token id"
        );

        // Bid maker can't be address 0x000...0
        require(_bid.maker != address(0), "Bid maker is 0x00");

        // // Bidder cannot be auctioneer (Why not!)
        // require(_bid.maker != _auction.taker, "Bid and auction taker is same");

        // Bid value should be less than or equal to staked value of the bid maker
        require(_bid.value <= stake[_bid.maker],"Bid is for higher value than staked");

        // Bid value should be higher than or equal to minimum auction value
        require(_bid.value >= _auction.min, "Bid is lower than min ask price");
        require(_bid.value >= _tokenData.reserve, "Bid is lower than min set by the minter/creator");

        // Auction can only be ended after it's ending timestamp
        require(_auction.end <= block.timestamp, "Auction hasn't ended yet");


        return (_tokenData, auctioneerFee);

    }


    function executeLazyAuction(
        LibLazyBidERC721.Bid memory _bid,
        LibLazyAuctionERC721.Auction memory _auction
    ) external virtual {

        (IGlipERC721Lazy.DecodedMintData memory _tokenData, uint96 auctioneerFee) = verifyOrderMatch(_bid, _auction);

        // All good wrt. validation
        uint256 value = _bid.value;

        // Effect
        // Reduce staked amount
        stake[_bid.maker] = stake[_bid.maker].sub(value);

        // Mint to creator first
        IGlipERC721Lazy(_bid.token).mintAndTransferEncodedData(_bid.tokenData, _bid.taker);

        // // Transfer to bid taker (Remember that taker can be different from bid maker)
        // IGlipERC721Lazy(_bid.token).safeTransferFrom(
        //     _tokenData.creator,
        //     _bid.taker,
        //     _tokenData.tokenId
        // );

        // Transfer required tokens to auction taker
        uint256 auctioneerTake = (value.mul(auctioneerFee)).div(10000);
        uint256 minterTake = (value.mul( _tokenData.minter.value)).div(10000);
        uint256 platformTake = (value.mul(platformFee)).div(10000);
        uint256 royaltyTake = (value.mul(_tokenData.royalty.value)).div(10000);

        stake[_auction.taker] = stake[_auction.taker].add(auctioneerTake);
        stake[_tokenData.minter.account] = stake[_tokenData.minter.account].add(minterTake);
        stake[owner()] = stake[owner()].add(platformTake);

        value = ((value.sub(auctioneerTake)).sub(minterTake)).sub(platformTake).sub(royaltyTake);

        for (uint256 i = 0; i < _tokenData.payouts.length; i++) {
            stake[_tokenData.payouts[i].account] += (value.mul(_tokenData.payouts[i].value)).div(10000);
        }

        // send royalty, do not stake
        if (royaltyTake > 0){
            (bool success, ) = _tokenData.royalty.account.call{value:royaltyTake}("");
            require(success, "Transfer failed.");
        }

        // Interactions

        // Events for querying
        emit AuctionMatched(
            _auction.maker, // maker address of the initial bid order
            _auction.taker, // sender address for the taker ask order
            _auction.token,
            _auction.tokenId, // tokenId transferred
            _auction.min
        );

        emit BidMatched(
            _bid.maker, // maker address of the initial bid order
            _bid.taker, // sender address for the taker ask order
            _bid.token,
            _bid.auctioneer,
            _bid.tokenId, // tokenId transferred
            _bid.value
        );

    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }

    function transferAssetContract(address _newOwner, address _nft)
        external
        virtual
        onlyOwner
    {
        require(
            IGlipERC721Lazy(_nft).owner() != _newOwner,
            "New owner is same as previous"
        );
        IGlipERC721Lazy(_nft).transferOwnership(_newOwner);
    }

    function releaseFunds() public onlyOwner {
        AddressUpgradeable.sendValue(payable(owner()), address(this).balance);
    }

    

    receive() external payable virtual {}

    uint256[50] private __gap;
}