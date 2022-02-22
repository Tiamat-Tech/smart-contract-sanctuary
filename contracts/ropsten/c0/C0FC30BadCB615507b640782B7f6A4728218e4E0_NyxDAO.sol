// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTContract {
    address[] public holders;

    function getHolders()
        public view
        returns (address[] memory)
    {
        return holders;
    }

}

contract NyxDAO is ReentrancyGuard, AccessControl {
    bytes32 public constant CONTRIBUTOR_ROLE = keccak256("CONTRIBUTOR");
    bytes32 public constant STAKEHOLDER_ROLE = keccak256("STAKEHOLDER");
    uint32 constant minimumVotingPeriod = 1 weeks;
    uint256 numOfProposals;

    struct InvestmentProposal {
        uint256 id;
        uint256 amount;
        address payable tokenAddress;
        uint256 livePeriod;
        uint256 votesFor;
        uint256 votesAgainst;
        string description;
        bool votingPassed;
        bool paid;
        address proposer;
        address paidBy;
    }

    mapping(uint256 => InvestmentProposal) private investmentProposalMapping;
    mapping(address => uint256[]) private stakeholderVotes;
    mapping(address => uint256) private contributors;
    mapping(address => uint256) public stakeholders;


    // Events
    ///////////////////

    event ContributionReceived(address indexed fromAddress, uint256 amount);
    event NewInvestmentProposal(address indexed proposer, uint256 amount);
    event PaymentTransfered(
        address indexed stakeholder,
        address indexed tokenAddress,
        uint256 amount
    );

    // Modifiers
    ///////////////////

    modifier onlyStakeholder(string memory message) {
        require(hasRole(STAKEHOLDER_ROLE, msg.sender), message);
        _;
    }

    modifier onlyContributor(string memory message) {
        require(hasRole(CONTRIBUTOR_ROLE, msg.sender), message);
        _;
    }

    // Functions
    ////////////////////
    
    function createInvestmentProposal(string calldata description, address tokenAddress, uint256 amount)
        external
        onlyStakeholder("Only stakeholders are allowed to create proposals")
    {
        uint256 proposalId = numOfProposals++;
        InvestmentProposal storage proposal = investmentProposalMapping[proposalId];
        proposal.id = proposalId;
        proposal.proposer = payable(msg.sender);
        proposal.description = description;
        proposal.tokenAddress = payable(tokenAddress);
        proposal.amount = amount;
        proposal.livePeriod = block.timestamp + minimumVotingPeriod;

        emit NewInvestmentProposal(msg.sender, amount);
    }

    function vote(uint256 proposalId, bool supportProposal)
        external
        onlyStakeholder("Only stakeholders are allowed to vote")
    {
        InvestmentProposal storage investmentProposal = investmentProposalMapping[proposalId];

        votable(investmentProposal);

        if (supportProposal) investmentProposal.votesFor++;
        else investmentProposal.votesAgainst++;

        stakeholderVotes[msg.sender].push(investmentProposal.id);
    }

    function votable(InvestmentProposal storage investmentProposal) private {
        if (
            investmentProposal.votingPassed ||
            investmentProposal.livePeriod <= block.timestamp
        ) {
            investmentProposal.votingPassed = true;
            revert("Voting period has passed on this proposal");
        }

        uint256[] memory tempVotes = stakeholderVotes[msg.sender];
        for (uint256 votes = 0; votes < tempVotes.length; votes++) {
            if (investmentProposal.id == tempVotes[votes])
                revert("This stakeholder already voted on this proposal");
        }
    }

    function payInvestment(uint256 proposalId)
        external
        onlyStakeholder("Only stakeholders are allowed to make payments")
    {
        InvestmentProposal storage investmentProposal = investmentProposalMapping[proposalId];

        if (investmentProposal.paid)
            revert("Payment has been made to this investment");

        if (investmentProposal.votesFor <= investmentProposal.votesAgainst)
            revert(
                "The proposal does not have the required amount of votes to pass"
            );

        investmentProposal.paid = true;
        investmentProposal.paidBy = msg.sender;

        emit PaymentTransfered(
            msg.sender,
            investmentProposal.tokenAddress,
            investmentProposal.amount
        );

        return investmentProposal.tokenAddress.transfer(investmentProposal.amount);
    }

    receive() external payable {
        emit ContributionReceived(msg.sender, msg.value);
    }

    function makeStakeholderOLD(uint256 amount) external {
        address account = msg.sender;
        uint256 amountContributed = amount;
        if (!hasRole(STAKEHOLDER_ROLE, account)) {
            uint256 totalContributed =
                contributors[account] + amountContributed;
            if (totalContributed >= 5 ether) {
                stakeholders[account] = totalContributed;
                contributors[account] += amountContributed;
                _setupRole(STAKEHOLDER_ROLE, account);
                _setupRole(CONTRIBUTOR_ROLE, account);
            } else {
                contributors[account] += amountContributed;
                _setupRole(CONTRIBUTOR_ROLE, account);
            }
        } else {
            contributors[account] += amountContributed;
            stakeholders[account] += amountContributed;
        }
    }

    function makeStakeholder()
        external
    {
        // address nft_contract_address = 0x446Fa8CB7339288f169bb10E8450AbD00d556Dfb;
        address nft_contract_address = 0xD7ACd2a9FD159E69Bb102A1ca21C9a3e3A5F771B;
        
        // M1
        // address[] memory holders = nft_contract_address.call(bytes4(keccak256("getHolders()")));
        // M2
        NFTContract nft_contract = NFTContract(nft_contract_address);
        address[] memory holders = nft_contract.getHolders();

        for (uint256 i = 0; i < holders.length; i++)
        {
            address addr = holders[i];
            stakeholders[addr] = 1;
        }

    }

    function getProposals()
        public
        view
        returns (InvestmentProposal[] memory props)
    {
        props = new InvestmentProposal[](numOfProposals);

        for (uint256 index = 0; index < numOfProposals; index++) {
            props[index] = investmentProposalMapping[index];
        }
    }

    function getProposal(uint256 proposalId)
        public
        view
        returns (InvestmentProposal memory)
    {
        return investmentProposalMapping[proposalId];
    }

    function getStakeholderVotes()
        public
        view
        onlyStakeholder("User is not a stakeholder")
        returns (uint256[] memory)
    {
        return stakeholderVotes[msg.sender];
    }

    function getStakeholderBalance()
        public
        view
        onlyStakeholder("User is not a stakeholder")
        returns (uint256)
    {
        return stakeholders[msg.sender];
    }

    function isStakeholder() public view returns (bool) {
        return stakeholders[msg.sender] > 0;
    }

    function getContributorBalance()
        public
        view
        onlyContributor("User is not a contributor")
        returns (uint256)
    {
        return contributors[msg.sender];
    }

    function isContributor() public view returns (bool) {
        return contributors[msg.sender] > 0;
    }
}