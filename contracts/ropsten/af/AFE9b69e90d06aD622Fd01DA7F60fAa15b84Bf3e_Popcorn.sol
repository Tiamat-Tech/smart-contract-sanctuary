// SPDX-License-Identifier: MIT

pragma solidity ^0.7.4;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract Popcorn {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Defintions
    struct Proposal {
        address proposer;
        bytes32 crossChainHash;
        uint256 value;
        address recipient;
        address token;
        uint256 releaseBlock;
    }
    uint256[] internal pendingProposals;
    uint256 public proposalsCounter;
    mapping(uint256 => Proposal) internal proposals;

    //event ProposalCreated(uint256 indexed proposalID);

    constructor() {}

    function createTransactionProposal(
        bytes32[] memory _crossChainHash,
        uint256[] memory _amount,
        address[] memory _recipient,
        address[] memory _token
    ) public {
        for (uint256 i = 0; i < _recipient.length; i++) {
            proposalsCounter = proposalsCounter.add(1);
            _createTransactionProposal(
                proposalsCounter,
                _crossChainHash[i],
                _amount[i],
                _recipient[i],
                _token[i]
            );
        }
    }

    function _createTransactionProposal(
        uint256 _proposalID,
        bytes32 _crossChainHash,
        uint256 _amount,
        address _recipient,
        address _token
    ) internal {
        Proposal memory newProposal;
        newProposal.proposer = msg.sender;
        newProposal.crossChainHash = _crossChainHash;
        newProposal.value = _amount;
        newProposal.recipient = _recipient;
        newProposal.token = _token;
        newProposal.releaseBlock = block.number.add(20); //block.number.add(100);

        //newProposal.pendingIndex = pendingProposals.length.add(1);
        //newProposal._type = 1; //Transaction proposal
        pendingProposals.push(_proposalID);
        proposals[_proposalID] = newProposal;
        //emit ProposalCreated(_proposalID);
    }
}