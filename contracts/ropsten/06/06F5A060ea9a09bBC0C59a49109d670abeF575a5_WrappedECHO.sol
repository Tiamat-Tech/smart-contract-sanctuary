// SPDX-License-Identifier: MIT
pragma solidity >0.8.5 <0.9.0;

import "openzeppelin-solidity/contracts/utils/math/Math.sol";
import "openzeppelin-solidity/contracts/utils/structs/EnumerableSet.sol";

abstract contract InternalStorage {
    function recoverSigner(
        bytes32 dataToSign,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal virtual pure returns (address) {
        return ecrecover(dataToSign, v, r, s);
    }

    using EnumerableSet for EnumerableSet.AddressSet;

    struct Signature {
        bytes32 r;
        bytes32 s;
        uint8 v;
    }

    struct HistoryNodeProps {
        uint256 version;
        bytes32 treeHash;
        bytes32 key;
        bytes32 value;
        uint256 blockNumber;
    }

    struct HistoryNode {
        HistoryNodeProps props;
        EnumerableSet.AddressSet signers;
        mapping(address => Signature) signatures;
    }

    bytes32 public immutable genesisHash;

    HistoryNode[] private history;
    mapping(bytes32 => uint256) internal versions;
    mapping(bytes32 => bytes32) private data;

    function getNode(uint256 version) public view returns (HistoryNodeProps memory) {
        require(version < history.length, "Version not found");
        return history[version].props;
    }

    function getNodeVersion(bytes32 nodeHash) public view returns (uint256 version) {
        version = versions[nodeHash];
        if (version == 0) require(nodeHash == genesisHash, "Node not found");
    }

    function getNodeByHash(bytes32 nodeHash) public view returns (HistoryNodeProps memory) {
        return getNode(getNodeVersion(nodeHash));
    }

    function getValue(bytes32 key) public view returns (bytes32) {
        return data[key];
    }

    function getNodes(uint256 fromVersion, uint256 limit) public view returns (HistoryNodeProps[] memory nodes) {
        uint256 nodesCount = history.length;
        if (fromVersion >= nodesCount) return new HistoryNodeProps[](0);
        uint256 length = Math.min(limit, nodesCount - fromVersion);
        nodes = new HistoryNodeProps[](length);
        for (uint256 i = 0; i < length; i++) nodes[i] = history[fromVersion + i].props;
    }

    function isNodeSigner(bytes32 nodeHash, address address_) public view returns (bool) {
        return history[getNodeVersion(nodeHash)].signers.contains(address_);
    }

    function getNodesDescending(uint256 fromVersion, uint256 limit)
        public
        view
        returns (HistoryNodeProps[] memory nodes)
    {
        uint256 nodesCount = history.length;
        if (fromVersion >= nodesCount) return new HistoryNodeProps[](0);
        uint256 length = Math.min(limit, fromVersion + 1);
        nodes = new HistoryNodeProps[](length);
        for (uint256 i = 0; i < length; i++) nodes[i] = history[fromVersion - i].props;
    }

    function readAscending(bytes32 from, uint256 limit) public view returns (HistoryNodeProps[] memory) {
        return getNodes(getNodeVersion(from), limit);
    }

    function readDescending(bytes32 from, uint256 limit) public view returns (HistoryNodeProps[] memory) {
        return getNodesDescending(getNodeVersion(from), limit);
    }

    function readDescendingFromHead(uint256 limit) public view returns (HistoryNodeProps[] memory) {
        return getNodesDescending(history.length - 1, limit);
    }

    function getNodeSignatures(
        bytes32 nodeHash,
        uint256 skip,
        uint256 limit
    ) public view returns (address[] memory signers, Signature[] memory signatures) {
        HistoryNode storage node = history[getNodeVersion(nodeHash)];
        uint256 signersCount = node.signers.length();
        uint256 length = Math.min(limit, signersCount - skip);
        signers = new address[](length);
        signatures = new Signature[](length);
        for (uint256 i = 0; i < length; i++) {
            address signer = node.signers.at(i + skip);
            signers[i] = signer;
            signatures[i] = node.signatures[signer];
        }
    }

    event NewHistoryNodeAdded(
        bytes32 indexed key,
        bytes32 indexed value,
        uint256 indexed blockNumber,
        uint256 version,
        bytes32 treeHash
    );

    event HistoryNodeSigned(
        uint256 indexed version,
        bytes32 indexed treeHash,
        address indexed signer,
        bytes32 r,
        bytes32 s,
        uint8 v
    );

    constructor(bytes32 genesisHash_) {
        genesisHash = genesisHash_;
        history.push();
        HistoryNode storage genesisNode = history[0];
        genesisNode.props = HistoryNodeProps(0, genesisHash_, 0x0, 0x0, block.number);
    }

    function signHistoryNode(bytes32 treeHash, Signature[] memory signatures) public returns (bool success) {
        uint256 version = versions[treeHash];
        require(version != 0, "Node not found");
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 dataToSign = keccak256(abi.encodePacked(prefix, treeHash));
        HistoryNode storage node = history[version];
        for (uint256 i = 0; i < signatures.length; i++) {
            Signature memory signature = signatures[i];
            address signer = recoverSigner(dataToSign, uint8(signature.v), signature.r, signature.s);
            require(signer != address(0), "Invalid signature");
            node.signers.add(signer);
            node.signatures[signer] = signature;
            emit HistoryNodeSigned(version, treeHash, signer, signature.r, signature.s, signature.v);
        }
        return true;
    }

    function _setValue(bytes32 key, bytes32 value) internal {
        data[key] = value;
        uint256 version = history.length;
        HistoryNodeProps storage prevNode = history[version - 1].props;
        bytes32 treeHash = keccak256(abi.encodePacked(prevNode.treeHash, key, value));
        uint256 currentBlock = block.number;
        history.push();
        HistoryNode storage node = history[version];
        node.props = HistoryNodeProps(version, treeHash, key, value, currentBlock);
        versions[treeHash] = version;
        emit NewHistoryNodeAdded(key, value, currentBlock, version, treeHash);
    }
}