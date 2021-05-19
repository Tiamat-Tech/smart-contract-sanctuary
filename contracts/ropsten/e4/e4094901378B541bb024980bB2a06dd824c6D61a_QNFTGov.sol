// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../interface/structs.sol";
import "../interface/IQNFT.sol";
import "../interface/IQNFTGov.sol";
import "../interface/IQNFTSettings.sol";
import "../interface/IQSettings.sol";

/**
 * @author fantasy
 */
contract QNFTGov is IQNFTGov, ContextUpgradeable, ReentrancyGuardUpgradeable {
    event VoteGovernanceAddress(
        address indexed voter,
        address indexed multisig
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
    event UpdateVote(
        address indexed user,
        uint256 originAmount,
        uint256 currentAmount
    );

    // constants
    uint256 public constant PERCENT_MAX = 100;
    uint256 public constant VOTE_QUORUM = 70; // 50%
    uint256 public constant MIN_VOTE_DURATION = 604800; // 1 week
    uint256 public constant SAFE_VOTE_END_DURATION = 1814400; // 3 weeks

    // vote options
    uint256 public totalUsers;
    mapping(address => uint256) public voteResult; // vote amount of give multisig wallet
    mapping(address => address) public voteAddressByVoter; // vote address of given user
    mapping(address => bool) public canVote; // vote amoutn of given user

    IQNFT public qnft;
    IQSettings public settings;
    IQNFTSettings public qnftSettings;

    modifier onlyManager() {
        require(
            settings.manager() == msg.sender,
            "QNFTGov: caller is not the manager"
        );
        _;
    }

    modifier onlyQnft() {
        require(address(qnft) == _msgSender(), "QNFTGov: caller is not QNFT");
        _;
    }

    receive() external payable {}

    fallback() external payable {}

    function initialize(address _settings, address _qnftSettings)
        external
        initializer
    {
        __Context_init();
        __ReentrancyGuard_init();

        settings = IQSettings(_settings);
        qnftSettings = IQNFTSettings(_qnftSettings);
    }

    /**
     * @dev votes on a given multisig wallet with the locked qstk balance of the user
     */
    function voteGovernanceAddress(address multisig) public {
        (bool mintStarted, bool mintFinished, , ) = voteStatus();
        require(mintStarted, "QNFTGov: mint not started");
        require(mintFinished, "QNFTGov: NFT sale not ended");

        require(
            canVote[msg.sender],
            "QNFTGov: caller has no locked qstk balance"
        );

        if (voteAddressByVoter[msg.sender] != address(0x0)) {
            voteResult[voteAddressByVoter[msg.sender]]--;
        }

        voteResult[multisig]++;
        voteAddressByVoter[msg.sender] = multisig;

        emit VoteGovernanceAddress(msg.sender, multisig);
    }

    /**
     * @dev withdraws to the governance address if it has enough vote amount
     */
    function withdrawToGovernanceAddress(address payable multisig)
        public
        nonReentrant
    {
        (, , bool ableToWithdraw, ) = voteStatus();
        require(ableToWithdraw, "QNFTGov: wait until vote end time");

        require(
            voteResult[multisig] >= (totalUsers * VOTE_QUORUM) / PERCENT_MAX,
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
        onlyManager
        nonReentrant
    {
        (, , , bool ableToSafeWithdraw) = voteStatus();
        require(ableToSafeWithdraw, "QNFTGov: wait until safe vote end time");

        uint256 amount = address(this).balance;

        multisig.transfer(amount);

        emit SafeWithdraw(msg.sender, multisig, amount);
    }

    /**
     * @dev updates the votes amount of the given user
     */
    function updateVote(
        address user,
        uint256 originAmount, // original amount before change
        uint256 currentAmount // current amount after change
    ) public override onlyQnft {
        require(originAmount != currentAmount, "QNFTGov: no changes");
        if (originAmount == 0) {
            canVote[user] = true;
            totalUsers++;
        } else if (currentAmount == 0) {
            if (voteAddressByVoter[user] != address(0x0)) {
                voteResult[voteAddressByVoter[user]]--;
                voteAddressByVoter[user] = address(0x0);
            }
            canVote[user] = false;
            totalUsers--;
        }

        emit UpdateVote(user, originAmount, currentAmount);
    }

    /**
     * @dev sets QNFT contract address
     */
    function setQNft(IQNFT _qnft) public onlyManager {
        require(qnft != _qnft, "QNFTGov: QNFT already set");

        qnft = _qnft;
    }

    /**
     * @dev returns the current vote status
     */
    function voteStatus()
        public
        view
        returns (
            bool mintStarted,
            bool mintFinished,
            bool ableToWithdraw,
            bool ableToSafeWithdraw
        )
    {
        mintStarted = qnftSettings.mintStarted();
        mintFinished = qnftSettings.mintFinished();
        if (mintStarted && mintFinished) {
            uint256 mintEndTime = qnftSettings.mintEndTime();
            ableToWithdraw = block.timestamp >= mintEndTime + MIN_VOTE_DURATION;
            ableToSafeWithdraw =
                block.timestamp >= mintEndTime + SAFE_VOTE_END_DURATION;
        }
    }
}