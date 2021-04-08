// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/external/yearn/IVault.sol";
import "./AdapterBase.sol";

// https://docs.yearn.finance/developers/yvaults-documentation/vault-interfaces#ivault
contract YvdaiAdapter is AdapterBase {
    using SafeERC20 for IERC20;

    address public governanceAccount;
    address public underlyingTokenAddress;
    address public programAddress;
    address public farmingPoolAccount;

    IVault private _yvdai;
    IERC20 private _underlyingAsset;

    constructor(
        address underlyingTokenAddress_,
        address programAddress_,
        address farmingPoolAccount_
    ) {
        require(
            underlyingTokenAddress_ != address(0),
            "YvdaiAdapter: underlying token address is the zero address"
        );
        require(
            programAddress_ != address(0),
            "YvdaiAdapter: yvDai address is the zero address"
        );
        require(
            farmingPoolAccount_ != address(0),
            "YvdaiAdapter: farming pool account is the zero address"
        );

        governanceAccount = msg.sender;
        underlyingTokenAddress = underlyingTokenAddress_;
        programAddress = programAddress_;
        farmingPoolAccount = farmingPoolAccount_;

        _yvdai = IVault(programAddress);
        _underlyingAsset = IERC20(underlyingTokenAddress);
    }

    modifier onlyBy(address account) {
        require(msg.sender == account, "YvdaiAdapter: sender not authorized");
        _;
    }

    function getTotalWrappedTokenAmountCore()
        internal
        view
        override
        returns (uint256)
    {
        return _yvdai.balanceOf(msg.sender);
    }

    function getWrappedTokenPriceInUnderlyingCore()
        internal
        view
        override
        returns (uint256)
    {
        return _yvdai.pricePerShare();
    }

    // https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-3
    // The reentrancy check is in farming pool.
    function depositUnderlyingToken(uint256 amount)
        external
        override
        onlyBy(farmingPoolAccount)
        returns (uint256)
    {
        require(amount != 0, "YvdaiAdapter: can't add 0");

        _underlyingAsset.safeTransferFrom(msg.sender, address(this), amount);
        _underlyingAsset.safeApprove(programAddress, amount);
        uint256 receivedWrappedTokenQuantity =
            _yvdai.deposit(amount, address(this));

        // slither-disable-next-line reentrancy-events
        emit DepositUnderlyingToken(
            underlyingTokenAddress,
            programAddress,
            amount,
            receivedWrappedTokenQuantity,
            msg.sender,
            block.timestamp
        );

        return receivedWrappedTokenQuantity;
    }

    // https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-3
    // The reentrancy check is in farming pool.
    function redeemWrappedToken(uint256 amount)
        external
        override
        onlyBy(farmingPoolAccount)
        returns (uint256)
    {
        require(amount != 0, "YvdaiAdapter: can't redeem 0");

        // The default maxLoss is 1: https://github.com/yearn/yearn-vaults/blob/v0.3.0/contracts/Vault.vy#L860
        uint256 receivedUnderlyingTokenQuantity =
            _yvdai.withdraw(amount, msg.sender, 1);

        // slither-disable-next-line reentrancy-events
        emit RedeemWrappedToken(
            underlyingTokenAddress,
            programAddress,
            amount,
            receivedUnderlyingTokenQuantity,
            msg.sender,
            block.timestamp
        );

        return receivedUnderlyingTokenQuantity;
    }

    function setGovernanceAccount(address newGovernanceAccount)
        external
        onlyBy(governanceAccount)
    {
        require(
            newGovernanceAccount != address(0),
            "YvdaiAdapter: new governance account is the zero address"
        );

        governanceAccount = newGovernanceAccount;
    }

    function setFarmingPoolAccount(address newFarmingPoolAccount)
        external
        onlyBy(governanceAccount)
    {
        require(
            newFarmingPoolAccount != address(0),
            "YvdaiAdapter: new farming pool account is the zero address"
        );

        farmingPoolAccount = newFarmingPoolAccount;
    }

    function sweep(address to) external override onlyBy(governanceAccount) {
        require(
            to != address(0),
            "YvdaiAdapter: the address to be swept is the zero address"
        );

        uint256 balance = _yvdai.balanceOf(address(this));
        emit Sweep(address(this), to, balance, msg.sender, block.timestamp);

        bool isTransferSuccessful = _yvdai.transfer(to, balance);
        require(isTransferSuccessful, "YvdaiAdapter: sweep failed");
    }
}