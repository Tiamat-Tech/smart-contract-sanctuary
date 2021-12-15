//SPDX-License-Identifier: un-licensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERCX/Interface/IERCX.sol";

contract VeraFinance721 is ERC721Holder, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    uint128 public _tradeCounter;
    IERCX _ERCX;

    // 10 => 1%
    uint16 _fee;

    struct NftFinance {
        uint128 id;
        uint256 startTime;
        address nftContract;
        uint256 nftId;
        uint128 price;
        uint256 downPayment; // 10 i.e 1 % of the price
        uint256 duration; // i.e 50 days
        uint256 paymentPeriod; // i.e every 5 days
        bytes32 status; // i.e Open, Pending, Executed, Canceled
        address sellerAddress;
        uint8 payment;
        uint256 nextPayment;
    }

    mapping(uint256 => NftFinance) _idToNftFinance;
    mapping(uint8 => address) _paymentToken;
    mapping(uint256 => uint256) _amountPayed;
    mapping(uint128 => uint256) idToPeriodicPayment;
    mapping(uint256 => address) idTobuyer;
    mapping(uint256 => bool) _isDownPaymentPayed;

    event NftListed(
        uint256 id,
        address nftContract,
        uint256 nftId,
        uint256 price,
        uint256 downPayment,
        uint256 duration,
        uint256 paymentPeriod,
        bytes32 status,
        address sellerAddress,
        uint8 payment
    );
    event DownPayment(uint256 id, bytes32 status);
    event PeriodPayment(uint256 id, uint256 totalPayment, uint256 paymentPaid);
    event NftTransferred(uint256 id, bytes32 status);
    event NftCanceled(uint256 id, bytes32 status);

    constructor(uint16 fee_, IERCX ERCX_) ReentrancyGuard() {
        _fee = fee_;
        _ERCX = ERCX_;
        _tradeCounter = 0;
    }

    function setFee(uint16 fee) external onlyOwner {
        //cannot set fee more than 1000 pt
        require(fee < 1000, "fee exceeds 100pct");
        _fee = fee;
    }

    function unListNft(uint256 id) external {
        NftFinance storage nft = _idToNftFinance[id];

        require(
            msg.sender == nft.sellerAddress,
            "NftFinance: you are not the seller"
        );
        require(
            _isDownPaymentPayed[id] == false,
            "NftFinance: downpayment is payed"
        );

        IERC721 token = IERC721(nft.nftContract);

        token.safeTransferFrom(
            address(this),
            payable(nft.sellerAddress),
            nft.nftId
        );
        _ERCX.revokeLien(id);

        emit NftCanceled(id, "Canceled");
        delete _idToNftFinance[id];
        delete idTobuyer[id];
        delete _isDownPaymentPayed[id];
        delete _amountPayed[id];
    }

    function calculateFee(uint256 price) internal view returns (uint256) {
        return price.mul(_fee).div(1000);
    }

    function calculateDownPayment(
        uint256 _price,
        uint256 _downPaymentPercentage
    ) internal pure returns (uint256) {
        return _price.mul(_downPaymentPercentage).div(1000);
    }

    function setPeriodicPayment(
        uint256 _price,
        uint256 _downPaymentPercentage,
        uint256 numberOfPeriod
    ) internal {
        uint256 downPayment = _price.sub(
            calculateDownPayment(_price, _downPaymentPercentage)
        );
        idToPeriodicPayment[_tradeCounter] = downPayment.div(numberOfPeriod);
    }

    function listNft(
        uint128 nftId,
        uint128 price,
        uint256 paymentPeriod,
        uint256 downPayment,
        uint256 duration,
        address nftContract,
        uint8 paymentCurrency
    ) external {
        require(
            msg.sender != address(0),
            "NftFinance: msg.sender is zero address"
        );
        require(
            paymentPeriod != 0,
            "NftFinance: Payment Period can not be zero"
        );
        setPeriodicPayment(price, downPayment, duration.div(paymentPeriod));

        IERC721 token = IERC721(nftContract);
        token.safeTransferFrom(payable(msg.sender), address(this), nftId);
        _ERCX.setLien(_tradeCounter);

        _idToNftFinance[_tradeCounter] = NftFinance({
            id: _tradeCounter,
            startTime: 0,
            nftContract: nftContract,
            nftId: nftId,
            price: price,
            downPayment: downPayment,
            duration: duration,
            paymentPeriod: paymentPeriod,
            status: "Open",
            sellerAddress: msg.sender,
            payment: paymentCurrency,
            nextPayment: 0
        });
        _amountPayed[_tradeCounter] = 0;
        _isDownPaymentPayed[_tradeCounter] = false;

        emit NftListed(
            _tradeCounter,
            nftContract,
            nftId,
            price,
            downPayment,
            duration,
            paymentPeriod,
            "Open",
            msg.sender,
            paymentCurrency
        );
        _tradeCounter += 1;
    }

    function payDownpayment(uint256 id, uint128 amount) external nonReentrant {
        NftFinance storage nft = _idToNftFinance[id];
        require(
            msg.sender != address(0) && msg.sender != nft.sellerAddress,
            "NftFinance: msg.sender is zero address or the owner is trying to buy his own nft"
        );

        require(
            _isDownPaymentPayed[id] == false,
            "NftFinance: down payment payed"
        );
        uint256 downPayment = calculateDownPayment(nft.price, nft.downPayment);
        uint256 fee = calculateFee(nft.price);
        uint256 total = downPayment.add(fee);
        require(total == amount, "NftFinance: unsufficient amount send");

        address _currencyAddress = _paymentToken[nft.payment];
        IERC20 erc20Currency = IERC20(_currencyAddress);
        erc20Currency.transferFrom(msg.sender, nft.sellerAddress, downPayment);
        erc20Currency.transferFrom(msg.sender, owner(), fee);

        _ERCX.safeTransferUser(owner(), msg.sender, id);

        nft.startTime = block.timestamp;
        nft.nextPayment = nft.startTime + nft.paymentPeriod;
        _amountPayed[id] += total;
        _isDownPaymentPayed[id] = true;
        nft.status = "Downpayment paid";
        idTobuyer[id] = msg.sender;

        emit DownPayment(id, "Downpayment paid");
    }

    function sendPeriodicPayment(uint128 id, uint128 periodicPayment)
        external
        nonReentrant
        returns (bool)
    {
        NftFinance storage nft = _idToNftFinance[id];

        address _currencyAddress = _paymentToken[nft.payment];
        IERC20 erc20Currency = IERC20(_currencyAddress);

        uint256 result = nft.price -
            calculateDownPayment(nft.price, nft.downPayment);
        require(
            idToPeriodicPayment[id] <= periodicPayment &&
                periodicPayment <= result,
            "NftFinance: in-correct periodic payment"
        );
        require(
            msg.sender != address(0) && msg.sender != nft.sellerAddress,
            "NftFinance: not authorized"
        );
        if (block.timestamp > nft.startTime + nft.duration) {
            revert("NftFinance: duration ended");
        }
        require(msg.sender == idTobuyer[id], "NftFinance: buyer only");

        if (block.timestamp > nft.nextPayment) {
            revert("NftFinance: periodic payment missed");
        }

        uint256 fee = calculateFee(nft.price);
        if (_amountPayed[id] >= (nft.price + fee)) {
            revert("NftFinance: amount paid. claim nft now");
        }

        erc20Currency.transferFrom(
            msg.sender,
            nft.sellerAddress,
            periodicPayment
        );
        _amountPayed[id] += periodicPayment;
        nft.nextPayment += nft.paymentPeriod;

        emit PeriodPayment(id, nft.price + fee, _amountPayed[id]);
        return true;
    }

    function ownerClaimNft(uint256 id) external nonReentrant {
        NftFinance storage nft = _idToNftFinance[id];
        require(
            _isDownPaymentPayed[id] == true,
            "NftFinance: downpayment is payed you can not un list the Nft"
        );

        require(
            block.timestamp > nft.startTime + nft.duration,
            "NftFinance: you can not claim your Nft until buyer fails to pay the full Nft price"
        );
        require(
            msg.sender == nft.sellerAddress,
            "NftFinance: you are not the seller"
        );
        IERC721 token = IERC721(nft.nftContract);

        token.safeTransferFrom(
            address(this),
            payable(nft.sellerAddress),
            nft.nftId
        );

        _ERCX.safeTransferUser(idTobuyer[id], owner(), id);
        _ERCX.revokeLien(id);

        emit NftTransferred(id, "seller claimed NFT");
        delete _idToNftFinance[id];
        delete idTobuyer[id];
        delete _isDownPaymentPayed[id];
        delete _amountPayed[id];
    }

    function claimNft(uint256 id) external {
        require(
            msg.sender == idTobuyer[id],
            "NftFinance: you can't claim this Nft"
        );
        NftFinance storage nft = _idToNftFinance[id];
        uint256 fee = calculateFee(nft.price);
        require(
            _amountPayed[id] == (nft.price + fee),
            "NftFinance: you have not payed full payment yet"
        );
        IERC721 token = IERC721(nft.nftContract);
        token.safeTransferFrom(address(this), payable(msg.sender), nft.nftId);

        _ERCX.safeTransferUser(msg.sender, owner(), id);
        _ERCX.revokeLien(id);

        emit NftTransferred(id, "Buyer claimed NFT");
        delete _idToNftFinance[id];
        delete idTobuyer[id];
        delete _isDownPaymentPayed[id];
        delete _amountPayed[id];
    }

    function getPeriodicAmount(uint8 tradeID) external view returns (uint256) {
        return idToPeriodicPayment[tradeID];
    }

    function idToNftFinance(uint128 id)
        external
        view
        returns (NftFinance memory)
    {
        return _idToNftFinance[id];
    }

    function setPaymentToken(uint8 index, address currencyAddress)
        external
        onlyOwner
    {
        require(
            _paymentToken[index] == address(0),
            "NftFinance: cannot reset the address"
        );
        _paymentToken[index] = currencyAddress;
    }

    function getPaymentToken(uint8 paymentID) public view returns (address) {
        return _paymentToken[paymentID];
    }
}