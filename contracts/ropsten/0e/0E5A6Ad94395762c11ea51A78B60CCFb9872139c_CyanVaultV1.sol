//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./CyanVaultTokenV1.sol";

contract CyanVaultV1 is AccessControl, ReentrancyGuard {
    using SafeMath for uint256;

    bytes32 public constant CYAN_ROLE = keccak256("CYAN_ROLE");
    bytes32 public constant CYAN_PAYMENT_PLAN_ROLE =
        keccak256("CYAN_PAYMENT_PLAN_ROLE");

    event DepositETH(
        address indexed from,
        uint256 indexed ethAmount,
        uint256 indexed tokenAmount
    );
    event LendETH(address indexed to, uint256 indexed amount);
    event Earn(uint256 indexed paymentAmount, uint256 indexed profitAmount);
    event NftDefaulted(
        uint256 indexed unpaidAmount,
        uint256 indexed estimatedPriceOfNFT
    );
    event NftLiquidated(uint256 indexed amount);
    event WithdrawETH(
        address indexed from,
        uint256 indexed ethAmount,
        uint256 indexed tokenAmount
    );

    address _cyanVaultTokenAddress;
    CyanVaultTokenV1 _cyanVaultTokenContract;

    // Remaining amount of ETH
    uint256 REMAINING_AMOUNT;

    // Total loaned amount
    uint256 LOANED_AMOUNT;

    // Total defaulted NFT amount
    uint256 DEFAULTED_NFT_ASSET_AMOUNT;

    constructor(address cyanVaultTokenAddress, address cyanPaymentPlanAddress)
        payable
    {
        console.log(
            "Deploying CyanVault sender: %s, value: %s",
            msg.sender,
            msg.value
        );
        _cyanVaultTokenAddress = cyanVaultTokenAddress;
        _cyanVaultTokenContract = CyanVaultTokenV1(_cyanVaultTokenAddress);

        REMAINING_AMOUNT = msg.value;
        LOANED_AMOUNT = 0;
        DEFAULTED_NFT_ASSET_AMOUNT = 0;

        _setupRole(CYAN_ROLE, msg.sender);
        _setupRole(CYAN_PAYMENT_PLAN_ROLE, cyanPaymentPlanAddress);
    }

    // TODO(Naba): add function that reverts unwanted payment

    // User stackes ETH
    function depositETH() public payable nonReentrant {
        uint256 depositedAmount = msg.value;
        uint256 mintAmount = calculateTokenByETH(depositedAmount);

        _cyanVaultTokenContract.mint(msg.sender, mintAmount);
        REMAINING_AMOUNT += depositedAmount;

        emit DepositETH(msg.sender, depositedAmount, mintAmount);
    }

    // Cyan lends money from Vault to do BNPL
    function lendETH(uint256 amount) public nonReentrant onlyRole(CYAN_ROLE) {
        LOANED_AMOUNT += amount;
        REMAINING_AMOUNT -= amount;
        payable(msg.sender).transfer(amount);

        emit LendETH(msg.sender, amount);
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
            REMAINING_AMOUNT += (amount - LOANED_AMOUNT);
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
            REMAINING_AMOUNT += (unpaidAmount - LOANED_AMOUNT);
            LOANED_AMOUNT = 0;
        }

        emit NftDefaulted(unpaidAmount, estimatedPriceOfNFT);
    }

    // Liquidating defaulted BNPL or PAWN token and tranferred sold amount to Vault
    function liquidateNFT() public payable nonReentrant onlyRole(CYAN_ROLE) {
        uint256 transferredAmount = msg.value;
        if (DEFAULTED_NFT_ASSET_AMOUNT < transferredAmount) {
            REMAINING_AMOUNT += (transferredAmount -
                DEFAULTED_NFT_ASSET_AMOUNT);
            DEFAULTED_NFT_ASSET_AMOUNT = 0;
        } else {
            DEFAULTED_NFT_ASSET_AMOUNT -= transferredAmount;
        }

        emit NftLiquidated(transferredAmount);
    }

    // User unstakes tokenAmount of tokens and gets back ETH
    function withdraw(uint256 amount) public nonReentrant {
        require(amount > 0, "Non-positive token amount");

        uint256 balance = _cyanVaultTokenContract.balanceOf(msg.sender);
        require(balance >= amount, "Check the token balance");

        _cyanVaultTokenContract.burn(msg.sender, amount);

        uint256 withdrawETHAmount = calculateETHByToken(amount);
        REMAINING_AMOUNT -= withdrawETHAmount;

        payable(msg.sender).transfer(withdrawETHAmount);

        emit WithdrawETH(msg.sender, withdrawETHAmount, amount);
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
}