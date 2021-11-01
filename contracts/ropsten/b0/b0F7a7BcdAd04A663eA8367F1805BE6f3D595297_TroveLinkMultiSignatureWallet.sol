// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/ITroveLinkMultiSignatureWallet.sol";
import "./interfaces/ITroveLinkController.sol";
import "./AddressUtils.sol";

contract TroveLinkMultiSignatureWallet is ITroveLinkMultiSignatureWallet, Initializable {
    using AddressUtils for address;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint256;

    uint256 public constant MAX_COMMITTEE_MEMBER_COUNT = 11;
    uint256 public constant MIN_COMMITTEE_MEMBER_COUNT = 2;
    uint256 public constant PROPOSAL_DURATION = 24 hours;

    EnumerableSet.AddressSet private _committeeMembers;
    ITroveLinkController private _controller;
    bool private _initialized;
    Proposal[] private _proposals;
    uint256 private _quorum;

    /**
     * @dev Returns current timestamp; Internal function for overriding in mocked contracts
     */
    function getTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    /**
     * @notice Returns controller address
     */
    function controller() public view returns (ITroveLinkController) {
        return _controller;
    }

    /**
     * @notice Returns initialization status
     */
    function initialized() public view returns (bool) {
        return _initialized;
    }

    /**
     * @notice Returns quorum value
     */
    function quorum() public view returns (uint256) {
        return _quorum;
    }

    /**
     * @inheritdoc ITroveLinkMultiSignatureWallet
     */
    function committeeMemberCount() external view override(ITroveLinkMultiSignatureWallet) returns (uint256) {
        return _committeeMembers.length();
    }

    /**
     * @inheritdoc ITroveLinkMultiSignatureWallet
     */
    function proposalCount() external view override(ITroveLinkMultiSignatureWallet) returns (uint256) {
        return _proposals.length;
    }

    /**
     * @inheritdoc ITroveLinkMultiSignatureWallet
     */
    function committeeMember(uint256 index_) external view override(ITroveLinkMultiSignatureWallet) returns (address) {
        return _committeeMembers.at(index_);
    }

    /**
     * @inheritdoc ITroveLinkMultiSignatureWallet
     */
    function proposal(
        uint256 index_
    ) external view override(ITroveLinkMultiSignatureWallet) returns (ProposalResponse memory) {
        Proposal storage proposal_ = _proposals[index_];
        EnumerableSet.AddressSet storage proposalConfirmations = proposal_.confirmations;
        uint256 confirmationsCount = proposalConfirmations.length();
        address[] memory confirmations_ = new address[](confirmationsCount);
        for (uint256 i = 0; i < confirmationsCount; i++) confirmations_[i] = proposalConfirmations.at(i);
        return ProposalResponse({
            creator: proposal_.creator,
            destination: proposal_.destination,
            data: proposal_.data,
            value: proposal_.value,
            description: proposal_.description,
            attachments: proposal_.attachments,
            createdAt: proposal_.createdAt,
            expiredAt: proposal_.expiredAt,
            confirmations: confirmations_,
            executed: proposal_.executed
        });
    }

    /**
     * @inheritdoc ITroveLinkMultiSignatureWallet
     * @param committeeMember_ address must be not already added
     */
    function addCommitteeMember(
        address committeeMember_,
        uint256 quorum_
    ) external override(ITroveLinkMultiSignatureWallet) returns (bool) {
        require(_initialized, "Not initialized");
        require(msg.sender == address(_controller), "Invalid sender");
        require(_committeeMembers.length().add(1) <= MAX_COMMITTEE_MEMBER_COUNT, "Invalid committee members count");
        require(!_committeeMembers.contains(committeeMember_), "Already committee member");
        _addCommitteeMember(committeeMember_);
        _updateQuorum(quorum_);
        emit QuorumUpdated(quorum_);
        return true;
    }

    /**
     * @inheritdoc ITroveLinkMultiSignatureWallet
     * @param index_ Must be less than proposalCount
     * Must be not executed
     * Must be not expired
     * Must be not already confirmed
     */
    function confirmProposal(uint256 index_) external override(ITroveLinkMultiSignatureWallet) returns (bool) {
        address sender = msg.sender;
        require(_initialized, "Not initialized");
        require(_committeeMembers.contains(sender), "Invalid sender");
        require(_proposals.length > index_, "Invalid proposal index");
        Proposal storage proposal_ = _proposals[index_];
        require(!proposal_.executed, "Already executed");
        require(proposal_.expiredAt > getTimestamp(), "Expired");
        require(!proposal_.confirmations.contains(sender), "Already confirmed");
        proposal_.confirmations.add(sender);
        emit ProposalConfirmed(index_, sender);
        return true;
    }

    /**
     * @inheritdoc ITroveLinkMultiSignatureWallet
     */
    function createProposal(
        address destination_,
        bytes memory data_,
        string memory description_,
        bytes32 attachments_
    ) external payable override(ITroveLinkMultiSignatureWallet) returns (bool) {
        address sender = msg.sender;
        uint256 proposalValue = msg.value;
        uint256 proposalIndex = _proposals.length;
        uint256 createdAt = getTimestamp();
        uint256 expiredAt = createdAt.add(PROPOSAL_DURATION);
        require(_initialized, "Not initialized");
        require(
            _committeeMembers.contains(sender) || _controller.isService(sender),
            "Invalid sender"
        );
        _proposals.push();
        Proposal storage proposal_ = _proposals[proposalIndex];
        proposal_.creator = sender;
        proposal_.destination = destination_;
        proposal_.data = data_;
        proposal_.description = description_;
        proposal_.attachments = attachments_;
        proposal_.value = proposalValue;
        proposal_.confirmations.add(sender);
        proposal_.createdAt = createdAt;
        proposal_.expiredAt = expiredAt;
        emit ProposalCreated(
            proposalIndex,
            sender,
            destination_,
            data_,
            proposalValue,
            description_,
            attachments_,
            createdAt,
            expiredAt
        );
        emit ProposalConfirmed(proposalIndex, sender);
        return true;
    }

    /**
     * @inheritdoc ITroveLinkMultiSignatureWallet
     * @param index_ Must be less then proposalCount
     * Must be not executed
     * Must be not expired
     * Must have enough confirmations count
     */
    function executeProposal(
        uint256 index_
    ) external payable override(ITroveLinkMultiSignatureWallet) returns (bytes memory result) {
        require(_initialized, "Not initialized");
        require(_proposals.length > index_, "Invalid proposal index");
        Proposal storage proposal_ = _proposals[index_];
        require(!proposal_.executed, "Already executed");
        require(proposal_.expiredAt > getTimestamp(), "Expired");
        require(proposal_.confirmations.length() >= _quorum, "Not enough confirmations");
        result = proposal_.destination.functionCallWithValue(
            proposal_.data,
            proposal_.value,
            "Proposal execution error"
        );
        proposal_.executed = true;
        emit ProposalExecuted(index_, msg.sender);
    }

    /**
     * @inheritdoc ITroveLinkMultiSignatureWallet
     * @param committeeMember_ Must be active committee member
     */
    function removeCommitteeMember(
        address committeeMember_,
        uint256 quorum_
    ) external override(ITroveLinkMultiSignatureWallet) returns (bool) {
        require(_initialized, "Not initialized");
        require(msg.sender == address(_controller), "Invalid sender");
        require(_committeeMembers.length().sub(1) >= MIN_COMMITTEE_MEMBER_COUNT, "Invalid committee members count");
        require(_committeeMembers.contains(committeeMember_), "Invalid committee member");
        _committeeMembers.remove(committeeMember_);
        _updateQuorum(quorum_);
        emit CommitteeMemberRemoved(committeeMember_);
        emit QuorumUpdated(quorum_);
        return true;
    }

    /**
     * @inheritdoc ITroveLinkMultiSignatureWallet
     * @param committeeMember_ Must be active committee member
     * @param newCommitteeMember_ Must be non - active committee member
     */
    function transferCommitteeMember(
        address committeeMember_,
        address newCommitteeMember_
    ) external override(ITroveLinkMultiSignatureWallet) returns (bool) {
        require(_initialized, "Not initialized");
        require(msg.sender == address(_controller), "Invalid sender");
        require(_committeeMembers.contains(committeeMember_), "Invalid committee member");
        require(!_committeeMembers.contains(newCommitteeMember_), "Invalid new committee member");
        _committeeMembers.remove(committeeMember_);
        _committeeMembers.add(newCommitteeMember_);
        emit CommitteeMemberTransfered(committeeMember_, newCommitteeMember_);
        return true;
    } 

    /**
     * @inheritdoc ITroveLinkMultiSignatureWallet
     */
    function updateQuorum(uint256 quorum_) external override(ITroveLinkMultiSignatureWallet) returns (bool) {
        require(_initialized, "Not initialized");
        require(msg.sender == address(_controller), "Invalid sender");
        _updateQuorum(quorum_);
        emit QuorumUpdated(quorum_);
        return true;
    }

    /**
     * @notice Method for contract initializing
     * @dev For success works contract must not be already initialized
     * Emits a {Initialized} event
     * @param controller_ Controller address
     * @param controller_ Must not be equal to zero address
     * @param quorum_ Initial quorum value
     * @param committeeMembers_ Initial committee members addresses
     * @return boolean value indicating whether the operation succeded
     */
    function initialize(
        address controller_,
        uint256 quorum_,
        address[] memory committeeMembers_
    ) public initializer() virtual returns (bool) {
        require(!_initialized, "Already initialized");
        require(controller_ != address(0), "Controller is zero address");
        _controller = ITroveLinkController(controller_);
        for (uint256 i = 0; i < committeeMembers_.length; i++) {
            _addCommitteeMember(committeeMembers_[i]);
        }
        uint256 committeeMembersCount = _committeeMembers.length();
        require(
            committeeMembersCount <= MAX_COMMITTEE_MEMBER_COUNT &&
            committeeMembersCount >= MIN_COMMITTEE_MEMBER_COUNT,
            "Invalid committee members count"
        );
        _updateQuorum(quorum_);
        _initialized = true;
        emit Initialized(controller_, quorum_, committeeMembers_);
        return true;
    }

    /**
     * @dev Private method for adding a new Commitee Member
     * Can emits a {CommitteeMemberAdded} event
     * @param committeeMember_ Committee member address
     * @param committeeMember_ Must be a non-zero address
     */
    function _addCommitteeMember(address committeeMember_) private {
        require(committeeMember_ != address(0), "Committee member is zero address");
        if (_committeeMembers.add(committeeMember_)) emit CommitteeMemberAdded(committeeMember_);
    }

    /**
     * @dev Private method for quorum updating
     * @param quorum_ Must be greater than or equal to MIN_COMMITEE_MEMBER_COUNT
     * @param quorum_ Must be less than or equal to committeeCount
     */
    function _updateQuorum(uint256 quorum_) private {
        uint256 committeeCount = _committeeMembers.length();
        require(quorum_ >= MIN_COMMITTEE_MEMBER_COUNT && quorum_ <= committeeCount, "Invalid quorum");
        _quorum = quorum_;
    }
}