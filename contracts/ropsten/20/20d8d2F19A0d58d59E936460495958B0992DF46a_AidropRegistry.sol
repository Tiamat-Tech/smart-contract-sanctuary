// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0; // solhint-disable-line compiler-version

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { StorageSlotOwnable } from "../lib/StorageSlotOwnable.sol";
import { OnApprove } from "../token/ERC20OnApprove.sol";

import { AidropRegistryStorage } from "./AidropRegistryStorage.sol";
import { AidropRegistryMerkleProof } from "./AidropRegistryMerkleProof.sol";

contract AidropRegistry is AidropRegistryStorage, StorageSlotOwnable, OnApprove, AidropRegistryMerkleProof {
    using SafeERC20 for IERC20;

    event RootAdded(address indexed token, bytes32 root);
    event Claimed(address indexed token, bytes32 root, address account, uint256 amount);

    //////////////////////////////////////////
    //
    // Kernel
    //
    //////////////////////////////////////////

    function implementationVersion() public view virtual override returns (string memory) {
        return "1.0.0";
    }

    function _initializeKernel(bytes memory data) internal override {
        (address owner_, address tokenWallet_) = abi.decode(data, (address, address));
        _setOwner(owner_);
        tokenWallet = tokenWallet_;
        _registerInterface(OnApprove(this).onApprove.selector);
    }

    //////////////////////////////////////////
    //
    // OnApprove
    //
    //////////////////////////////////////////

    function onApprove(
        address owner,
        address spender,
        uint256 amount,
        bytes calldata data
    ) external override returns (bool) {
        spender;
        data;
        IERC20(msg.sender).safeTransferFrom(owner, address(this), amount);
        return true;
    }

    ///////////////////////////////////
    //
    // helper
    //
    ///////////////////////////////////

    /// @dev add merkle root for ERC20 token
    function addRoot(address token, bytes32 root) external onlyOwner {
        _addRoot(token, root);

        emit RootAdded(token, root);
    }

    /// @dev claim token with merkle proof
    function claim(
        address token,
        bytes32 root,
        uint256 amount,
        bytes calldata proof
    ) external {
        _verify(token, root, msg.sender, amount, proof);

        // check token wallet balance and allowance
        address tokenWallet_ = tokenWallet;
        require(IERC20(token).allowance(tokenWallet_, address(this)) >= amount, "insufficient allowance");
        require(IERC20(token).balanceOf(tokenWallet_) >= amount, "insufficient balance");

        claimed[token][root][msg.sender] = true;
        IERC20(token).safeTransferFrom(tokenWallet, msg.sender, amount);

        emit Claimed(token, root, msg.sender, amount);
    }
}