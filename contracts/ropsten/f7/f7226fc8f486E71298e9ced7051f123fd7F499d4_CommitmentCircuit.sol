// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./SchnorrSignature.sol";

contract CommitmentCircuit is SchnorrSignature {
	using SafeERC20 for IERC20;

	IERC20 public xftTokenAddress;

	mapping(address => uint256[]) public _idsByAddress;
	mapping(uint256 => PointEC) public _commitmentById;
	mapping(uint256 => bool) public _spents; // spents[id]

	event CommitmentTransferred(
		address indexed sender,
		address indexed recipient,
		uint256 senderCommitmentId,
		uint256 recipientCommitmentId,
		PointEC senderCommitment,
		PointEC recipientCommitment
	);
	event Deposited(
		address indexed to,
		uint256 amount,
		uint256 indexed commitmentId,
		PointEC commitment
	);
	event Withdrawn(
		address indexed to,
		uint256 amount,
		uint256 indexed commitmentIdOld,
		uint256 indexed commitmentIdNew,
		PointEC commitmentOld,
		PointEC commitmentNew
	);

	constructor(address _xftTokenAddress) {
		xftTokenAddress = IERC20(_xftTokenAddress);
	}
	
	function transferCommitment(
		address recipient,
		uint256 senderCommitmentId,
		PointEC memory recipientCommitment,
		string memory message,
		PointEC memory pubKey,
		PointEC memory ecR,
		uint256 s
	) public {
		require(SchnorrSignatureVerify(message, pubKey, ecR, s), "invalid signature");
		require(_spents[senderCommitmentId], "commitment already used");
		PointEC memory senderCommitment = _commitmentById[senderCommitmentId];
		require(
			_CommitmentVerify(senderCommitment, recipientCommitment, pubKey),
			"invalid commitments"
		);

		_CommitmentOldSpent(senderCommitmentId);
		uint256 id = _CommitmentNewAdd(recipient, recipientCommitment);
		emit CommitmentTransferred(
			msg.sender,
			recipient,
			senderCommitmentId,
			id,
			senderCommitment,
			_commitmentById[id]
		);
	}

	function deposit(
		uint256 amount,
		PointEC memory recipientCommitment,
		PointEC memory pubKey,
		PointEC memory ecR,
		uint256 s,
		string memory message
	) public {
		require(SchnorrSignatureVerify(message, pubKey, ecR, s), "invalid signature");

		xftTokenAddress.safeTransferFrom(msg.sender, address(this), amount);
		uint256 id = _CommitmentNewAdd(msg.sender, recipientCommitment);

		emit Deposited(msg.sender, amount, id, _commitmentById[id]);
	}

	function withdraw(
		uint256 amount,
		uint256 recipientCommitmentOldId,
		PointEC memory recipientCommitment,
		PointEC memory pubKey,
		PointEC memory ecR,
		string memory message,
		uint256 s
	) public {
		require(SchnorrSignatureVerify(message, pubKey, ecR, s), "invalid signature");
		require(_spents[recipientCommitmentOldId], "commitment already used");
		require(
			_CommitmentVerify(
				_commitmentById[recipientCommitmentOldId],
				recipientCommitment,
				pubKey
			),
			"invalid commitments"
		);

		xftTokenAddress.safeTransfer(msg.sender, amount);
		_CommitmentOldSpent(recipientCommitmentOldId);
		uint256 id = _CommitmentNewAdd(msg.sender, recipientCommitment);

		emit Withdrawn(
			msg.sender,
			amount,
			recipientCommitmentOldId,
			id,
			_commitmentById[recipientCommitmentOldId],
			_commitmentById[id]
		);
	}

	function _CommitmentOldSpent(uint256 _id) internal {
		_spents[_id] = false;
	}

	function _CommitmentNewAdd(address _newOwner, PointEC memory _commitment)
		internal
		returns (uint256)
	{
		uint256 _id = block.timestamp;
		_commitmentById[_id] = _commitment;
		_idsByAddress[_newOwner].push(_id);
		_spents[_id] = true;
		return _id;
	}

	function _CommitmentVerify( 
		PointEC memory _ecCommInput,
		PointEC memory _ecCommOutput,
		PointEC memory _ecCommValid
	) internal pure returns (bool) {
		PointEC memory _ecP;
		(_ecP.x, _ecP.y) = eSub(_ecCommInput.x, _ecCommInput.y, _ecCommOutput.x, _ecCommOutput.y);
		return _equalPointEC(_ecP, _ecCommValid);
	}
}