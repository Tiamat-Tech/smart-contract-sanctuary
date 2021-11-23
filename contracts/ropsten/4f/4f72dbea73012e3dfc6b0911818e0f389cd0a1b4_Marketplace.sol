// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "./interfaces/IMarketplace.sol";
import "./interfaces/IFactory.sol";
import "./abstract/Exchange.sol";

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract Marketplace is Exchange, IMarketplace {
    using SafeERC20 for IERC20;
    address public factory;

    uint256 public pendingWithdrawalAmount;
    mapping(address => mapping(uint256 => Lot)) marketplace;
    mapping(address => uint256) public pendingWithdrawals;
    mapping(address => bool) public whitelistedTokens;

    // Default sell fee is 2.5%
    uint256 public sellFee = 250;

    constructor(address _factory, address _uniswapV3Quoter, address _WETH9)
    Exchange(_uniswapV3Quoter, _WETH9) {
        require(_factory != address(0), "ZFA");
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, _factory);

        factory = _factory;
        emit SellFeeChanged(0, sellFee);
    }

    receive() external payable {
        require(msg.sender == address(WETH9), "!WETH");
    }

    fallback() external payable {
        require(msg.sender == address(WETH9), "!WETH");
    }

    /// @inheritdoc IMarketplace
    function sell(ITangibleNFT nft, uint256 tokenId, uint256 amount, uint256 price) external override {
        // gas saving
        address seller = msg.sender;
        marketplace[address(nft)][tokenId] = Lot(nft, tokenId, seller, amount, price, true);

        emit Selling(seller, address(nft), tokenId, amount, price);
        IERC1155(nft).safeTransferFrom(seller, address(this), tokenId, amount, "");
    }

    /// @inheritdoc IMarketplace
    function stopSale(ITangibleNFT nft, uint256 tokenId) external override {
        address seller = msg.sender;
        // gas saving
        Lot memory lot = marketplace[address(nft)][tokenId];
        require(lot.seller == seller, "Not a seller");

        emit StopSelling(seller, address(nft), tokenId, lot.amount);
        delete marketplace[address(nft)][tokenId];
        IERC1155(nft).safeTransferFrom(address(this), lot.seller, lot.tokenId, lot.amount, "");
    }

    /// @inheritdoc IMarketplace
    function buy(ITangibleNFT nft, uint256 tokenId, uint256 amount) external override {
        _buy(nft, tokenId, amount, msg.sender);
    }

    function _buy(ITangibleNFT nft, uint256 tokenId, uint256 amount, address payer) internal {
        address buyer = msg.sender;
        // gas saving

        Lot memory lot = marketplace[address(nft)][tokenId];
        require(lot.seller != address(0), "No lot");
        require(lot.minted, "Not minted");
        require(lot.amount >= amount, "Not enough");

        uint256 cost = lot.price * amount;
        IFactory(factory).USDC().safeTransferFrom(payer, address(this), cost);
        _bought(lot.seller, cost);

        emit Bought(buyer, address(nft), tokenId, lot.seller, amount, lot.price);
        if (lot.amount > amount) {
            marketplace[address(nft)][tokenId].amount -= amount;
        } else {
            delete marketplace[address(nft)][tokenId];
        }

        IERC1155(nft).safeTransferFrom(address(this), buyer, tokenId, amount, "");
    }

    /// @inheritdoc IMarketplace
    function bought(address vendor, uint256 amount) external override onlyFactory() {
        _bought(vendor, amount);
    }

    function _bought(address vendor, uint256 amount) internal {
        if (sellFee > 0) {
            // if there is fee set, decrease amount by the fee
            amount = amount - (amount * sellFee / 10000);
        }

        // record payment to vendor's withdrawal balance
        pendingWithdrawals[vendor] += amount;
        pendingWithdrawalAmount += amount;
    }

    /// @inheritdoc IMarketplace
    function buyForETH(ITangibleNFT nft, uint256 tokenId, uint256 amount) external override payable {
        uint256 cost = marketplace[address(nft)][tokenId].price * amount;
        address USDC = address(IFactory(factory).USDC());
        uint256 maxAmountIn = quoteIn(address(WETH9), USDC, cost);

        require(msg.value >= maxAmountIn, "Not enough paid");

        // exchange sent ETH to WETH9
        WETH9.deposit{value: msg.value}();

        // exchange WETH9 to USDC. USDC will be received on the contract's address
        uint256 amountIn = exchange(address(WETH9), USDC, cost, maxAmountIn);

        // buy NFTs to msg.sender but pay from contract's address
        _buy(nft, tokenId, amount, address(this));

        if (maxAmountIn > amountIn) {
            uint256 difference = msg.value - amountIn;
            // withdraw the difference
            WETH9.withdraw(difference);

            // return ETH if was taken less
            msg.sender.call{value: difference}("");
        }
    }

    /// @inheritdoc IMarketplace
    function buyForOtherToken(ITangibleNFT nft, address token, uint256 tokenId, uint256 amount) external override {
        require(whitelistedTokens[token], "NWT");

        uint256 cost = marketplace[address(nft)][tokenId].price * amount;
        address USDC = address(IFactory(factory).USDC());
        uint256 maxAmountIn = quoteIn(token, USDC, cost);

        IERC20(token).safeTransferFrom(msg.sender, address(this), maxAmountIn);

        // exchange token to USDC. USDC will be received on the contract's address
        uint256 amountIn = exchange(token, USDC, cost, maxAmountIn);

        if (maxAmountIn > amountIn) {
            // return tokenIn if was taken less
            IERC20(token).transfer(msg.sender, maxAmountIn - amountIn);
        }

        // buy NFTs to msg.sender but pay from contract's address
        _buy(nft, tokenId, amount, address(this));
    }

    function whitelistTokenForPayment(address token) external onlyAdmin {
        require(!whitelistedTokens[token], "Whitelisted");
        whitelistedTokens[token] = true;
        emit TokenPaymentWhitelisted(token);
    }

    function blacklistTokenForPayment(address token) external onlyAdmin {
        require(whitelistedTokens[token], "Blacklisted");
        delete whitelistedTokens[token];
        emit TokenPaymentBlacklisted(token);
    }

    function withdraw() external {
        uint amount = 0;
        IERC20 USDC = IFactory(factory).USDC();

        if (isAdmin(msg.sender)) {
            uint256 balance = USDC.balanceOf(address(this));
            amount = balance - pendingWithdrawalAmount;
        } else {
            amount = pendingWithdrawals[msg.sender];
        }

        require(amount > 0, "Zero");

        USDC.transfer(msg.sender, amount);
    }

    function withdrawTokens(IERC20 token) external onlyAdmin {
        require(address(token) != address(IFactory(factory).USDC()), "USDC");

        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "Zero");

        token.transfer(msg.sender, balance);
    }

    function setSellFee(uint256 _sellFee) external onlyAdmin {
        require(sellFee != _sellFee, "SSF");
        emit SellFeeChanged(sellFee, _sellFee);
        sellFee = _sellFee;
    }
}