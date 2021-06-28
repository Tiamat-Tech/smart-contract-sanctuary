pragma solidity 0.7.4;

import "./Minter.sol";
import "@0xsequence/erc-1155/contracts/interfaces/IERC1155TokenReceiver.sol";

contract Exchange is Minter, IERC1155TokenReceiver {
    struct FixedPriceOrder {
        address seller;
        uint256 tokenId;
        uint256 price;
        uint256 amount;
    }
    mapping(uint256 => FixedPriceOrder) public fixedPriceOrders;
    /**
    @dev createSellOrderFee should be updated later
     */
    uint256 public createSellOrderFee = 10 * 10**9;
    uint256 private currentOrderId = 0;
    event SellOrderCreated(
        address seller,
        uint256 tokenId,
        uint256 price,
        uint256 amount,
        uint256 orderId
    );
    event SellOrderFulfilled(address buyer, uint256 orderId, uint256 amount);

    constructor(address _paymentToken) Minter(_paymentToken) {}

    function onERC1155Received(
        address _operator,
        address _from,
        uint256 _id,
        uint256 _amount,
        bytes calldata _data
    ) external override returns (bytes4) {
        return
            bytes4(
                keccak256(
                    "onERC1155Received(address,address,uint256,uint256,bytes)"
                )
            );
    }

    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) external override returns (bytes4) {
        return
            bytes4(
                keccak256(
                    "onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"
                )
            );
    }

    /**
    @dev Utility function to mint and create sell order for all supply right after that
     */
    function mintAndSetPrice(
        uint256 _initialSupply,
        string calldata _uri,
        uint256 _price,
        bytes calldata _data
    ) external payable returns (uint256) {
        uint256 tokenId = mintWithFee(_initialSupply, _uri, _data);
        return createSellOrder(_price, _initialSupply, tokenId);
    }

    /**
    @dev Payment token MUST be a trusted contract, e.g AstropenToken, to avoid re-entrancy attack
     */
    function fulfillSellOrder(uint256 _orderId, uint256 _amount) external {
        FixedPriceOrder storage order = fixedPriceOrders[_orderId];
        uint256 orderValue = order.price * _amount;
        require(
            paymentToken.balanceOf(msg.sender) >= orderValue,
            "Balance is not enough"
        );
        require(order.amount >= _amount, "Remaining amount is not enough");
        order.amount -= _amount;
        paymentToken.transferFrom(msg.sender, order.seller, orderValue);
        astropenNFT.safeTransferFrom(
            address(this),
            msg.sender,
            order.tokenId,
            _amount,
            ""
        );
        emit SellOrderFulfilled(msg.sender, _orderId, _amount);
    }

    function createSellOrder(
        uint256 _price,
        uint256 _amount,
        uint256 _tokenId
    ) public returns (uint256) {
        require(
            astropenNFT.balanceOf(msg.sender, _tokenId) >= _amount,
            "Token reserve is not enough"
        );
        FixedPriceOrder memory order = FixedPriceOrder(
            msg.sender,
            _tokenId,
            _price,
            _amount
        );
        currentOrderId++;
        fixedPriceOrders[currentOrderId] = order;
        astropenNFT.safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId,
            _amount,
            ""
        );
        emit SellOrderCreated(
            msg.sender,
            _tokenId,
            _price,
            _amount,
            currentOrderId
        );
        return currentOrderId;
    }
}