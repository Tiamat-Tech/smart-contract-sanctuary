pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

// SPDX-License-Identifier: MIT OR Apache-2.0





import "./ReentrancyGuard.sol";
import "./SafeMath.sol";
import "./SafeMathUInt128.sol";
import "./SafeCast.sol";
import "./Utils.sol";

import "./Storage.sol";
import "./Config.sol";
import "./Events.sol";

import "./Bytes.sol";
import "./Operations.sol";

import "./UpgradeableMaster.sol";

/// @title zkSync additional main contract
/// @author Matter Labs
contract AdditionalZkSync is Storage, Config, Events, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeMathUInt128 for uint128;

    function increaseBalanceToWithdraw(bytes22 _packedBalanceKey, uint128 _amount) internal {
        uint128 balance = pendingBalances[_packedBalanceKey].balanceToWithdraw;
        pendingBalances[_packedBalanceKey] = PendingBalance(balance.add(_amount), FILLED_GAS_RESERVE_VALUE);
    }

    /// @notice Withdraws token from ZkSync to root chain in case of exodus mode. User must provide proof that he owns funds
    /// @param _storedBlockInfo Last verified block
    /// @param _owner Owner of the account
    /// @param _accountId Id of the account in the tree
    /// @param _proof Proof
    /// @param _tokenId Verified token id
    /// @param _amount Amount for owner (must be total amount, not part of it)
    function performExodus(
        StoredBlockInfo memory _storedBlockInfo,
        address _owner,
        uint32 _accountId,
        uint32 _tokenId,
        uint128 _amount,
        uint32 _nftCreatorAccountId,
        address _nftCreatorAddress,
        uint32 _nftSerialId,
        bytes32 _nftContentHash,
        uint256[] memory _proof
    ) external {
        require(_accountId <= MAX_ACCOUNT_ID, "e");
        require(_accountId != SPECIAL_ACCOUNT_ID, "v");
        require(_tokenId < SPECIAL_NFT_TOKEN_ID, "T");

        require(exodusMode, "s"); // must be in exodus mode
        require(!performedExodus[_accountId][_tokenId], "t"); // already exited
        require(storedBlockHashes[totalBlocksExecuted] == hashStoredBlockInfo(_storedBlockInfo), "u"); // incorrect stored block info

        bool proofCorrect =
            verifier.verifyExitProof(
                _storedBlockInfo.stateHash,
                _accountId,
                _owner,
                _tokenId,
                _amount,
                _nftCreatorAccountId,
                _nftCreatorAddress,
                _nftSerialId,
                _nftContentHash,
                _proof
            );
        require(proofCorrect, "x");

        if (_tokenId <= MAX_FUNGIBLE_TOKEN_ID) {
            bytes22 packedBalanceKey = packAddressAndTokenId(_owner, uint16(_tokenId));
            increaseBalanceToWithdraw(packedBalanceKey, _amount);
        } else {
            require(_amount != 0, "Z"); // Unsupported nft amount
            Operations.WithdrawNFT memory withdrawNftOp =
                Operations.WithdrawNFT(
                    _nftCreatorAccountId,
                    _nftCreatorAddress,
                    _nftSerialId,
                    _nftContentHash,
                    _owner,
                    _tokenId
                );
            pendingWithdrawnNFTs[_tokenId] = withdrawNftOp;
        }
        performedExodus[_accountId][_tokenId] = true;
    }

    function cancelOutstandingDepositsForExodusMode(uint64 _n, bytes[] memory _depositsPubdata) external {
        require(exodusMode, "8"); // exodus mode not active
        uint64 toProcess = Utils.minU64(totalOpenPriorityRequests, _n);
        require(toProcess == _depositsPubdata.length, "A");
        require(toProcess > 0, "9"); // no deposits to process
        uint64 currentDepositIdx = 0;
        for (uint64 id = firstPriorityRequestId; id < firstPriorityRequestId + toProcess; id++) {
            if (priorityRequests[id].opType == Operations.OpType.Deposit) {
                bytes memory depositPubdata = _depositsPubdata[currentDepositIdx];
                require(Utils.hashBytesToBytes20(depositPubdata) == priorityRequests[id].hashedPubData, "a");
                ++currentDepositIdx;

                Operations.Deposit memory op = Operations.readDepositPubdata(depositPubdata);
                bytes22 packedBalanceKey = packAddressAndTokenId(op.owner, uint16(op.tokenId));
                pendingBalances[packedBalanceKey].balanceToWithdraw += op.amount;
            }
            delete priorityRequests[id];
        }
        firstPriorityRequestId += toProcess;
        totalOpenPriorityRequests -= toProcess;
    }

    function withdrawPendingNFTBalance(uint32 _tokenId) external nonReentrant {
        Operations.WithdrawNFT memory op = pendingWithdrawnNFTs[_tokenId];
        require(op.creatorAddress != address(0), "op"); // No NFT to withdraw
        NFTFactory _factory = governance.getNFTFactory(op.creatorAccountId, op.creatorAddress);
        _factory.mintNFTFromZkSync(
            op.creatorAddress,
            op.receiver,
            op.creatorAccountId,
            op.serialId,
            op.contentHash,
            op.tokenId
        );
        // Save withdrawn nfts for future deposits
        withdrawnNFTs[op.tokenId] = address(_factory);
        emit WithdrawalNFT(op.tokenId);
        delete pendingWithdrawnNFTs[_tokenId];
    }
}