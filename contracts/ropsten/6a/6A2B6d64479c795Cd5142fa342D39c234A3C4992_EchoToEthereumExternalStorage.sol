// SPDX-License-Identifier: MIT
pragma solidity >0.8.5 <0.9.0;

import "openzeppelin-solidity/contracts/utils/math/Math.sol";
import "openzeppelin-solidity/contracts/utils/structs/EnumerableSet.sol";

contract Committee {
    function recoverSigner(
        bytes32 data,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal virtual pure returns (address) {
        return ecrecover(data, v, r, s);
    }

    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant MIN_COMMITTEE_SIZE = 8;
    uint256 public constant MAX_COMMITTEE_SIZE = 50;

    struct Signature {
        bytes32 r;
        bytes32 s;
        uint8 v;
    }

    struct Action {
        bool addition;
        address address_;
    }

    struct NodeProps {
        bool applied;
        bool verified;
        bytes32 parentHash;
        Action action;
    }

    struct Node {
        uint256 version;
        NodeProps props;
        EnumerableSet.AddressSet signers;
        mapping(address => Signature) signatures;
    }

    bytes32 public immutable rootHash;

    bytes32 private _headHash;
    bytes32[] private _hashes;
    EnumerableSet.AddressSet private _members;
    mapping(bytes32 => Node) private _nodes;

    function committeeSize() public view returns (uint256) {
        return _members.length();
    }

    function requiredSignaturesCount() public virtual view returns (uint256) {
        return (_members.length() * 2) / 3 + 1;
    }

    function version() public view returns (uint256) {
        return _hashes.length - 1;
    }

    function headHash() public view returns (bytes32) {
        return _headHash;
    }

    function snapshot() public view returns (bytes32 root, address[] memory members) {
        return (_headHash, getCommitteeMembers(0, type(uint256).max));
    }

    function isCommitteeMember(address address_) public view returns (bool) {
        return _members.contains(address_);
    }

    function getNodeSignersCount(bytes32 nodeHash) public view returns (uint256) {
        return _nodes[nodeHash].signers.length();
    }

    function getCommitteeMembers(uint256 fromIndex, uint256 limit) public view returns (address[] memory) {
        uint256 committeeSize_ = committeeSize();
        if (fromIndex >= committeeSize_) return new address[](0);
        uint256 length = Math.min(limit, committeeSize_ - fromIndex);
        address[] memory result = new address[](length);
        for (uint256 i = 0; i < length; i++) result[i] = _members.at(fromIndex + i);
        return result;
    }

    function getNodeSigners(
        bytes32 nodeHash,
        uint256 fromIndex,
        uint256 limit
    ) public view returns (address[] memory) {
        Node storage node_ = _nodes[nodeHash];
        uint256 signersCount_ = node_.signers.length();
        if (fromIndex >= signersCount_) return new address[](0);
        uint256 length = Math.min(limit, signersCount_ - fromIndex);
        address[] memory result = new address[](length);
        for (uint256 i = 0; i < length; i++) result[i] = node_.signers.at(fromIndex + i);
        return result;
    }

    function getAppliedNodesHashes(uint256 fromVersion, uint256 limit) public view returns (bytes32[] memory) {
        uint256 hashesCount = _hashes.length;
        if (fromVersion >= hashesCount) return new bytes32[](0);
        uint256 length = Math.min(limit, hashesCount - fromVersion);
        bytes32[] memory result = new bytes32[](length);
        for (uint256 i = 0; i < length; i++) result[i] = _hashes[fromVersion + i];
        return result;
    }

    function getAppliedNodes(uint256 fromVersion, uint256 limit) public view returns (NodeProps[] memory) {
        bytes32[] memory hashes = getAppliedNodesHashes(fromVersion, limit);
        uint256 length = hashes.length;
        NodeProps[] memory result = new NodeProps[](length);
        for (uint256 i = 0; i < length; i++) result[i] = _nodes[hashes[i]].props;
        return result;
    }

    function getNode(bytes32 hash_) public view returns (uint256 version_, NodeProps memory props) {
        Node storage node_ = _nodes[hash_];
        return (node_.version, node_.props);
    }

    function getNodeSignatures(
        bytes32 nodeHash,
        uint256 fromIndex,
        uint256 limit
    ) public view returns (Signature[] memory signatures_, address[] memory signers_) {
        Node storage node_ = _nodes[nodeHash];
        uint256 signersCount_ = node_.signers.length();
        if (fromIndex >= signersCount_) return (signatures_, signers_);
        uint256 length = Math.min(limit, signersCount_ - fromIndex);
        signatures_ = new Signature[](length);
        signers_ = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            address signer = node_.signers.at(fromIndex + i);
            signatures_[i] = node_.signatures[signer];
            signers_[i] = signer;
        }
    }

    event MemberAdded(address indexed address_);
    event MemberRemoved(address indexed address_);
    event NodeSigned(bytes32 indexed nodeHash, address indexed signer, bytes32 r, bytes32 s, uint8 v);
    event NodeVerified(bytes32 indexed nodeHash, bytes32 indexed parentHash, address indexed address_, bool addition);
    event NodeApplied(bytes32 indexed hash_);
    event SignerRemoved(bytes32 indexed nodeHash, address indexed signer);

    constructor(address[] memory members, bytes32 rootHash_) {
        rootHash = rootHash_;
        _headHash = rootHash_;
        _hashes.push(rootHash_);
        uint256 membersCount = members.length;
        require(membersCount >= MIN_COMMITTEE_SIZE, "Members count lt required");
        require(membersCount <= MAX_COMMITTEE_SIZE, "Members count gt allowed");
        for (uint256 i = 0; i < membersCount; i++) _addMember(members[i]);
    }

    function sign(bytes32 hash_, Signature[] memory signatures_) public returns (bool success) {
        Node storage node_ = _nodes[hash_];
        uint256 signaturesCount = signatures_.length;
        for (uint256 i = 0; i < signaturesCount; i++) {
            Signature memory signature = signatures_[i];
            address signer = recoverSigner(_getPrefixedHash(hash_), signature.v, signature.r, signature.s);
            node_.signers.add(signer);
            node_.signatures[signer] = signature;
            emit NodeSigned(hash_, signer, signature.r, signature.s, signature.v);
        }
        return true;
    }

    function verify(bytes32 parentHash, Action memory action) public returns (bool success) {
        _verify(parentHash, action);
        return true;
    }

    function removeExcessSignatures(bytes32 nodeHash_, address[] memory signers) public returns (bool success) {
        Node storage node_ = _nodes[nodeHash_];
        require(node_.props.verified, "Node not verified");
        require(node_.props.parentHash == _headHash, "Not incomming node");
        uint256 signersCount = signers.length;
        for (uint256 i = 0; i < signersCount; i++) {
            address signer = signers[i];
            require(!isCommitteeMember(signer), "Signer is committee member");
            node_.signers.remove(signer);
            emit SignerRemoved(nodeHash_, signer);
        }
        return true;
    }

    function commit(Action memory action) public returns (bool success) {
        bytes32 newHeadHash;
        Node storage node_;
        (newHeadHash, node_) = _verify(_headHash, action);
        uint256 validSignaturesCount = 0;
        for (uint256 i = 0; i < node_.signers.length(); i++) {
            address signer = node_.signers.at(i);
            if (_members.contains(signer)) validSignaturesCount += 1;
        }
        require(validSignaturesCount >= requiredSignaturesCount(), "Not enough signatures");
        if (action.addition) {
            require(!_members.contains(action.address_), "Already committee member");
            require(_members.length() < MAX_COMMITTEE_SIZE, "Members count gt allowed");
            _addMember(action.address_);
        } else {
            require(_members.contains(action.address_), "Not committee member");
            require(_members.length() > MIN_COMMITTEE_SIZE, "Members count lt required");
            _members.remove(action.address_);
            emit MemberRemoved(action.address_);
        }
        _hashes.push(newHeadHash);
        _headHash = newHeadHash;
        node_.props.applied = true;
        emit NodeApplied(newHeadHash);
        return true;
    }

    function _getPrefixedHash(bytes32 hash_) internal pure returns (bytes32) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        return keccak256(abi.encodePacked(prefix, hash_));
    }

    function _addMember(address address_) private {
        _members.add(address_);
        emit MemberAdded(address_);
    }

    function _verify(bytes32 parentHash, Action memory action) private returns (bytes32 hash_, Node storage node_) {
        hash_ = keccak256(abi.encodePacked(parentHash, action.addition, action.address_));
        node_ = _nodes[hash_];
        Node storage parent = _nodes[parentHash];
        require(parentHash == rootHash || parent.props.verified, "Parent node not verified");
        node_.version = parent.version + 1;
        node_.props.parentHash = parentHash;
        node_.props.action = action;
        node_.props.verified = true;
        emit NodeVerified(hash_, parentHash, action.address_, action.addition);
    }
}