// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;
pragma abicoder v2;

import './IDelegate.sol';
import './IWETHUpgradable.sol';
import './MarketConsts.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';

contract MarketV3 is
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct OrderItem {
        uint256 network;
        uint256 intentFlag;
        uint256 delegateType;
        uint256 price;
        uint256 deadline;
        IERC20Upgradeable currency;
        bytes data;
        bytes dataMask;
    }

    struct Order {
        uint256 salt;
        OrderItem[] items;
        address user;
        bytes signature;
    }

    struct Fee {
        uint256 percentage;
        address to;
    }

    struct SettleDetail {
        Consts.Op op;
        uint256 orderIdx;
        uint256 itemIdx;
        uint256 price;
        bytes32 itemHash;
        IDelegate executionDelegate;
        bytes dataReplacement;
        uint64 bidIncentivePct;
        uint64 aucMinIncrementPct;
        uint64 aucIncDurationSecs;
        Fee[] fees;
    }

    struct SettleShared {
        uint256 salt;
        uint256 deadline;
        uint256 amountToEth;
        uint256 amountToWeth;
        address user;
    }

    struct RunInput {
        Order[] orders;
        SettleDetail[] details;
        SettleShared shared;
        bytes signature;
    }

    struct OngoingAuction {
        uint256 price;
        uint256 netPrice;
        uint256 endAt;
        address bidder;
    }

    event EvMarketFee(bytes32 itemHash, address currency, address to, uint256 amount);
    event EvProfit(bytes32 itemHash, address currency, address to, uint256 amount);
    event EvPayment(bytes32 itemHash, address currency, address from, uint256 amount);
    event EvAuctionRefund(bytes32 itemHash, address currency, address to, uint256 amount);
    event EvInventory(
        bytes32 itemHash,
        address maker,
        address taker,
        uint256 orderSalt,
        uint256 settleSalt,
        OrderItem item,
        SettleDetail detail
    );
    event EvSigner(address signer, bool isRemoval);
    event EvDelegate(address delegate, bool isRemoval);
    event EvFeeCapUpdate(uint256 newValue);

    mapping(address => bool) public delegates;
    mapping(address => bool) public signers;

    mapping(bytes32 => Consts.InvStatus) public inventoryStatus;
    mapping(bytes32 => OngoingAuction) public ongoingAuctions;

    uint256 public constant RATE_BASE = 1e6;
    uint256 public networkId;
    uint256 public feeCapPct;
    IWETHUpgradable public weth;

    receive() external payable {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function initialize(
        uint256 networkId_,
        uint256 feeCapPct_,
        address weth_
    ) public initializer {
        networkId = networkId_;
        feeCapPct = feeCapPct_;
        weth = IWETHUpgradable(weth_);

        __ReentrancyGuard_init_unchained();
        __Pausable_init_unchained();
        __Ownable_init_unchained();
    }

    function updateFeeCap(uint256 val) public virtual onlyOwner {
        feeCapPct = val;
        emit EvFeeCapUpdate(val);
    }

    function updateSigners(address[] memory adds, address[] memory removes)
        public
        virtual
        onlyOwner
    {
        for (uint256 i = 0; i < adds.length; i++) {
            signers[adds[i]] = true;
            emit EvSigner(adds[i], false);
        }
        for (uint256 i = 0; i < removes.length; i++) {
            delete signers[removes[i]];
            emit EvSigner(removes[i], true);
        }
    }

    function updateDelegates(address[] memory adds, address[] memory removes)
        public
        virtual
        onlyOwner
    {
        for (uint256 i = 0; i < adds.length; i++) {
            delegates[adds[i]] = true;
            emit EvDelegate(adds[i], false);
        }
        for (uint256 i = 0; i < removes.length; i++) {
            delete delegates[removes[i]];
            emit EvDelegate(removes[i], true);
        }
    }

    function run(RunInput memory input) public payable virtual nonReentrant whenNotPaused {
        require(input.shared.deadline > block.timestamp, 'input deadline reached');
        require(msg.sender == input.shared.user, 'sender does not match');
        _verifyInputSignature(input);

        uint256 amountEth = msg.value;
        if (input.shared.amountToWeth > 0) {
            uint256 amt = input.shared.amountToWeth;
            weth.deposit{value: amt}();
            SafeERC20Upgradeable.safeTransfer(weth, msg.sender, amt);
            amountEth -= amt;
        }
        if (input.shared.amountToEth > 0) {
            uint256 amt = input.shared.amountToEth;
            SafeERC20Upgradeable.safeTransferFrom(weth, msg.sender, address(this), amt);
            weth.withdraw(amt);
            amountEth += amt;
        }

        for (uint256 i = 0; i < input.orders.length; i++) {
            Order memory order = input.orders[i];
            require(order.user != address(0), 'invalid order.user');
            _verifyOrderSignature(order);
        }

        for (uint256 i = 0; i < input.details.length; i++) {
            SettleDetail memory detail = input.details[i];
            Order memory order = input.orders[detail.orderIdx];
            amountEth -= _run(order, input.shared, detail);
        }
        if (amountEth > 0) {
            payable(msg.sender).transfer(amountEth);
        }
    }

    function _run(
        Order memory order,
        SettleShared memory shared,
        SettleDetail memory detail
    ) internal virtual returns (uint256) {
        uint256 nativeAmount = 0;

        OrderItem memory item = order.items[detail.itemIdx];
        bytes32 itemHash = keccak256(abi.encode(order.salt, order.user, item, detail.itemIdx));

        require(itemHash == detail.itemHash, 'item hash does not match');
        require(item.network == networkId, 'wrong network');
        require(inventoryStatus[itemHash] != Consts.InvStatus.CANCELLED, 'order cancelled');
        require(
            address(detail.executionDelegate) != address(0) &&
                delegates[address(detail.executionDelegate)],
            'unknown delegate'
        );

        bytes memory data = item.data;
        if (item.dataMask.length > 0 && detail.dataReplacement.length > 0) {
            _arrayReplace(data, detail.dataReplacement, item.dataMask);
        }

        if (detail.op == Consts.Op.COMPLETE_SELL_OFFER) {
            require(_hasFlag(item.intentFlag, IntentFlags.SELL), 'sell flag required');
            _assertDelegation(item, detail);
            require(item.deadline > block.timestamp, 'deadline reached');
            require(detail.price >= item.price, 'underpaid');

            nativeAmount = _takePayment(itemHash, item.currency, order.user, detail.price);
            require(
                detail.executionDelegate.executeSell(order.user, shared.user, data),
                'delegation error'
            );

            _distributeFeeAndProfit(
                itemHash,
                order.user,
                item.currency,
                detail,
                detail.price,
                detail.price
            );
            inventoryStatus[itemHash] = Consts.InvStatus.COMPLETE;
        } else if (detail.op == Consts.Op.COMPLETE_BUY_OFFER) {
            require(_hasFlag(item.intentFlag, IntentFlags.BUY), 'buy flag required');
            _assertDelegation(item, detail);
            require(item.deadline > block.timestamp, 'deadline reached');
            require(!_isNative(item.currency), 'native token not supported');
            require(item.price == detail.price, 'price not match');

            nativeAmount = _takePayment(itemHash, item.currency, order.user, detail.price);
            require(
                detail.executionDelegate.executeBuy(shared.user, order.user, data),
                'delegation error'
            );

            _distributeFeeAndProfit(
                itemHash,
                shared.user,
                item.currency,
                detail,
                detail.price,
                detail.price
            );
            inventoryStatus[itemHash] = Consts.InvStatus.COMPLETE;
        } else if (detail.op == Consts.Op.CANCEL_OFFER) {
            require(inventoryStatus[itemHash] == Consts.InvStatus.NEW, 'unable to cancel');
            require(item.deadline > block.timestamp, 'deadline reached');
            inventoryStatus[itemHash] = Consts.InvStatus.CANCELLED;
        } else if (detail.op == Consts.Op.BID) {
            require(_hasFlag(item.intentFlag, IntentFlags.AUCTION), 'auction flag required');
            _assertDelegation(item, detail);
            bool firstBid = false;
            if (ongoingAuctions[itemHash].bidder == address(0)) {
                require(item.deadline > block.timestamp, 'auction ended');
                require(detail.price >= item.price, 'underpaid');

                firstBid = true;
                ongoingAuctions[itemHash] = OngoingAuction({
                    price: detail.price,
                    netPrice: detail.price,
                    bidder: shared.user,
                    endAt: item.deadline
                });
                inventoryStatus[itemHash] = Consts.InvStatus.AUCTION;

                require(
                    detail.executionDelegate.executeBid(order.user, address(0), shared.user, data),
                    'delegation error'
                );
            }

            OngoingAuction storage auc = ongoingAuctions[itemHash];
            require(auc.endAt > block.timestamp, 'auction ended');

            nativeAmount = _takePayment(itemHash, item.currency, shared.user, detail.price);

            if (!firstBid) {
                require(
                    detail.price >= (auc.price * detail.aucMinIncrementPct) / RATE_BASE,
                    'underbid'
                );

                uint256 bidRefund = auc.netPrice;
                uint256 incentive = (detail.price * detail.bidIncentivePct) / RATE_BASE;
                if (bidRefund + incentive > 0) {
                    _transferTo(item.currency, auc.bidder, bidRefund + incentive);
                    emit EvAuctionRefund(
                        itemHash,
                        address(item.currency),
                        auc.bidder,
                        bidRefund + incentive
                    );
                }

                require(
                    detail.executionDelegate.executeBid(order.user, auc.bidder, shared.user, data),
                    'delegation error'
                );

                auc.price = detail.price;
                auc.netPrice = detail.price - incentive;
                auc.bidder = shared.user;
            }

            if (block.timestamp + detail.aucIncDurationSecs > auc.endAt) {
                auc.endAt += detail.aucIncDurationSecs;
            }
        } else if (
            detail.op == Consts.Op.REFUND_AUCTION ||
            detail.op == Consts.Op.REFUND_AUCTION_STUCK_ITEM
        ) {
            require(inventoryStatus[itemHash] == Consts.InvStatus.AUCTION);
            OngoingAuction storage auc = ongoingAuctions[itemHash];

            if (auc.netPrice > 0) {
                _transferTo(item.currency, auc.bidder, auc.netPrice);
                emit EvAuctionRefund(itemHash, address(item.currency), auc.bidder, auc.netPrice);
            }
            _assertDelegation(item, detail);

            if (detail.op == Consts.Op.REFUND_AUCTION) {
                require(
                    detail.executionDelegate.executeAuctionRefund(order.user, auc.bidder, data),
                    'delegation error'
                );
            }
            delete ongoingAuctions[itemHash];
            inventoryStatus[itemHash] = Consts.InvStatus.REFUNDED;
        } else if (detail.op == Consts.Op.COMPLETE_AUCTION) {
            require(inventoryStatus[itemHash] == Consts.InvStatus.AUCTION);
            _assertDelegation(item, detail);
            OngoingAuction storage auc = ongoingAuctions[itemHash];
            require(block.timestamp >= auc.endAt, 'auction not finished yet');

            require(
                detail.executionDelegate.executeAuctionComplete(order.user, auc.bidder, data),
                'delegation error'
            );
            _distributeFeeAndProfit(
                itemHash,
                order.user,
                item.currency,
                detail,
                auc.price,
                auc.netPrice
            );

            inventoryStatus[itemHash] = Consts.InvStatus.COMPLETE;
            delete ongoingAuctions[itemHash];
        } else {
            revert('unknown op');
        }

        emit EvInventory(itemHash, order.user, shared.user, order.salt, shared.salt, item, detail);
        return nativeAmount;
    }

    function _hasFlag(uint256 a, uint256 flag) internal pure returns (bool) {
        return (a & flag) > 0;
    }

    function _assertDelegation(OrderItem memory item, SettleDetail memory detail)
        internal
        view
        virtual
    {
        require(
            detail.executionDelegate.delegateType() == item.delegateType,
            'delegation type error'
        );
    }

    // modifies `src`
    function _arrayReplace(
        bytes memory src,
        bytes memory replacement,
        bytes memory mask
    ) internal view virtual {
        require(src.length == replacement.length);
        require(src.length == mask.length);

        // src[i] = mask[i] && replacement[i] || src[i]
        for (uint256 i = 0; i < src.length; i++) {
            if (mask[i] != 0) {
                src[i] = replacement[i];
            }
        }
    }

    function _verifyInputSignature(RunInput memory input) internal view virtual {
        bytes32 hash = keccak256(abi.encode(input.shared, input.details));
        address signer = ECDSA.recover(ECDSA.toEthSignedMessageHash(hash), input.signature);
        require(signers[signer], 'Input signature error');
    }

    function _verifyOrderSignature(Order memory order) internal view virtual {
        bytes32 orderHash = keccak256(abi.encode(order.salt, order.user, order.items));
        address orderSigner = ECDSA.recover(
            ECDSA.toEthSignedMessageHash(orderHash),
            order.signature
        );
        require(orderSigner == order.user, 'Order signature does not match');
    }

    function _isNative(IERC20Upgradeable currency) internal view virtual returns (bool) {
        return address(currency) == address(0);
    }

    function _takePayment(
        bytes32 itemHash,
        IERC20Upgradeable currency,
        address from,
        uint256 amount
    ) internal virtual returns (uint256) {
        emit EvPayment(itemHash, address(currency), from, amount);
        if (amount > 0) {
            if (_isNative(currency)) {
                return amount;
            } else {
                currency.safeTransferFrom(from, address(this), amount);
            }
        }
        return 0;
    }

    function _transferTo(
        IERC20Upgradeable currency,
        address to,
        uint256 amount
    ) internal virtual {
        if (amount > 0) {
            if (_isNative(currency)) {
                AddressUpgradeable.sendValue(payable(to), amount);
            } else {
                currency.safeTransfer(to, amount);
            }
        }
    }

    function _distributeFeeAndProfit(
        bytes32 itemHash,
        address seller,
        IERC20Upgradeable currency,
        SettleDetail memory sd,
        uint256 price,
        uint256 netPrice
    ) internal virtual {
        require(price >= netPrice, 'price error');

        uint256 payment = netPrice;
        uint256 totalFeePct;

        for (uint256 i = 0; i < sd.fees.length; i++) {
            Fee memory fee = sd.fees[i];
            totalFeePct += fee.percentage;
            uint256 amount = (price * fee.percentage) / RATE_BASE;
            payment -= amount;
            _transferTo(currency, fee.to, amount);
            emit EvMarketFee(itemHash, address(currency), fee.to, amount);
        }

        require(feeCapPct >= totalFeePct, 'total fee cap exceeded');

        _transferTo(currency, seller, payment);
        emit EvProfit(itemHash, address(currency), seller, payment);
    }
}