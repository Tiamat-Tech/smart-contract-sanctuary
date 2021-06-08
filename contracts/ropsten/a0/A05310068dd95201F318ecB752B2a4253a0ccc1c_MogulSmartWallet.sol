//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
import "./matic/BasicMetaTransaction.sol";
import "./openzeppelinModified/AccessControl.sol";
import "./utils/Pausable.sol";

contract MogulSmartWallet is
    BasicMetaTransaction,
    Initializable,
    AccessControl,
    ERC721Holder,
    ERC1155Holder,
    Pausable
{
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private guardiansSet;

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    address public owner;
    uint256 public minGuardianVotesRequired;
    uint256 public pausedUntil;
    uint256 public pausePeriod;

    struct ChangeOwnerProposal {
        uint256 voteAmt;
        address newOwnerAddress;
        bool active;
    }
    mapping(address => bool) public changeOwnerProposalYesVotes;

    ChangeOwnerProposal public currChangeOwnerProposal;

    event Received(address sender, uint256 nativeCurrencyAmt);

    /**
     * @dev Initialize function to be used by Factory Contract.
     * Owner is set and will be assigned OWNER_ROLE and DEFAULT_ADMIN_ROLE,
     * guardians will be assigned GUARDIAN_ROLE,
     * minGuardianVotesRequired is set,
     * pausePeriod is set.
     *
     * Parameters:
     *
     * - _owner: owner of the smart wallet.
     * - _guardians: initial guardians of the smart wallet.
     * - _minGuardianVotesRequired: minimum guardian votes required
     * to change owners.
     * - _pausePeriod: number of seconds to pause the
     * smart wallet owner actions  when locked
     *
     * Requirements:
     *
     * - _guardians must have more unique address than _minGuardianVotesRequired.
     */
    function initialize(
        address _owner,
        address[] memory _guardians,
        uint256 _minGuardianVotesRequired,
        uint256 _pausePeriod
    ) public initializer {
        owner = _owner;
        _setupRole(OWNER_ROLE, _owner);
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);

        for (uint256 i = 0; i < _guardians.length; i++) {
            EnumerableSet.add(guardiansSet, _guardians[i]);
            _setupRole(GUARDIAN_ROLE, _guardians[i]);
        }

        require(
            EnumerableSet.length(guardiansSet) >= _minGuardianVotesRequired,
            "Minimum Guardian Votes required must be <= guardian addresses supplied"
        );

        minGuardianVotesRequired = _minGuardianVotesRequired;
        pausePeriod = _pausePeriod;
    }

    /**
     * @dev Adds new guardians to the smart wallet.
     *
     * Parameters:
     *
     * - newGuardians: new guardians of smart wallet.
     *
     * Requirements:
     *
     * - caller must have OWNER_ROLE
     * - smart wallet is not paused
     */
    function addGuardians(address[] memory newGuardians) public whenNotPaused {
        require(hasRole(OWNER_ROLE, msgSender()), "Caller is not an owner");

        for (uint256 i = 0; i < newGuardians.length; i++) {
            EnumerableSet.add(guardiansSet, newGuardians[i]);
            _setupRole(GUARDIAN_ROLE, newGuardians[i]);
        }
    }

    /**
     * @dev Removes guardians from the smart wallet.
     *
     * Parameters:
     *
     * - newGuardians: new guardians to remove from smart wallet.
     *
     * Requirements:
     *
     * - caller must have OWNER_ROLE
     * - the number of guardians remaining must be at least minGuardianVotesRequired
     * - smart wallet is not paused
     */
    function removeGuardians(address[] memory newGuardians)
        public
        whenNotPaused
    {
        require(hasRole(OWNER_ROLE, msgSender()), "Caller is not an owner");
        require(
            (EnumerableSet.length(guardiansSet) - newGuardians.length) >=
                minGuardianVotesRequired,
            "Removing guardians beyond minimum guardian votes required"
        );

        for (uint256 i = 0; i < newGuardians.length; i++) {
            EnumerableSet.remove(guardiansSet, newGuardians[i]);
            _revokeRole(GUARDIAN_ROLE, newGuardians[i]);
        }
    }

    /**
     * @dev Returns the amount of guardians of the smart wallet.
     */
    function getGuardiansAmount() public view returns (uint256) {
        return EnumerableSet.length(guardiansSet);
    }

    /**
     * @dev Returns 100 of guardians of the smart wallet.
     */
    function getAllGuardians() public view returns (address[100] memory) {
        address[100] memory guardians;
        for (
            uint256 i = 0;
            i < EnumerableSet.length(guardiansSet) && i < 100;
            i++
        ) {
            guardians[i] = EnumerableSet.at(guardiansSet, i);
        }
        return guardians;
    }

    /**
     * @dev Returns if accountAddress is a guardian of the smart wallet.
     *
     * Parameters:
     *
     * - accountAddress: the address in question.
     */
    function isGuardian(address accountAddress) public view returns (bool) {
        return
            EnumerableSet.contains(guardiansSet, accountAddress) &&
            hasRole(GUARDIAN_ROLE, accountAddress);
    }

    /**
     * @dev Owner function to change the owner of the smart wallet.
     * The guardian change owner proposal will be cancelled.
     *
     * Parameters:
     *
     * - newOwner: new newOwner of smart wallet.
     *
     * Requirements:
     *
     * - caller must have OWNER_ROLE
     * - smart wallet is not paused
     */
    function changeOwnerByOwner(address newOwner) public whenNotPaused {
        require(hasRole(OWNER_ROLE, msgSender()), "Caller is not owner");
        owner = newOwner;
        _setupRole(OWNER_ROLE, owner);
        _revokeRole(OWNER_ROLE, msgSender());

        for (uint256 i = 0; i < EnumerableSet.length(guardiansSet); i++) {
            delete changeOwnerProposalYesVotes[
                EnumerableSet.at(guardiansSet, i)
            ];
        }

        currChangeOwnerProposal.voteAmt = 0;
        currChangeOwnerProposal.newOwnerAddress = address(0);
        currChangeOwnerProposal.active = false;
    }

    /**
     * @dev Guardian function to create a proposal to change the owner of
     * the smart wallet. The proposer's vote for the proposal is auto casted.
     *
     * Parameters:
     *
     * - newOwner: new newOwner of smart wallet.
     *
     * Requirements:
     *
     * - caller must have GUARDIAN_ROLE
     * - there is no proposal currently active
     */
    function createChangeOwnerProposal(address newOwner) public {
        require(
            isGuardian(msgSender()),
            "Only Guardians can propose owner change"
        );
        require(
            currChangeOwnerProposal.active == false,
            "Change owner proposal is already active"
        );

        currChangeOwnerProposal.active = true;
        currChangeOwnerProposal.voteAmt++;
        currChangeOwnerProposal.newOwnerAddress = newOwner;
        changeOwnerProposalYesVotes[msgSender()] = true;
    }

    /**
     * @dev Guardian function to vote on a proposal to change the owner
     * of the smart wallet.
     *
     * Requirements:
     *
     * - caller must have GUARDIAN_ROLE
     * - a proposal is currently active
     * - caller has not voted yet
     */
    function addVoteChangeOwnerProposal() public {
        require(
            isGuardian(msgSender()),
            "Only Guardians can vote on owner change"
        );
        require(
            currChangeOwnerProposal.active == true,
            "Change owner proposal is not active"
        );
        require(
            changeOwnerProposalYesVotes[msgSender()] == false,
            "Guardian has already voted"
        );

        changeOwnerProposalYesVotes[msgSender()] = true;
        currChangeOwnerProposal.voteAmt++;
    }

    /**
     * @dev Guardian function to remove vote on a proposal.
     * If votes to the proposal reduces to 0, the proposal is cancelled.
     *
     * Requirements:
     *
     * - caller must have GUARDIAN_ROLE
     * - a proposal is currently active
     * - caller has voted
     */
    function removeVoteChangeOwnerProposal() public {
        require(
            isGuardian(msgSender()),
            "Only Guardians can remove vote on owner change"
        );
        require(
            currChangeOwnerProposal.active == true,
            "Change owner proposal is not active"
        );
        require(
            changeOwnerProposalYesVotes[msgSender()] == true,
            "Guardian has not voted"
        );
        changeOwnerProposalYesVotes[msgSender()] = false;
        currChangeOwnerProposal.voteAmt--;

        if (currChangeOwnerProposal.voteAmt == 0) {
            currChangeOwnerProposal.newOwnerAddress = address(0);
            currChangeOwnerProposal.active = false;
        }
    }

    /**
     * @dev Guardian function to execute a change owner proposal.
     * The smart wallet will have a new owner specified in the proposal,
     * and the proposal will be reset.
     *
     * Parameters:
     *
     * - newOwner: new newOwner of smart wallet.
     *
     * Requirements:
     *
     * - caller must have GUARDIAN_ROLE
     * - a proposal is currently active
     * - minimum guardian votes are met
     */
    function changeOwnerByGuardian() public {
        require(isGuardian(msgSender()), "Caller is not a guardian");
        require(
            currChangeOwnerProposal.active == true,
            "Change owner proposal is not active"
        );
        require(
            currChangeOwnerProposal.voteAmt >= minGuardianVotesRequired,
            "Minimum guardian votes not met"
        );

        _setupRole(OWNER_ROLE, currChangeOwnerProposal.newOwnerAddress);
        _revokeRole(OWNER_ROLE, owner);
        owner = currChangeOwnerProposal.newOwnerAddress;

        for (uint256 i = 0; i < EnumerableSet.length(guardiansSet); i++) {
            delete changeOwnerProposalYesVotes[
                EnumerableSet.at(guardiansSet, i)
            ];
        }
        currChangeOwnerProposal.voteAmt = 0;
        currChangeOwnerProposal.newOwnerAddress = address(0);
        currChangeOwnerProposal.active = false;
    }

    /**
     * @dev Owner function to set the minimum guardian votes
     * needed to execute a change owner proposal.
     *
     * Parameters:
     *
     * - _minGuardianVotesRequired: new newOwner of smart wallet.
     *
     * Requirements:
     *
     * - caller must have OWNER_ROLE
     * - minimum guardian votes needed is at most the amount of guardians
     * - smart wallet is not paused
     */
    function setMinGuardianVotesRequired(uint256 _minGuardianVotesRequired)
        public
        whenNotPaused
    {
        require(hasRole(OWNER_ROLE, msgSender()), "Caller is not owner");
        require(
            EnumerableSet.length(guardiansSet) >= _minGuardianVotesRequired,
            "Minimum Guardian Votes required must be <= guardian addresses supplied"
        );

        minGuardianVotesRequired = _minGuardianVotesRequired;
    }

    /**
     * @dev Owner function to approve ERC20 token.
     *
     * Parameters:
     *
     * - erc20Address: contract address of ERC20 token.
     * - spender: spender's address.
     * - amt: token amount mantissa to be approved.
     *
     * Requirements:
     *
     * - caller must have OWNER_ROLE
     * - smart wallet is not paused
     */
    function approveERC20(
        address erc20Address,
        address spender,
        uint256 amt
    ) public whenNotPaused {
        require(hasRole(OWNER_ROLE, msgSender()), "Caller is not owner");
        IERC20(erc20Address).approve(spender, amt);
    }

    /**
     * @dev Owner function to transfer ERC20 token.
     *
     * Parameters:
     *
     * - erc20Address: contract address of ERC20 token.
     * - recipient: recipient's address.
     * - amt: token amount mantissa to be transfered.
     *
     * Requirements:
     *
     * - caller must have OWNER_ROLE
     * - smart wallet is not paused
     */
    function transferERC20(
        address erc20Address,
        address recipient,
        uint256 amt
    ) public whenNotPaused {
        require(hasRole(OWNER_ROLE, msgSender()), "Caller is not owner");
        IERC20(erc20Address).transfer(recipient, amt);
    }

    /**
     * @dev Owner function to transfer ERC20 token from a
     * specific address.
     *
     * Parameters:
     *
     * - erc20Address: contract address of ERC20 token.
     * - sender: sender's address.
     * - recipient: recipient's address.
     * - amt: token amount mantissa to be transfered.
     *
     * Requirements:
     *
     * - caller must have OWNER_ROLE
     * - smart wallet is not paused
     */
    function transferFromERC20(
        address erc20Address,
        address sender,
        address recipient,
        uint256 amt
    ) public whenNotPaused {
        require(hasRole(OWNER_ROLE, msgSender()), "Caller is not owner");
        IERC20(erc20Address).transferFrom(sender, recipient, amt);
    }

    /**
     * @dev Owner function to transfer ERC721 token from a
     * specific address.
     *
     * Parameters:
     *
     * - erc721Address: contract address of ERC721 token.
     * - sender: sender's address.
     * - recipient: recipient's address.
     * - tokenId: token's id.
     *
     * Requirements:
     *
     * - caller must have OWNER_ROLE
     * - smart wallet is not paused
     */
    function transferFromERC721(
        address erc721Address,
        address sender,
        address recipient,
        uint256 tokenId
    ) public whenNotPaused {
        require(hasRole(OWNER_ROLE, msgSender()), "Caller is not owner");
        IERC721(erc721Address).transferFrom(sender, recipient, tokenId);
    }

    /**
     * @dev Owner function to safe transfer ERC721 token from a
     * specific address.
     *
     * Parameters:
     *
     * - erc721Address: contract address of ERC721 token.
     * - sender: sender's address.
     * - recipient: recipient's address.
     * - tokenId: token's id.
     *
     * Requirements:
     *
     * - caller must have OWNER_ROLE
     * - smart wallet is not paused
     */
    function safeTransferFromERC721(
        address erc721Address,
        address sender,
        address recipient,
        uint256 tokenId
    ) public whenNotPaused {
        require(hasRole(OWNER_ROLE, msgSender()), "Caller is not owner");
        IERC721(erc721Address).safeTransferFrom(sender, recipient, tokenId);
    }

    /**
     * @dev Owner function to safe transfer ERC721 token from a
     * specific address.
     *
     * Parameters:
     *
     * - erc721Address: contract address of ERC721 token.
     * - sender: sender's address.
     * - recipient: recipient's address.
     * - tokenId: token's id.
     * - data: token transfer data.
     *
     * Requirements:
     *
     * - caller must have OWNER_ROLE
     * - smart wallet is not paused
     */
    function safeTransferFromERC721(
        address erc721Address,
        address sender,
        address recipient,
        uint256 tokenId,
        bytes memory data
    ) public whenNotPaused {
        require(hasRole(OWNER_ROLE, msgSender()), "Caller is not owner");
        IERC721(erc721Address).safeTransferFrom(
            sender,
            recipient,
            tokenId,
            data
        );
    }

    /**
     * @dev Owner function to approve ERC721 token.
     *
     * Parameters:
     *
     * - erc721Address: contract address of ERC721 token.
     * - spender: spender's address.
     * - tokenId: token's id.
     *
     * Requirements:
     *
     * - caller must have OWNER_ROLE
     * - smart wallet is not paused
     */
    function approveERC721(
        address erc721Address,
        address spender,
        uint256 tokenId
    ) public whenNotPaused {
        require(hasRole(OWNER_ROLE, msgSender()), "Caller is not owner");
        IERC721(erc721Address).approve(spender, tokenId);
    }

    /**
     * @dev Owner function to approve all transfers of a
     * ERC721 token.
     *
     * Parameters:
     *
     * - erc721Address: contract address of ERC721 token.
     * - operator: operator's address.
     * - approved: the approval status.
     *
     * Requirements:
     *
     * - caller must have OWNER_ROLE
     * - smart wallet is not paused
     */
    function setApprovalForAllERC721(
        address erc721Address,
        address operator,
        bool approved
    ) public whenNotPaused {
        require(hasRole(OWNER_ROLE, msgSender()), "Caller is not owner");
        IERC721(erc721Address).setApprovalForAll(operator, approved);
    }

    /**
     * @dev Owner function to safe transfer ERC1155 token from a
     * specific address.
     *
     * Parameters:
     *
     * - erc1155Address: contract address of ERC1155 token.
     * - sender: sender's address.
     * - recipient: recipient's address.
     * - tokenId: token's id.
     * - amt: token amount to send.
     * - data: token transfer data.
     *
     * Requirements:
     *
     * - caller must have OWNER_ROLE
     * - smart wallet is not paused
     */
    function safeTransferFromERC1155(
        address erc1155Address,
        address sender,
        address recipient,
        uint256 tokenId,
        uint256 amt,
        bytes memory data
    ) public whenNotPaused {
        require(hasRole(OWNER_ROLE, msgSender()), "Caller is not owner");
        IERC1155(erc1155Address).safeTransferFrom(
            sender,
            recipient,
            tokenId,
            amt,
            data
        );
    }

    /**
     * @dev Owner function to safe batch transfer ERC1155 token from a
     * specific address.
     *
     * Parameters:
     *
     * - erc1155Address: contract address of ERC1155 token.
     * - sender: sender's address.
     * - recipient: recipient's address.
     * - tokenIds: tokens' ids.
     * - amts: token amounts to send.
     * - data: token transfer data.
     *
     * Requirements:
     *
     * - caller must have OWNER_ROLE
     * - smart wallet is not paused
     */
    function safeBatchTransferFromERC1155(
        address erc1155Address,
        address sender,
        address recipient,
        uint256[] memory tokenIds,
        uint256[] memory amts,
        bytes memory data
    ) public whenNotPaused {
        require(hasRole(OWNER_ROLE, msgSender()), "Caller is not owner");
        IERC1155(erc1155Address).safeBatchTransferFrom(
            sender,
            recipient,
            tokenIds,
            amts,
            data
        );
    }

    /**
     * @dev Owner function to approve all transfers of a
     * ERC1155 token.
     *
     * Parameters:
     *
     * - erc1155Address: contract address of ERC1155 token.
     * - operator: operator's address.
     * - approved: the approval status.
     *
     * Requirements:
     *
     * - caller must have OWNER_ROLE
     * - smart wallet is not paused
     */
    function setApprovalForAllERC1155(
        address erc1155Address,
        address operator,
        bool approved
    ) public whenNotPaused {
        require(hasRole(OWNER_ROLE, msgSender()), "Caller is not owner");
        IERC1155(erc1155Address).setApprovalForAll(operator, approved);
    }

    /**
     * @dev Owner function to transfer Native token
     * (ETH on mainnet, MATIC on Polygon, BNB on Bsc).
     *
     * Parameters:
     *
     * - recipient: recipient's address.
     * - amt: token amount mantissa to be transfered.
     *
     * Requirements:
     *
     * - caller must have OWNER_ROLE
     * - smart wallet is not paused
     */
    function transferNativeToken(address payable recipient, uint256 amt)
        public
        whenNotPaused
    {
        require(hasRole(OWNER_ROLE, msgSender()), "Caller is not owner");
        recipient.transfer(amt);
    }

    /**
     * @dev Owner function to pause all owner functions for pausePeriod
     * amount of seconds. Guardians will still have access to the
     * smart wallet functions. Call this function ASAP when the
     * smart wallet is compromised.
     *
     * Requirements:
     *
     * - caller must have OWNER_ROLE
     * - smart wallet is not paused
     */
    function lockWallet() public whenNotPaused {
        require(hasRole(OWNER_ROLE, msgSender()), "Caller is not owner");
        _pause();
        pausedUntil = block.timestamp + pausePeriod;
    }

    /**
     * @dev Owner function to unpause all owner functions.
     *
     * Requirements:
     *
     * - caller must have OWNER_ROLE
     * - pause period is passed
     * - smart wallet is paused
     */
    function unlockWallet() public whenPaused {
        require(hasRole(OWNER_ROLE, msgSender()), "Caller is not owner");
        require(
            block.timestamp >= pausedUntil,
            "This account's lock period is not over"
        );
        _unpause();
    }

    receive() external payable {
        emit Received(msgSender(), msg.value);
    }
}