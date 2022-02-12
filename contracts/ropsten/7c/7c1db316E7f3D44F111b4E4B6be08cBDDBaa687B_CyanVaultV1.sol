//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

// import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./CyanVaultTokenV1.sol";

contract CyanVaultV1 is AccessControl, ReentrancyGuard, ERC721Holder, Pausable {
    using SafeMath for uint256;

    bytes32 public constant CYAN_ROLE = keccak256("CYAN_ROLE");
    bytes32 public constant CYAN_PAYMENT_PLAN_ROLE =
        keccak256("CYAN_PAYMENT_PLAN_ROLE");

    event DepositETH(
        address indexed from,
        uint256 ethAmount,
        uint256 tokenAmount
    );
    event LendBNPL(address indexed to, uint256 amount);
    event LendPAWN(address indexed to, uint256 amount);
    event Earn(uint256 paymentAmount, uint256 profitAmount);
    event NftDefaulted(uint256 unpaidAmount, uint256 estimatedPriceOfNFT);
    event NftLiquidated(uint256 defaultedAssetsAmount, uint256 soldAmount);
    event WithdrawETH(
        address indexed from,
        uint256 ethAmount,
        uint256 tokenAmount
    );
    event GetDefaultedNFT(
        address indexed to,
        address indexed contractAddress,
        uint256 indexed tokenId
    );
    event UpdatedDefaultedNFTAssetAmount(uint256 amount);
    // event ReceivedETH(address indexed from, bool isFallback, uint256 amount);

    address _cyanVaultTokenAddress;
    CyanVaultTokenV1 _cyanVaultTokenContract;

    // Safety fund percent
    uint256 _safetyFundPercent;

    // Remaining amount of ETH
    uint256 REMAINING_AMOUNT;

    // Total loaned amount
    uint256 LOANED_AMOUNT;

    // Total defaulted NFT amount
    uint256 DEFAULTED_NFT_ASSET_AMOUNT;

    constructor(
        address cyanVaultTokenAddress,
        address cyanPaymentPlanAddress,
        uint256 safetyFundPercent
    ) payable {
        _cyanVaultTokenAddress = cyanVaultTokenAddress;
        _cyanVaultTokenContract = CyanVaultTokenV1(_cyanVaultTokenAddress);
        _safetyFundPercent = safetyFundPercent;

        LOANED_AMOUNT = 0;
        DEFAULTED_NFT_ASSET_AMOUNT = 0;
        REMAINING_AMOUNT = msg.value;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CYAN_PAYMENT_PLAN_ROLE, cyanPaymentPlanAddress);
    }

    // User stakes ETH
    function depositETH() public payable nonReentrant whenNotPaused {
        uint256 depositedAmount = msg.value;
        uint256 mintAmount = calculateTokenByETH(depositedAmount);

        _cyanVaultTokenContract.mint(msg.sender, mintAmount);
        REMAINING_AMOUNT += depositedAmount;

        emit DepositETH(msg.sender, depositedAmount, mintAmount);
    }

    // Cyan lends money from Vault to do BNPL
    function lendBNPL(address to, uint256 amount)
        public
        nonReentrant
        whenNotPaused
        onlyRole(CYAN_PAYMENT_PLAN_ROLE)
    {
        // Adding 0.3% for admin gas fee coverage
        amount = amount.mul(1003).div(1000);

        uint256 maxWithdrableAmount = getMaxWithdrawableAmount();
        require(amount <= maxWithdrableAmount, "Not enough ETH in the Vault");

        LOANED_AMOUNT += amount;
        REMAINING_AMOUNT -= amount;
        payable(to).transfer(amount);

        emit LendBNPL(to, amount);
    }

    // User lends money from Vault to do PAWN
    function lendPAWN(address to, uint256 amount)
        public
        nonReentrant
        whenNotPaused
        onlyRole(CYAN_PAYMENT_PLAN_ROLE)
    {
        uint256 maxWithdrableAmount = getMaxWithdrawableAmount();
        require(amount <= maxWithdrableAmount, "Not enough ETH in the Vault");

        LOANED_AMOUNT += amount;
        REMAINING_AMOUNT -= amount;
        payable(to).transfer(amount);

        emit LendPAWN(to, amount);
    }

    // Cyan Payment Plan contract transfers paid amount back to Vault
    function earn(uint256 amount, uint256 profit)
        public
        payable
        nonReentrant
        onlyRole(CYAN_PAYMENT_PLAN_ROLE)
    {
        require(msg.value == amount + profit, "Wrong tranfer amount");

        REMAINING_AMOUNT += msg.value;
        if (LOANED_AMOUNT >= amount) {
            LOANED_AMOUNT -= amount;
        } else {
            LOANED_AMOUNT = 0;
        }

        emit Earn(amount, profit);
    }

    // When BNPL or PAWN plan defaults
    function nftDefaulted(uint256 unpaidAmount, uint256 estimatedPriceOfNFT)
        public
        nonReentrant
        onlyRole(CYAN_PAYMENT_PLAN_ROLE)
    {
        DEFAULTED_NFT_ASSET_AMOUNT += estimatedPriceOfNFT;

        if (LOANED_AMOUNT >= unpaidAmount) {
            LOANED_AMOUNT -= unpaidAmount;
        } else {
            LOANED_AMOUNT = 0;
        }

        emit NftDefaulted(unpaidAmount, estimatedPriceOfNFT);
    }

    // Liquidating defaulted BNPL or PAWN token and tranferred sold amount to Vault
    function liquidateNFT(uint256 totalDefaultedNFTAmount)
        public
        payable
        whenNotPaused
        onlyRole(CYAN_ROLE)
    {
        REMAINING_AMOUNT += msg.value;
        DEFAULTED_NFT_ASSET_AMOUNT = totalDefaultedNFTAmount;

        emit NftLiquidated(msg.value, totalDefaultedNFTAmount);
    }

    // User unstakes tokenAmount of tokens and gets back ETH
    function withdraw(uint256 amount) public nonReentrant whenNotPaused {
        require(amount > 0, "Non-positive token amount");

        uint256 balance = _cyanVaultTokenContract.balanceOf(msg.sender);
        require(balance >= amount, "Check the token balance");

        uint256 withdrawableTokenBalance = getWithdrawableBalance(msg.sender);
        require(
            amount <= withdrawableTokenBalance,
            "Not enough active balance in Cyan Vault"
        );

        uint256 withdrawETHAmount = calculateETHByToken(amount);

        _cyanVaultTokenContract.burn(msg.sender, amount);
        REMAINING_AMOUNT -= withdrawETHAmount;
        payable(msg.sender).transfer(withdrawETHAmount);

        emit WithdrawETH(msg.sender, withdrawETHAmount, amount);
    }

    // Cyan updating total amount of defaulted NFT assets
    function updateDefaultedNFTAssetAmount(uint256 amount)
        public
        whenNotPaused
        onlyRole(CYAN_ROLE)
    {
        DEFAULTED_NFT_ASSET_AMOUNT = amount;
        emit UpdatedDefaultedNFTAssetAmount(amount);
    }

    // Get defaulted NFT from Vault to Cyan Admin account
    function getDefaultedNFT(address contractAddress, uint256 tokenId)
        public
        nonReentrant
        whenNotPaused
        onlyRole(CYAN_ROLE)
    {
        require(contractAddress != address(0), "Zero contract address");

        IERC721 originalContract = IERC721(contractAddress);

        require(
            originalContract.ownerOf(tokenId) == address(this),
            "Vault isn't owner of the token"
        );

        originalContract.safeTransferFrom(address(this), msg.sender, tokenId);

        emit GetDefaultedNFT(msg.sender, contractAddress, tokenId);
    }

    function getWithdrawableBalance(address user)
        public
        view
        returns (uint256)
    {
        uint256 tokenBalance = _cyanVaultTokenContract.balanceOf(user);
        uint256 ethAmountForToken = calculateETHByToken(tokenBalance);
        uint256 maxWithdrawableAmount = getMaxWithdrawableAmount();

        if (ethAmountForToken <= maxWithdrawableAmount) {
            return tokenBalance;
        }
        return calculateTokenByETH(maxWithdrawableAmount);
    }

    function getMaxWithdrawableAmount() public view returns (uint256) {
        uint256 util = LOANED_AMOUNT
            .add(DEFAULTED_NFT_ASSET_AMOUNT)
            .mul(_safetyFundPercent)
            .div(100);
        if (REMAINING_AMOUNT > util) {
            return REMAINING_AMOUNT.sub(util);
        }
        return 0;
    }

    function getCurrentAssetAmounts()
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (REMAINING_AMOUNT, LOANED_AMOUNT, DEFAULTED_NFT_ASSET_AMOUNT);
    }

    function calculateTokenByETH(uint256 amount) public view returns (uint256) {
        uint256 totalETH = REMAINING_AMOUNT +
            LOANED_AMOUNT +
            DEFAULTED_NFT_ASSET_AMOUNT;
        uint256 totalToken = _cyanVaultTokenContract.totalSupply();

        return (amount.mul(totalToken)).div(totalETH);
    }

    function calculateETHByToken(uint256 amount) public view returns (uint256) {
        uint256 totalETH = REMAINING_AMOUNT +
            LOANED_AMOUNT +
            DEFAULTED_NFT_ASSET_AMOUNT;
        uint256 totalToken = _cyanVaultTokenContract.totalSupply();

        return (amount.mul(totalETH)).div(totalToken);
    }

    function updateSafetyFundPercent(uint256 safetyFundPercent)
        public
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            safetyFundPercent < 100,
            "Safety fund percent must be less than 100"
        );
        _safetyFundPercent = safetyFundPercent;
    }

    function withdrawAirDroppedERC20(address contractAddress, uint256 amount)
        public
        nonReentrant
        onlyRole(CYAN_ROLE)
    {
        IERC20 erc20Contract = IERC20(contractAddress);
        require(
            erc20Contract.balanceOf(address(this)) >= amount,
            "ERC20 balance not enough"
        );
        erc20Contract.transfer(msg.sender, amount);
    }

    function withdrawApprovedERC20(
        address contractAddress,
        address from,
        uint256 amount
    ) public nonReentrant onlyRole(CYAN_ROLE) {
        IERC20 erc20Contract = IERC20(contractAddress);
        require(
            erc20Contract.allowance(from, address(this)) >= amount,
            "ERC20 allowance not enough"
        );
        erc20Contract.transferFrom(from, msg.sender, amount);
    }

    // fallback() external payable {
    //     emit ReceivedETH(msg.sender, true, msg.value);
    // }

    // receive() external payable {
    //     emit ReceivedETH(msg.sender, false, msg.value);
    // }

    function pause() public nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}