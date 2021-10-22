//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "../interfaces/IHorizon.sol";

contract HorizonConfig is IHorizonConfig, AccessControlEnumerableUpgradeable {
    bytes32[] public override identifier; // e.g. keccak256(abi.encodePacked("VAULT_USDC"))
    mapping(bytes32 => string) public override underlying;
    mapping(bytes32 => Asset) private _assets;
    mapping(uint256 => bool) public override isPeerChainRegistered;
    uint256[] public override peerChains;

    function initialize(Asset[] memory assets_, string[] memory underlying_) public virtual initializer {
        for (uint256 i = 0; i < underlying_.length; i++) {
            bytes32 id = keccak256(abi.encodePacked(underlying_[i]));
            _assets[id] = assets_[i];
            identifier.push(id);
            underlying[id] = underlying_[i];
        }
    }
    function assets(bytes32 id) external view override returns(Asset memory) {
        return _assets[id];
    }
    function listIdentifier() external view override returns(bytes32[] memory) {
        return identifier;
    }
    function listPeerChains() external view override returns(uint256[] memory) {
        return peerChains;
    }

    function registerPeerChains(uint256[] calldata chainIds) external override {
        for (uint i = 0; i < chainIds.length; i++) {
            if (isPeerChainRegistered[chainIds[i]]) continue;
            isPeerChainRegistered[chainIds[i]] = true;
            peerChains.push(chainIds[i]);
        }
    }

    function unregisterPeerChains(uint256[] calldata chainIds) external override {
        for (uint i = 0; i < chainIds.length; i++) {
            if (!isPeerChainRegistered[chainIds[i]]) continue;
            isPeerChainRegistered[chainIds[i]] = false;

            uint256 len = peerChains.length;
            for (uint256 j = 0; j < len; j++) {
                if (chainIds[i] == peerChains[j]) {
                    peerChains[i] = peerChains[len - 1];
                    peerChains.pop();
                }
            }

        }
    }
}