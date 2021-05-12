// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interface/structs.sol";
import "../interface/IQNFT.sol";

/**
 * @author fantasy
 */
contract QNFTGov is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeMathUpgradeable for uint256;

    event VoteGovernanceAddress(
        address indexed voter,
        address indexed multisig,
        uint256 amount
    );
    event WithdrawToGovernanceAddress(
        address indexed user,
        address indexed multisig,
        uint256 amount
    );
    event SafeWithdraw(
        address indexed owner,
        address indexed ultisig,
        uint256 amount
    );

    // constants
    uint256 public constant VOTE_QUORUM = 50; // 50%
    uint256 public constant PERCENT_MAX = 100;

    // vote options
    mapping(address => uint256) public voteResult; // vote amount of give multisig wallet
    mapping(address => address) public voteAddressByVoter; // vote address of given user
    mapping(address => uint256) public voteWeightsByVoter; // vote amoutn of given user

    IQNFT public qnft;

    modifier onlyQnft() {
        require(address(qnft) == _msgSender(), "Ownable: caller is not QNFT");
        _;
    }

    receive() external payable {}

    fallback() external payable {}

    function initialize() external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
    }

    /**
     * @dev votes on a given multisig wallet with the locked qstk balance of the user
     */
    function voteGovernanceAddress(address multisig) public {
        require(qnft.mintStarted(), "QNFTGov: mint not started");
        require(qnft.mintFinished(), "QNFTGov: NFT sale not ended");

        uint256 qstkAmount = qnft.qstkBalances(msg.sender);
        require(qstkAmount > 0, "QNFTGov: non-zero qstk balance");

        if (voteAddressByVoter[msg.sender] != address(0x0)) {
            voteResult[voteAddressByVoter[msg.sender]] = voteResult[
                voteAddressByVoter[msg.sender]
            ]
                .sub(voteWeightsByVoter[msg.sender]);
        }

        voteResult[multisig] = voteResult[multisig].add(qstkAmount);
        voteWeightsByVoter[msg.sender] = qstkAmount;
        voteAddressByVoter[msg.sender] = multisig;

        emit VoteGovernanceAddress(msg.sender, multisig, qstkAmount);
    }

    /**
     * @dev withdraws to the governance address if it has enough vote amount
     */
    function withdrawToGovernanceAddress(address payable multisig)
        public
        nonReentrant
    {
        VoteStatus status = qnft.voteStatus();
        require(status != VoteStatus.NotStarted, "QNFTGov: vote not started");
        require(status != VoteStatus.InProgress, "QNFTGov: vote in progress");

        require(
            voteResult[multisig] >=
                qnft.totalAssignedQstk().mul(VOTE_QUORUM).div(PERCENT_MAX),
            "QNFTGov: specified multisig address is not voted enough"
        );

        uint256 amount = address(this).balance;

        multisig.transfer(amount);

        emit WithdrawToGovernanceAddress(msg.sender, multisig, amount);
    }

    /**
     * @dev withdraws to multisig wallet by owner - need to pass the safe vote end duration
     */
    function safeWithdraw(address payable multisig)
        public
        onlyOwner
        nonReentrant
    {
        VoteStatus status = qnft.voteStatus();
        require(status != VoteStatus.NotStarted, "QNFTGov: vote not started");
        require(status != VoteStatus.InProgress, "QNFTGov: vote in progress");
        require(
            status == VoteStatus.AbleToSafeWithdraw,
            "QNFTGov: wait until safe vote end time"
        );

        uint256 amount = address(this).balance;

        multisig.transfer(amount);

        emit SafeWithdraw(msg.sender, multisig, amount);
    }

    /**
     * @dev updates the votes amount of the given user
     */
    function updateVoteAmount(
        address user,
        uint256 minusAmount,
        uint256 plusAmount
    ) public onlyQnft {
        if (voteAddressByVoter[user] != address(0x0)) {
            // just updates the vote amount if the user has previous vote.

            voteWeightsByVoter[user] = voteWeightsByVoter[user]
                .add(plusAmount)
                .sub(minusAmount);

            voteResult[voteAddressByVoter[msg.sender]] = voteResult[
                voteAddressByVoter[msg.sender]
            ]
                .add(plusAmount)
                .sub(minusAmount);

            if (voteWeightsByVoter[user] == 0) {
                voteAddressByVoter[user] = address(0x0);
            }
        }
    }

    /**
     * @dev sets QNFT contract address
     */
    function setQNft(IQNFT _qnft) public onlyOwner {
        require(qnft != _qnft, "QNFTGov: QNFT already set");

        qnft = _qnft;
    }
}