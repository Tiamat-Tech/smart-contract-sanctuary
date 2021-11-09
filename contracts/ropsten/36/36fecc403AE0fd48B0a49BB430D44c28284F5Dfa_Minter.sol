// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "./XPNft.sol";
import "./XPNet.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "solidity-bytes-utils/contracts/BytesLib.sol";

contract Minter is Pausable, ERC721Holder {
    using BytesLib for bytes;
    using SafeCast for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 private threshold;
    uint256 private actionCnt = 0;
    uint256 private nftCnt = 0x0;
    uint256 private txFees = 0x0;
    XPNft private immutable nftToken;
    XPNet private immutable token;

    EnumerableSet.AddressSet private validators;
    mapping(address => uint8) private nftWhitelist;

    enum ValidationRes {
        Execute,
        Noop
    }

    enum Action {
        // Bridge actions
        Transfer,
        TransferUnique,
        Unfreeze,
        UnfreezeUnique,
        // Bridge status
        WhitelistNft,
        PauseBridge,
        UnpauseBridge,
        // Multisig
        AddValidator,
        RemoveValidator,
        SetThreshold,
        WithdrawFees
    }

    struct ActionInfo {
        Action action;
        bytes actionData;
        uint256 validatorCnt;
        uint256 readCnt;
    }

    struct TransferAction {
        uint64 chainNonce;
        address to;
        uint256 value;
    }

    struct TransferNftAction {
        address to;
        string data;
    }

    struct UnfreezeAction {
        address to;
        uint256 value;
    }

    struct UnfreezeNftAction {
        address to;
        uint256 tokenId;
        address contractAddr;
    }

    event Transfer(
        uint256 actionId,
        uint64 chainNonce,
        uint256 txFees,
        string to,
        uint256 value
    ); // Transfer ETH to polkadot
    event TransferErc721(
        uint256 actionId,
        uint64 chainNonce,
        uint256 txFees,
        string to,
        uint256 id,
        address contractAddr
    ); // Transfer Erc721 to polkadot
    event Unfreeze(
        uint256 actionId,
        uint64 chainNonce,
        uint256 txFees,
        string to,
        uint256 value
    ); // Unfreeze XPNET on polkadot
    event UnfreezeNft(uint256 actionId, uint256 txFees, string to, string data); // Unfreeze NFT on polkaot
    event QuorumFailure(uint256 actionId);

    mapping(uint128 => ActionInfo) private actions;
    mapping(uint128 => mapping(address => uint8)) private actionValidators;

    modifier requireFees() {
        require(msg.value > 0, "Tx Fees is required!");
        _;
    }

    constructor(
        address[] memory _validators,
        IERC721[] memory _nftWhitelist,
        uint16 _threshold,
        XPNft _nftToken,
        XPNet _token
    ) {
        require(_validators.length > 0, "Validators must not be empty!");
        require(
            _threshold > 0 && _threshold <= _validators.length,
            "invalid threshold!"
        );

        for (uint256 i = 0; i < _validators.length; i++) {
            validators.add(_validators[i]);
        }
        for (uint256 i = 0; i < _nftWhitelist.length; i++) {
            nftWhitelist[address(_nftWhitelist[i])] = 2;
        }

        threshold = _threshold;
        nftToken = _nftToken;
        token = _token;
    }

    function validateAction(
        uint128 actionId,
        Action action,
        bytes memory actionData
    ) private returns (ValidationRes) {
        require(validators.contains(msg.sender), "Not a validator!");

        if (actions[actionId].validatorCnt == 0) {
            actions[actionId] = ActionInfo(action, actionData, 1, 1);
        } else {
            require(
                actionValidators[actionId][msg.sender] != 2,
                "Duplicate Validator!"
            );

            actions[actionId].readCnt += 1;
            require(actions[actionId].action == action, "Action Mismatch");
            require(
                actions[actionId].actionData.equal(actionData),
                "Action Mismatch"
            );
            actions[actionId].validatorCnt += 1;
        }

        actionValidators[actionId][msg.sender] = 2;

        ValidationRes res = ValidationRes.Noop;
        if (actions[actionId].validatorCnt == threshold) {
            res = ValidationRes.Execute;
        }

        if (actions[actionId].readCnt == validators.length()) {
            delete actions[actionId];
            if (actions[actionId].validatorCnt < threshold) {
                // _pause(); (should we pause?)
                emit QuorumFailure(actionId); // Quorum Failed, manual intervention required
            }
        }

        return res;
    }

    // Transfer XPNET
    function validateTransfer(
        uint128 actionId,
        uint64 chainNonce,
        address to,
        uint256 value
    ) external whenNotPaused {
        bytes memory actionData = abi.encode(
            TransferAction(chainNonce, to, value)
        );
        ValidationRes res = validateAction(
            actionId,
            Action.Transfer,
            actionData
        );
        if (res == ValidationRes.Execute) {
            token.mint(to, chainNonce, value);
        }
    }

    // Transfer Foreign NFT
    function validateTransferNft(
        uint128 actionId,
        address to,
        string calldata data
    ) external whenNotPaused returns (uint256) {
        bytes memory actionData = abi.encode(TransferNftAction(to, data));
        ValidationRes res = validateAction(
            actionId,
            Action.TransferUnique,
            actionData
        );
        if (res == ValidationRes.Execute) {
            nftToken.mint(to, nftCnt);
            nftToken.setURI(nftCnt, data);
            nftCnt += 1;

            return nftCnt - 1;
        }

        return 0;
    }

    // Unfreeze ETH
    function validateUnfreeze(
        uint128 actionId,
        address payable to,
        uint256 value
    ) external whenNotPaused {
        bytes memory actionData = abi.encode(UnfreezeAction(to, value));
        ValidationRes res = validateAction(
            actionId,
            Action.Unfreeze,
            actionData
        );
        if (res == ValidationRes.Execute) {
            require(to.send(value), "FAILED TO TRANSFER?!");
        }
    }

    function validateUnfreezeNft(
        uint128 actionId,
        address to,
        uint256 tokenId,
        IERC721 contractAddr
    ) external whenNotPaused {
        require(
            nftWhitelist[address(contractAddr)] == 2,
            "NFT not whitelisted?!"
        );

        bytes memory actionData = abi.encode(
            UnfreezeNftAction(to, tokenId, address(contractAddr))
        );
        ValidationRes res = validateAction(
            actionId,
            Action.UnfreezeUnique,
            actionData
        );
        if (res == ValidationRes.Execute) {
            contractAddr.safeTransferFrom(address(this), to, tokenId);
        }
    }

    function validateWhitelistNft(uint128 actionId, IERC721 contractAddr)
        external
        whenNotPaused
    {
        require(
            nftWhitelist[address(contractAddr)] != 2,
            "NFT already whitelisted"
        );

        bytes memory actionData = abi.encodePacked(address(contractAddr));
        ValidationRes res = validateAction(
            actionId,
            Action.WhitelistNft,
            actionData
        );
        if (res == ValidationRes.Execute) {
            nftWhitelist[address(contractAddr)] = 2;
        }
    }

    function validateAddValidator(uint128 actionId, address newValidator)
        external
        whenNotPaused
    {
        require(!validators.contains(newValidator), "already a validator");

        bytes memory actionData = abi.encodePacked(newValidator);
        ValidationRes res = validateAction(
            actionId,
            Action.AddValidator,
            actionData
        );
        if (res == ValidationRes.Execute) {
            validators.add(newValidator);
        }
    }

    function validateRemoveValidator(uint128 actionId, address oldValidator)
        external
        whenNotPaused
    {
        require(
            threshold <= validators.length() - 1,
            "threshold too high"
        );
        require(
            validators.contains(oldValidator),
            "given address is not a validator"
        );

        bytes memory actionData = abi.encodePacked(oldValidator);
        ValidationRes res = validateAction(
            actionId,
            Action.RemoveValidator,
            actionData
        );
        if (res == ValidationRes.Execute) {
            validators.remove(oldValidator);
        }
    }

    function validatePauseBridge(uint128 actionId) external whenNotPaused {
        bytes memory actionData = "";

        ValidationRes res = validateAction(
            actionId,
            Action.PauseBridge,
            actionData
        );
        if (res == ValidationRes.Execute) {
            _pause();
        }
    }

    function validateUnpauseBridge(uint128 actionId) external whenPaused {
        bytes memory actionData = "";

        ValidationRes res = validateAction(
            actionId,
            Action.UnpauseBridge,
            actionData
        );
        if (res == ValidationRes.Execute) {
            _unpause();
        }
    }

    function validateSetThreshold(uint128 actionId, uint16 newThreshold)
        external
        whenNotPaused
    {
        require(
            newThreshold <= validators.length(),
            "threshold too high"
        );

        bytes memory actionData = abi.encodePacked(newThreshold);
        ValidationRes res = validateAction(
            actionId,
            Action.SetThreshold,
            actionData
        );
        if (res == ValidationRes.Execute) {
            threshold = newThreshold;
        }
    }

    function _withdrawFees() private {
        uint256 validatorCnt = validators.length();

        // This is not perfect but the residual value can't be greater than validatorCnt,
		// which should be minimal compared to total fees collected (> 1E18!)
        uint256 perAcc = txFees / validatorCnt;
        for (uint256 i = 0; i < validatorCnt; i++) {
			txFees -= perAcc;
            payable(validators.at(i)).transfer(perAcc);
        }
    }

    function validateWithdrawFees(uint128 actionId) external {
        bytes memory actionData = "";
        ValidationRes res = validateAction(
            actionId,
            Action.WithdrawFees,
            actionData
        );
        if (res == ValidationRes.Execute) {
            _withdrawFees();
        }
    }

    function _withdraw(
        address sender,
        uint64 chainNonce,
        string calldata to,
        uint256 value
    ) private {
        token.burn(sender, chainNonce, value);
        emit Unfreeze(actionCnt, chainNonce, msg.value, to, value);
        actionCnt += 1;
        txFees += msg.value;
    }

    // Withdraw Wrapped token
    function withdraw(
        uint64 chainNonce,
        string calldata to,
        uint256 value
    ) external payable requireFees whenNotPaused {
        _withdraw(msg.sender, chainNonce, to, value);
    }

    function _withdrawNft(
        address sender,
        string calldata to,
        uint256 id
    ) private {
        require(nftToken.ownerOf(id) == sender, "You don't own this nft!");

        string memory data = nftToken.tokenURI(id);

        nftToken.setURI(id, "");
        nftToken.burn(id);
        emit UnfreezeNft(actionCnt, msg.value, to, data);
        actionCnt += 1;
        txFees += msg.value;
    }

    // Withdraw Foreign NFT
    function withdrawNft(string calldata to, uint256 id)
        external
        payable
        requireFees
        whenNotPaused
    {
        _withdrawNft(msg.sender, to, id);
    }

    // Freeze erc721 token, requires approval to transfer
    function freezeErc721(
        IERC721 erc721Contract,
        uint256 tokenId,
        uint64 chainNonce,
        string calldata to
    ) external payable requireFees whenNotPaused {
        require(
            nftWhitelist[address(erc721Contract)] == 2,
            "contract not whitelisted"
        );

        erc721Contract.safeTransferFrom(msg.sender, address(this), tokenId);

        emit TransferErc721(
            actionCnt,
            chainNonce,
            msg.value,
            to,
            tokenId,
            address(erc721Contract)
        );
        actionCnt += 1;
        txFees += msg.value;
    }

    // Transfer ETH to to Polka
    function freeze(
        uint64 chainNonce,
        string memory to,
        uint256 value
    ) external payable whenNotPaused {
        require(msg.value > 0, "value must be > 0!");
        require(msg.value > value, "txfees/value not enough");

        emit Transfer(actionCnt, chainNonce, msg.value - value, to, value);
        actionCnt += 1;
        txFees += msg.value - value;
    }
}