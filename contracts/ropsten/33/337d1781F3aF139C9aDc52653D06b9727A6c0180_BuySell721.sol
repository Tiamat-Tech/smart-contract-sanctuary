pragma solidity ^0.8.1;

import "Ownable.sol";
import "IERC721.sol";
import "IERC20.sol";

contract BuySell721 is Ownable {
    enum PledgeStatus {
        DONE,
        REFUNDED
    }

    enum ItemStatus {
        FOR_SALE,
        PURCHASE_APPROVED,
        CANCELED,
        SOLD
    }

    struct Item {
        address contractAddress;
        uint256 tokenId;
        address paymentContract;
        uint256 price;
        uint256 pledgeAmount;
        uint256 pledge;
        address owner;
        bool isItemWithdrawn;
        bool isMoneyWithdrawn;
        ItemStatus status;
    }

    struct Pledge {
        uint256 item;
        address pledger;
        PledgeStatus status;
    }

    mapping(uint256 => Item) public itemForSaleStore;
    mapping(uint256 => Pledge) public pledgeStore;
    uint256 public itemSaleNumber;
    uint256 public pledgeNumber;

    event PlacedItemForSale(uint256 item);
    event SaleCanceled(uint256 item);
    event PledgeForItem(uint256 item, address pledger);
    event RefundPledge(uint256 item);
    event ApprovePurchase(uint256 item);
    event BuyItem(uint256 item);
    event ItemWithdrawn(uint256 item);
    event MoneyWithdrawn(uint256 item);

    function placeItemForSale(
        address _contractAddress,
        uint256 _tokenId,
        address _paymentContract,
        uint256 _price,
        uint256 _pledgeAmount
    ) external {
        address _msgSender = msg.sender;
        require(
            _pledgeAmount < _price,
            "BuySell: price can't be less than pledge"
        );
        itemSaleNumber += 1;
        itemForSaleStore[itemSaleNumber] = Item({
            contractAddress: _contractAddress,
            tokenId: _tokenId,
            paymentContract: _paymentContract,
            price: _price,
            pledgeAmount: _pledgeAmount,
            pledge: 0,
            owner: _msgSender,
            isItemWithdrawn: false,
            isMoneyWithdrawn: false,
            status: ItemStatus.FOR_SALE
        });
        IERC721(_contractAddress).transferFrom(_msgSender, address(this), _tokenId);

        emit PlacedItemForSale(itemSaleNumber);
    }

    function cancelSale(uint256 _itemId) external {
        address _msgSender = msg.sender;
        Item memory _itemForSale = itemForSaleStore[_itemId];
        require(
            _msgSender == _itemForSale.owner,
            "BuySell: It's not your item"
        );
        require(
            _itemForSale.status == ItemStatus.FOR_SALE,
            "BuySell: You can't cancel this sale"
        );
        if (_itemForSale.pledge != 0) {
            require(
                pledgeStore[_itemForSale.pledge].status ==
                    PledgeStatus.REFUNDED,
                "BuySell: this item is reserved"
            );
        }
        IERC721(_itemForSale.contractAddress).safeTransferFrom(
            address(this),
            _msgSender,
            _itemForSale.tokenId
        );
        itemForSaleStore[_itemId].status = ItemStatus.CANCELED;
        emit SaleCanceled(_itemId);
    }

    function reserveItem(uint256 _itemId) external {
        address _msgSender = msg.sender;
        Item memory _itemForSale = itemForSaleStore[_itemId];
        require (_itemForSale.status == ItemStatus.FOR_SALE, "This item can't be reserved");
        if (_itemForSale.pledge != 0) {
            require(
                pledgeStore[_itemForSale.pledge].status ==
                    PledgeStatus.REFUNDED,
                "BuySell: this item is already reserved"
            );
        }
        IERC20 _pledgeContract = IERC20(_itemForSale.paymentContract);
        _pledgeContract.transferFrom(
            _msgSender,
            address(this),
            _itemForSale.pledgeAmount
        );
        pledgeNumber += 1;
        pledgeStore[pledgeNumber] = Pledge({
            item: _itemId,
            pledger: _msgSender,
            status: PledgeStatus.DONE
        });

        itemForSaleStore[_itemId].pledge = pledgeNumber;

        emit PledgeForItem(_itemId, _msgSender);
    }

    function refundPledge(uint256 _itemId) external {
        address _msgSender = msg.sender;
        Item memory _itemForSale = itemForSaleStore[_itemId];
        require(_itemForSale.pledge != 0, "BuySell: no pledge available");
        Pledge memory _pledge = pledgeStore[_itemForSale.pledge];

        require(
            _msgSender == _itemForSale.owner || _msgSender == _pledge.pledger,
            "BuySell: You can't refund this pledge"
        );
        require(
            _itemForSale.status == ItemStatus.FOR_SALE,
            "BuySell: You can't refund pledge for this item"
        );
        require(
            _pledge.status == PledgeStatus.DONE,
            "BuySell: You can't refund it"
        );
        IERC20 _pledgeContract = IERC20(_itemForSale.paymentContract);
        _pledgeContract.transferFrom(
            address(this),
            _msgSender,
            _itemForSale.pledgeAmount
        );
        pledgeStore[_itemForSale.pledge].status = PledgeStatus.REFUNDED;

        emit RefundPledge(_itemId);
    }

    function approvePurchase(uint256 _itemId) external {
        address _msgSender = msg.sender;
        Item memory _itemForSale = itemForSaleStore[_itemId];
        require(_itemForSale.pledge != 0, "BuySell: no pledge available");
        Pledge memory _pledge = pledgeStore[_itemForSale.pledge];
        require(
            _msgSender == _itemForSale.owner,
            "BuySell: It's not your item"
        );
        require(
            _itemForSale.status == ItemStatus.FOR_SALE,
            "BuySell: You can't approve purchase to it"
        );
        require(
            _pledge.status == PledgeStatus.DONE,
            "BuySell: you can't approve purchase to it"
        );

        itemForSaleStore[_itemId].status = ItemStatus.PURCHASE_APPROVED;

        emit ApprovePurchase(_itemId);
    }

    function buyItem(uint256 _itemId) external {
        address _msgSender = msg.sender;
        Item memory _itemForSale = itemForSaleStore[_itemId];
        require(_itemForSale.pledge != 0, "BuySell: no pledge available");
        Pledge memory _pledge = pledgeStore[_itemForSale.pledge];
        // check if sender is a pledger
        require(
            _pledge.pledger == _msgSender,
            "BuySell: this pledge isn't your"
        );
        // check if pledge is available
        require(
            _pledge.status == PledgeStatus.DONE,
            "BuySell: this pledge is inavailable"
        );
        // check if purchase is approved
        require(
            _itemForSale.status == ItemStatus.PURCHASE_APPROVED,
            "BuySell: you can't buy this item"
        );

        IERC20(_itemForSale.paymentContract).transferFrom(
            _msgSender,
            address(this),
            _itemForSale.price - _itemForSale.pledgeAmount
        );

        itemForSaleStore[_itemId].status = ItemStatus.SOLD;

        emit BuyItem(_itemId);
    }

    function withdrawMoneyAfterDeal(uint256 _itemId) external {
        address _msgSender = msg.sender;
        Item memory _itemForSale = itemForSaleStore[_itemId];
        require(
            _itemForSale.status == ItemStatus.SOLD && _itemForSale.isMoneyWithdrawn == false,
            "BuySell: you can't withdraw money"
        );
        require(
            _msgSender == _itemForSale.owner,
            "BuySell: It's not your item"
        );
        IERC20(_itemForSale.paymentContract).transferFrom(
            address(this),
            _msgSender,
            _itemForSale.price
        );
        itemForSaleStore[_itemId].isMoneyWithdrawn = true;
        emit MoneyWithdrawn(_itemId);
    }

    function withdrawItemAfterDeal(uint256 _itemId) external {
        address _msgSender = msg.sender;
        Item memory _itemForSale = itemForSaleStore[_itemId];
        require(
            _itemForSale.status == ItemStatus.SOLD && _itemForSale.isItemWithdrawn == false,
            "BuySell: you can't withdraw item"
        );
        Pledge memory _pledge = pledgeStore[_itemForSale.pledge];
        require(
            _msgSender == _pledge.pledger,
            "BuySell: You didn't buy this item"
        );
        IERC721(_itemForSale.contractAddress).safeTransferFrom(
            address(this),
            _msgSender,
            _itemForSale.tokenId
        );
        itemForSaleStore[_itemId].isItemWithdrawn = true;
        emit ItemWithdrawn(_itemId);
    }
}