// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

contract Deserializer {
    enum OpType {
        NotSubmittedTx,
        Swap1,
        Swap2,
        AddLiquidity,
        RemoveLiquidity,
        HiddenTx,
        DepositToNew,
        Deposit,
        Withdraw,
        Exit
    }

    uint256 internal constant NOT_SUBMITTED_BYTES_SIZE = 1;
    uint256 internal constant SWAP_BYTES_SIZE = 11;
    uint256 internal constant ADD_LIQUIDITY_BYTES_SIZE = 16;
    uint256 internal constant REMOVE_LIQUIDITY_BYTES_SIZE = 11;
    uint256 internal constant TX_COMMITMENT_SIZE = 32;

    uint256 internal constant DEPOSIT_BYTES_SIZE = 6;
    uint256 internal constant WITHDRAW_BYTES_SIZE = 13;
    uint256 internal constant OPERATION_COMMITMENT_SIZE = 32;
}