// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
contract MultiSig is AccessControl {
    bytes32 public constant MULTI_SIG_ROLE = keccak256("MULTI_SIG_ROLE");

    uint256 public requireSigner;
    mapping(uint256 => bool) comfirmedTxs;
    mapping(uint256 => mapping(address => bool)) pendingTxs;
    mapping (uint256 => uint256) pendingSigned;

    event SetRequireSigner(uint256 amount_);

    constructor(address[] memory accounts, uint256 _requireSigner) {
        for (uint i = 0; i < accounts.length; i++) {
            _setupRole(MULTI_SIG_ROLE, accounts[i]);
        }
        requireSigner = _requireSigner;
    }

    function setRequireSigner(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (requireSigner != amount) {
            requireSigner = amount;
            emit SetRequireSigner(requireSigner);
        }
    }

    function _sign(uint256 _txId) internal onlyRole(MULTI_SIG_ROLE) returns(bool) {
        require(!comfirmedTxs[_txId], "MultiSig: transaction completed");
        require(!pendingTxs[_txId][_msgSender()], "MultiSig: already signed");

        pendingTxs[_txId][_msgSender()] = true;
        pendingSigned[_txId]++;

        if (pendingSigned[_txId] >= requireSigner) {
            comfirmedTxs[_txId] = true;
            return true;
        }
        return false;
    }

    function _cancelSign(uint256 _txId) internal onlyRole(MULTI_SIG_ROLE) {
        require(!comfirmedTxs[_txId], "MultiSig: transaction completed");
        require(pendingTxs[_txId][_msgSender()], "MultiSig: sign info noexists");

        pendingSigned[_txId]--;
        pendingTxs[_txId][_msgSender()] = false;
    }
    
}