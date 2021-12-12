// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./TokenTx/IERC2981.sol";
import "./TokenTx/IERC721Metadata.sol";

/**
 * @title TokenTx contract
 */
contract TokenTx {
    receive() external payable {}
    fallback() external payable {}

    event Post (
        uint256 itemId,
        address nftContract,
        uint256 tokenId,
        string uri,
        address seller,
        uint256 price,
        uint256 timer
    );

    event Cancel (
        uint256 itemId,
        address nftContract,
        uint256 tokenId,
        string uri,
        address owner
    );

    event Purchase (
        uint256 itemId,
        address nftContract,
        uint256 tokenId,
        string uri,
        address seller,
        address owner,
        uint256 price
    );

    event Bid (
        uint256 itemId,
        address nftContract,
        uint256 tokenId,
        string uri,
        address bidder,
        address seller,
        uint256 price
    );

    event Swap (
        address nftContract1,
        uint256 tokenId1,
        address initialOwner1,
        address newOwner1,
        address nftContract2,
        uint256 tokenId2,
        address initialOwner2,
        address newOwner2
    );

    struct Item {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        string uri;
        address seller;
        address owner;
        uint256 price;
        uint256 timer;
        uint256 limit;
        address bidder;
        bool available;
    }

    mapping (uint256 => Item) private _tracking;
    mapping (address => address) private _contractTrace;
    mapping (address => uint256) private _tokenTrace;

    uint256 private _itemId;

    bool private constant unlocked = true;
    bool private constant locked = false;
    bool private _gate;

    address management;

    /**
     * @dev Sets values for {_gate} {_itemId} and {management}
     */
    constructor(address _management) {
        _gate = unlocked;
        _itemId = 100;
        management = _management;
    }

    /**
     * @dev Searches entire blockchain
     */
    function searchTest(address nftContract, uint256 tokenId) public view returns (string memory, string memory, string memory, address) {
        string memory name;
        string memory symbol;
        string memory uri;
        address owner;

        if (IERC165(nftContract).supportsInterface(0x5b5e139f) == true) {
            name = IERC721Metadata(nftContract).name();
            symbol = IERC721Metadata(nftContract).symbol();
            uri = IERC721Metadata(nftContract).tokenURI(tokenId);
        } else {
            name = "";
            symbol = "";
            uri = "";
        }

        owner = IERC2981(nftContract).ownerOf(tokenId);

        return (
            name,
            symbol,
            uri,
            owner
        );
    }

    /**
     * @dev Posts an item for sale
     */
    function post(address nftContract, uint256 tokenId, uint256 price, uint256 dayTimer) public {
        require(_gate != locked, "TokenTx: reentrancy denied");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "TokenTx: caller is not the owner of the token");
        require(IERC721(nftContract).getApproved(tokenId) == address(this), "TokenTx: marketplace has not been approved");
        require(price > 0, "TokenTx: price cannot be zero");
        require(dayTimer < 30, "TokenTx: auction cannot be for more than 30 days");

        _gate = locked;

        string memory uri;

        if (IERC165(nftContract).supportsInterface(0x5b5e139f) == true) {
            uri = IERC721Metadata(nftContract).tokenURI(tokenId);
        } else {
            uri = "";
        }

        if (dayTimer >= 1) {
            uint256 timer = dayTimer;
            uint256 limit = block.timestamp + (dayTimer * 86400);

            _itemId += 1;
            uint256 itemId = _itemId * 476;

            _tracking[itemId] = Item (
                itemId,
                nftContract,
                tokenId,
                uri,
                msg.sender,
                msg.sender,
                price,
                timer,
                limit,
                address(0),
                true
            );

            emit Post (
                itemId,
                nftContract,
                tokenId,
                uri,
                msg.sender,
                price,
                timer
            );
        } else {
            uint256 timer = 0;
            uint256 limit = 0;

            _itemId += 1;
            uint256 itemId = _itemId * 476;

            _tracking[itemId] = Item (
                itemId,
                nftContract,
                tokenId,
                uri,
                msg.sender,
                msg.sender,
                price,
                timer,
                limit,
                address(0),
                true
            );

            emit Post (
                itemId,
                nftContract,
                tokenId,
                uri,
                msg.sender,
                price,
                timer
            );
        }

        _gate = unlocked;
    }

    /**
     * @dev Cancels an item from being sold
     */
    function cancel(uint256 itemId) public {
        require(_gate != locked, "TokenTx: reentrancy denied");
        require(_tracking[itemId].available == true, "TokenTx: item is already unavailable");
        require(
            IERC721(_tracking[itemId].nftContract).ownerOf(_tracking[itemId].tokenId) == msg.sender,
            "TokenTx: caller is not the owner of the token"
        );

        _gate = locked;

        address nftContract = _tracking[itemId].nftContract;
        uint256 tokenId = _tracking[itemId].tokenId;
        string memory uri = _tracking[itemId].uri;

        _tracking[itemId].available = false;

        emit Cancel (
            itemId,
            nftContract,
            tokenId,
            uri,
            msg.sender
        );

        _gate = unlocked;
    }

    /**
     * @dev Fetches an item
     */
    function fetch(uint256 itemId) public view returns (address, uint256, string memory, address, address, uint256, bool) {
        return (
            _tracking[itemId].nftContract,
            _tracking[itemId].tokenId,
            _tracking[itemId].uri,
            _tracking[itemId].seller,
            IERC721(_tracking[itemId].nftContract).ownerOf(_tracking[itemId].tokenId),
            _tracking[itemId].price,
            _tracking[itemId].available
        );
    }

    /**
     * @dev Returns claim status for bidder
     */
    function status(uint256 itemId) public view returns (address, uint256, uint256, address, uint256, bool) {
        require(_tracking[itemId].timer >= 1, "TokenTx: not an auctionable item");
        
        bool _claimStatus;
        uint256 _timeRemaining;

        if (_tracking[itemId].limit < block.timestamp) {
            if (_tracking[itemId].available == false) {
                _claimStatus = false;
            } else {
                if (_tracking[itemId].limit == 0) {
                    _claimStatus = false;
                } else {
                    _claimStatus = true;
                    _timeRemaining = 0;
                }
            }
        } else {
            _claimStatus = false;
            _timeRemaining = _tracking[itemId].limit - block.timestamp;
        }
        return (
            _tracking[itemId].nftContract,
            _tracking[itemId].tokenId,
            _tracking[itemId].price,
            _tracking[itemId].bidder,
            _timeRemaining,
            _claimStatus
        );
    }

    /**
     * @dev Swaps NFTs
     */
    function swap(address nftContract, uint256 tokenId, address nftContractSwap, uint256 tokenIdSwap) public {
        require(_gate != locked, "TokenTx: reentrancy denied");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "TokenTx: caller is not the owner of the token");
        require(IERC721(nftContract).getApproved(tokenId) == address(this), "TokenTx: marketplace has not been approved");

        _gate = locked;

        _contractTrace[msg.sender] = nftContractSwap;
        _tokenTrace[msg.sender] = tokenIdSwap;

        address requestSwapOwner = IERC721(nftContractSwap).ownerOf(tokenIdSwap);

        if (_contractTrace[requestSwapOwner] == nftContract && _tokenTrace[requestSwapOwner] == tokenId) {
            require(IERC721(nftContractSwap).getApproved(tokenIdSwap) == address(this), "TokenTx: marketplace has not been approved");
            IERC721(nftContractSwap).transferFrom(requestSwapOwner, msg.sender, tokenIdSwap);
            IERC721(nftContract).transferFrom(msg.sender, requestSwapOwner, tokenId);

            emit Swap (
                nftContractSwap,
                tokenIdSwap,
                requestSwapOwner,
                msg.sender,
                nftContract,
                tokenId,
                msg.sender,
                requestSwapOwner
            );
        } else {}

        _gate = unlocked;
    }

    /**
     * @dev Bids on an item
     */
    function bid(uint256 itemId, uint256 amount) public {
        require(_gate != locked, "TokenTx: reentrancy denied");
        require(_tracking[itemId].timer >= 1, "TokenTx: not an auctionable item");
        require(_tracking[itemId].limit >= block.timestamp, "TokenTx: auction has expired");
        require(_tracking[itemId].price < amount, "TokenTx: bid must be greater than price");

        _gate = locked;

        uint256 price;
        price = amount;
        address bidder = msg.sender;

        _tracking[itemId] = Item (
            itemId,
            _tracking[itemId].nftContract,
            _tracking[itemId].tokenId,
            _tracking[itemId].uri,
            _tracking[itemId].seller,
            _tracking[itemId].owner,
            price,
            _tracking[itemId].timer,
            _tracking[itemId].limit,
            bidder,
            true
        );

        emit Bid (
            itemId,
            _tracking[itemId].nftContract,
            _tracking[itemId].tokenId,
            _tracking[itemId].uri,
            msg.sender,
            _tracking[itemId].seller,
            price
        );

        _gate = unlocked;
    }

    /**
     * @dev Purchases an item
     */
    function purchase(uint256 itemId) public payable {
        require(_gate != locked, "TokenTx: reentrancy denied");
        require(_tracking[itemId].available == true, "TokenTx: item is unavailable");
        require(
            IERC721(_tracking[itemId].nftContract).ownerOf(_tracking[itemId].tokenId) == _tracking[itemId].owner,
            "TokenTx: seller is not the owner of the token anymore"
        );
        require(
            IERC721(_tracking[itemId].nftContract).getApproved(_tracking[itemId].tokenId) == address(this),
            "TokenTx: marketplace has not been approved"
        );
        require(msg.value >= _tracking[itemId].price, "TokenTx: incorrect asking price");

        _gate = locked;

        address tokenReceiver;

        if (_tracking[itemId].timer >= 1) {
            require(_tracking[itemId].limit < block.timestamp, "TokenTx: auction has not completed");
            require(_tracking[itemId].bidder == msg.sender, "TokenTx: caller not the highest bidder");

            tokenReceiver = msg.sender;
        } else {
            require(_tracking[itemId].timer == 0, "TokenTx: access denied");
            require(_tracking[itemId].limit == 0, "TokenTx: access denied");
            require(_tracking[itemId].bidder == address(0), "TokenTx: access denied");

            tokenReceiver = msg.sender;
        }

        address seller = _tracking[itemId].seller;
        address nftContract = _tracking[itemId].nftContract;
        uint256 tokenId = _tracking[itemId].tokenId;
        string memory uri = _tracking[itemId].uri;
        uint256 price = _tracking[itemId].price;

        address receiverAddress;
        uint256 royaltyFund;

        uint256 amount = msg.value;
        uint256 fee;

        if (IERC165(nftContract).supportsInterface(0x2a55205a) == true) {
            (receiverAddress, royaltyFund) = IERC2981(nftContract).royaltyInfo(tokenId, price);
            amount = price - royaltyFund;
            (bool tx1, ) = payable(receiverAddress).call{value: royaltyFund}("");
            require(tx1, "TokenTx: ether transfer to royalty receiver failed");

            fee = amount / 100;
            amount = amount - fee;
        } else {
            amount = msg.value;

            fee = amount / 100;
            amount = amount - fee;
        }

        (bool tx2, ) = payable(seller).call{value: amount}("");
        require(tx2, "TokenTx: ether transfer to sell failed");

        (bool tx3, ) = payable(management).call{value: fee}("");
        require(tx3, "TokenTx: ether transfer to management failed");

        IERC721(nftContract).transferFrom(seller, tokenReceiver, tokenId);

        _tracking[itemId].owner = tokenReceiver;

        _tracking[itemId].available = false;

        emit Purchase (
            itemId,
            nftContract,
            tokenId,
            uri,
            seller,
            msg.sender,
            msg.value
        );

        _gate = unlocked;
    }
}