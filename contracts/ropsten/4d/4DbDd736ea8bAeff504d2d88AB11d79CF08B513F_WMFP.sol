// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.4;

import {IERC20} from "openzeppelin-contracts-4.4.1/contracts/token/ERC20/IERC20.sol";

import {SafeERC20} from "openzeppelin-contracts-4.4.1/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "openzeppelin-contracts-4.4.1/contracts/token/ERC20/ERC20.sol";
// solhint-disable-next-line max-line-length
import {ERC20Permit} from "openzeppelin-contracts-4.4.1/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

/**
 * @title WMFP (Wrapped MFP).
 *
 * @dev A fixed-balance ERC-20 wrapper for the MFP rebasing token.
 *
 *      Users deposit MFP into this contract and are minted wMFP.
 *
 *      Each account's wMFP balance represents the fixed percentage ownership
 *      of MFP's market cap.
 *
 *      For example: 100K wMFP => 1% of the MFP market cap
 *        when the MFP supply is 100M, 100K wMFP will be redeemable for 1M MFP
 *        when the MFP supply is 500M, 100K wMFP will be redeemable for 5M MFP
 *        and so on.
 *
 *      We call wMFP the "wrapper" token and MFP the "underlying" or "wrapped" token.
 */
contract WMFP is ERC20, ERC20Permit {
    using SafeERC20 for IERC20;

    //--------------------------------------------------------------------------
    // Constants

    /// @dev The maximum wMFP supply.
    uint256 public constant MAX_WMFP_SUPPLY = 10000000 * (10**18); // 10 M

    //--------------------------------------------------------------------------
    // Attributes

    /// @dev The reference to the MFP token.
    address private immutable _mfp;

    //--------------------------------------------------------------------------

    /// @param mfp The MFP ERC20 token address.
    /// @param name_ The wMFP ERC20 name.
    /// @param symbol_ The wMFP ERC20 symbol.
    constructor(
        address mfp,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) ERC20Permit(name_) {
        _mfp = mfp;
    }

    //--------------------------------------------------------------------------
    // WMFP write methods

    /// @notice Transfers MFPs from {msg.sender} and mints wMFPs.
    ///
    /// @param wmfps The amount of wMFPs to mint.
    /// @return The amount of MFPs deposited.
    function mint(uint256 wmfps) external returns (uint256) {
        uint256 mfps = _wmfpToMfp(wmfps, _queryMFPSupply());
        _deposit(_msgSender(), _msgSender(), mfps, wmfps);
        return mfps;
    }

    /// @notice Transfers MFPs from {msg.sender} and mints wMFPs,
    ///         to the specified beneficiary.
    ///
    /// @param to The beneficiary wallet.
    /// @param wmfps The amount of wMFPs to mint.
    /// @return The amount of MFPs deposited.
    function mintFor(address to, uint256 wmfps) external returns (uint256) {
        uint256 mfps = _wmfpToMfp(wmfps, _queryMFPSupply());
        _deposit(_msgSender(), to, mfps, wmfps);
        return mfps;
    }

    /// @notice Burns wMFPs from {msg.sender} and transfers MFPs back.
    ///
    /// @param wmfps The amount of wMFPs to burn.
    /// @return The amount of MFPs withdrawn.
    function burn(uint256 wmfps) external returns (uint256) {
        uint256 mfps = _wmfpToMfp(wmfps, _queryMFPSupply());
        _withdraw(_msgSender(), _msgSender(), mfps, wmfps);
        return mfps;
    }

    /// @notice Burns wMFPs from {msg.sender} and transfers MFPs back,
    ///         to the specified beneficiary.
    ///
    /// @param to The beneficiary wallet.
    /// @param wmfps The amount of wMFPs to burn.
    /// @return The amount of MFPs withdrawn.
    function burnTo(address to, uint256 wmfps) external returns (uint256) {
        uint256 mfps = _wmfpToMfp(wmfps, _queryMFPSupply());
        _withdraw(_msgSender(), to, mfps, wmfps);
        return mfps;
    }

    /// @notice Burns all wMFPs from {msg.sender} and transfers MFPs back.
    ///
    /// @return The amount of MFPs withdrawn.
    function burnAll() external returns (uint256) {
        uint256 wmfps = balanceOf(_msgSender());
        uint256 mfps = _wmfpToMfp(wmfps, _queryMFPSupply());
        _withdraw(_msgSender(), _msgSender(), mfps, wmfps);
        return mfps;
    }

    /// @notice Burns all wMFPs from {msg.sender} and transfers MFPs back,
    ///         to the specified beneficiary.
    ///
    /// @param to The beneficiary wallet.
    /// @return The amount of MFPs withdrawn.
    function burnAllTo(address to) external returns (uint256) {
        uint256 wmfps = balanceOf(_msgSender());
        uint256 mfps = _wmfpToMfp(wmfps, _queryMFPSupply());
        _withdraw(_msgSender(), to, mfps, wmfps);
        return mfps;
    }

    /// @notice Transfers MFPs from {msg.sender} and mints wMFPs.
    ///
    /// @param mfps The amount of MFPs to deposit.
    /// @return The amount of wMFPs minted.
    function deposit(uint256 mfps) external returns (uint256) {
        uint256 wmfps = _mfpToWmfp(mfps, _queryMFPSupply());
        _deposit(_msgSender(), _msgSender(), mfps, wmfps);
        return wmfps;
    }

    /// @notice Transfers MFPs from {msg.sender} and mints wMFPs,
    ///         to the specified beneficiary.
    ///
    /// @param to The beneficiary wallet.
    /// @param mfps The amount of MFPs to deposit.
    /// @return The amount of wMFPs minted.
    function depositFor(address to, uint256 mfps) external returns (uint256) {
        uint256 wmfps = _mfpToWmfp(mfps, _queryMFPSupply());
        _deposit(_msgSender(), to, mfps, wmfps);
        return wmfps;
    }

    /// @notice Burns wMFPs from {msg.sender} and transfers MFPs back.
    ///
    /// @param mfps The amount of MFPs to withdraw.
    /// @return The amount of burnt wMFPs.
    function withdraw(uint256 mfps) external returns (uint256) {
        uint256 wmfps = _mfpToWmfp(mfps, _queryMFPSupply());
        _withdraw(_msgSender(), _msgSender(), mfps, wmfps);
        return wmfps;
    }

    /// @notice Burns wMFPs from {msg.sender} and transfers MFPs back,
    ///         to the specified beneficiary.
    ///
    /// @param to The beneficiary wallet.
    /// @param mfps The amount of MFPs to withdraw.
    /// @return The amount of burnt wMFPs.
    function withdrawTo(address to, uint256 mfps) external returns (uint256) {
        uint256 wmfps = _mfpToWmfp(mfps, _queryMFPSupply());
        _withdraw(_msgSender(), to, mfps, wmfps);
        return wmfps;
    }

    /// @notice Burns all wMFPs from {msg.sender} and transfers MFPs back.
    ///
    /// @return The amount of burnt wMFPs.
    function withdrawAll() external returns (uint256) {
        uint256 wmfps = balanceOf(_msgSender());
        uint256 mfps = _wmfpToMfp(wmfps, _queryMFPSupply());
        _withdraw(_msgSender(), _msgSender(), mfps, wmfps);
        return wmfps;
    }

    /// @notice Burns all wMFPs from {msg.sender} and transfers MFPs back,
    ///         to the specified beneficiary.
    ///
    /// @param to The beneficiary wallet.
    /// @return The amount of burnt wMFPs.
    function withdrawAllTo(address to) external returns (uint256) {
        uint256 wmfps = balanceOf(_msgSender());
        uint256 mfps = _wmfpToMfp(wmfps, _queryMFPSupply());
        _withdraw(_msgSender(), to, mfps, wmfps);
        return wmfps;
    }

    //--------------------------------------------------------------------------
    // WMFP view methods

    /// @return The address of the underlying "wrapped" token ie) MFP.
    function underlying() external view returns (address) {
        return _mfp;
    }

    /// @return The total MFPs held by this contract.
    function totalUnderlying() external view returns (uint256) {
        return _wmfpToMfp(totalSupply(), _queryMFPSupply());
    }

    /// @param owner The account address.
    /// @return The MFP balance redeemable by the owner.
    function balanceOfUnderlying(address owner) external view returns (uint256) {
        return _wmfpToMfp(balanceOf(owner), _queryMFPSupply());
    }

    /// @param mfps The amount of MFP tokens.
    /// @return The amount of wMFP tokens exchangeable.
    function underlyingToWrapper(uint256 mfps) external view returns (uint256) {
        return _mfpToWmfp(mfps, _queryMFPSupply());
    }

    /// @param wmfps The amount of wMFP tokens.
    /// @return The amount of MFP tokens exchangeable.
    function wrapperToUnderlying(uint256 wmfps) external view returns (uint256) {
        return _wmfpToMfp(wmfps, _queryMFPSupply());
    }

    //--------------------------------------------------------------------------
    // Private methods

    /// @dev Internal helper function to handle deposit state change.
    /// @param from The initiator wallet.
    /// @param to The beneficiary wallet.
    /// @param mfps The amount of MFPs to deposit.
    /// @param wmfps The amount of wMFPs to mint.
    function _deposit(
        address from,
        address to,
        uint256 mfps,
        uint256 wmfps
    ) private {
        IERC20(_mfp).safeTransferFrom(from, address(this), mfps);

        _mint(to, wmfps);
    }

    /// @dev Internal helper function to handle withdraw state change.
    /// @param from The initiator wallet.
    /// @param to The beneficiary wallet.
    /// @param mfps The amount of MFPs to withdraw.
    /// @param wmfps The amount of wMFPs to burn.
    function _withdraw(
        address from,
        address to,
        uint256 mfps,
        uint256 wmfps
    ) private {
        _burn(from, wmfps);

        IERC20(_mfp).safeTransfer(to, mfps);
    }

    /// @dev Queries the current total supply of MFP.
    /// @return The current MFP supply.
    function _queryMFPSupply() private view returns (uint256) {
        return IERC20(_mfp).totalSupply();
    }

    //--------------------------------------------------------------------------
    // Pure methods

    /// @dev Converts MFPs to wMFP amount.
    function _mfpToWmfp(uint256 mfps, uint256 totalMFPSupply)
        private
        pure
        returns (uint256)
    {
        return (mfps * MAX_WMFP_SUPPLY) / totalMFPSupply;
    }

    /// @dev Converts wMFPs amount to MFPs.
    function _wmfpToMfp(uint256 wmfps, uint256 totalMFPSupply)
        private
        pure
        returns (uint256)
    {
        return (wmfps * totalMFPSupply) / MAX_WMFP_SUPPLY;
    }
}