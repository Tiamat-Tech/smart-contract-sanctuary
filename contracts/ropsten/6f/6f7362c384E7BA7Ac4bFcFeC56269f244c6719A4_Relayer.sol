// SPDX-License-Identifier: MIT

pragma solidity ^0.6.11;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IResolver {
    function setAddr(bytes32 node, address _addr) external;
}

interface IENS {
    function setOwner(bytes32 node, address owner) external;
}

interface IETHRegitrar {
    function renew(string calldata name, uint256 duration) external payable;

    function rentPrice(string memory name, uint256 duration)
        external
        view
        returns (uint256);
}

contract Relayer {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Defintions
    struct Proposal {
        address proposer;
        uint256 _type; // 1 means transaction proposal,2 means New token proposal ,3 set ENS new owner ,4 set new resolve address ,5 renew ENS Name
        bytes32 crossChainHash;
        uint256 value; //if type==1 means transactions amount,type =2 means new fees value, type=5 means new duration
        address _address; //trxRecipient;1 meant  trxRecipient,3 new owner ,4 new resolving address
        address token; //if type==1 means transaction token,if type=2 means supported token
        uint256 releaseBlock;
        uint256 status;
        uint256 zefiAgainstVotes;
        uint256 zefi_eth_uni_lpAgainstVotes;
        uint256 pendingIndex;
        uint256 tokenProposalPaidFees;
        mapping(address => bool) votedAgainst;
    }
    struct Token {
        address token;
        uint256 fees;
        uint256 index; // starting from 1;
    }
    address private zefi_eth_uni_lp;
    address private zefi;
    bytes32 nodeHashedName;
    uint256 public _honestyCreditTotal;
    string private _NAME = "chess";
    IENS iEns;
    IResolver iResolver;
    IETHRegitrar iETHRegitrar;
    address[] private rewardAddresses;
    address[] private voteBalancesList;
    address[] private supportedTokensList;
    uint256[] private pendingProposals;
    mapping(address => uint256) public _totalSupply;
    mapping(address => uint256) public bondingBalance;
    mapping(uint256 => address[]) private proposalVoters;
    mapping(address => bytes32) private version;
    mapping(address => uint256) public _honestyCredit;
    mapping(address => uint256) public _voteTotalSupply;
    mapping(address => mapping(address => uint256)) public collectedFees;
    mapping(address => mapping(address => uint256)) public _voteBalances;
    mapping(address => mapping(address => uint256)) public _balances;
    mapping(address => Token) private supportedTokens;
    mapping(uint256 => Proposal) public proposals;

    event ProposalCreated(uint256 indexed proposalID);
    event VoteBalancChanged();

    constructor(
        address _zefi_eth_uni_lp,
        address _zefi,
        bytes32 _node,
        IENS _iEns,
        IResolver _iResolver,
        IETHRegitrar _iETHRegitrar
    ) public {
        zefi_eth_uni_lp = _zefi_eth_uni_lp;
        zefi = _zefi;
        iResolver = _iResolver;
        iEns = _iEns;
        nodeHashedName = _node;
        iETHRegitrar = _iETHRegitrar;
    }

    function noZeroAmount(uint256 _amount) internal pure {
        require(_amount > 0, "Amount is zero");
    }

    function _isValid(uint256 _proposalID) internal view {
        require(
            proposals[_proposalID].status == 0 && pendingProposals.length < 100,
            "Prop ID is used or count > 100"
        );
    }

    function _isValidBalance() internal view {
        require(
            bondingBalance[msg.sender] >= 0.2 ether && msg.value == 0.05 ether,
            "bonding or paid ether not enough "
        );
    }

    function isPending(uint256 _proposalID) internal view {
        require(proposals[_proposalID].status == 1, "processed before");
    }

    function bondFees() external payable {
        noZeroAmount(msg.value);
        bondingBalance[msg.sender] = bondingBalance[msg.sender].add(msg.value);
    }

    function unbondFees() external {
        uint256 _amount = bondingBalance[msg.sender];
        require(pendingProposals.length == 0, "Still pending proposals!");
        noZeroAmount(_amount);
        bondingBalance[msg.sender] = 0;
        msg.sender.transfer(_amount);
    }

    function depositToken(uint256 _amount, address _token) external {
        uint256 _rate;
        uint256 _balance = _balances[msg.sender][_token].add(_amount);
        uint256 _total = _totalSupply[_token].add(_amount);
        _rate = _balance.mul(100).div(_total);
        require(
            _rate >= 1 && (_token == zefi_eth_uni_lp || _token == zefi),
            "not accepted"
        );
        noZeroAmount(_amount);
        IERC20 _erc20Token = IERC20(_token);
        _honestyCredit[msg.sender] = _honestyCredit[msg.sender].add(1);
        _honestyCreditTotal = _honestyCreditTotal.add(1);
        _totalSupply[_token] = _totalSupply[_token].add(_amount);
        _balances[msg.sender][_token] = _balances[msg.sender][_token].add(
            _amount
        );
        _voteTotalSupply[_token] = _voteTotalSupply[_token].add(_amount);
        _voteBalances[msg.sender][_token] = _balances[msg.sender][_token];
        bool notExist = true;
        for (uint256 i = 0; i < voteBalancesList.length; i++) {
            if (voteBalancesList[i] == msg.sender) {
                notExist = false;
                break;
            }
        }
        if (notExist) {
            voteBalancesList.push(msg.sender);
        }
        _erc20Token.safeTransferFrom(msg.sender, address(this), _amount);
        emit VoteBalancChanged();
    }

    function withdrawToken(address _token) external {
        uint256 _amount = _balances[msg.sender][_token];
        noZeroAmount(_amount);
        IERC20 _erc20Token = IERC20(_token);
        _totalSupply[_token] = _totalSupply[_token].sub(_amount);
        _balances[msg.sender][_token] = 0;
        _voteTotalSupply[_token] = _voteTotalSupply[_token].sub(
            _voteBalances[msg.sender][_token]
        );
        _voteBalances[msg.sender][_token] = 0;
        _honestyCreditTotal = _honestyCreditTotal.sub(
            _honestyCredit[msg.sender]
        );
        _honestyCredit[msg.sender] = 0;
        for (uint256 i = 0; i < voteBalancesList.length; i++) {
            if (voteBalancesList[i] == msg.sender) {
                voteBalancesList[i] = voteBalancesList[voteBalancesList
                    .length
                    .sub(1)];
                voteBalancesList.pop();
                break;
            }
        }
        _erc20Token.safeTransfer(msg.sender, _amount);
        emit VoteBalancChanged();
    }

    function createTransactionProposal(
        uint256 _proposalID,
        bytes32 _crossChainHash,
        uint256 _amount,
        address _recipient,
        address _token
    ) external {
        _isValid(_proposalID);
        Proposal memory newProposal;
        newProposal.proposer = msg.sender;
        newProposal.crossChainHash = _crossChainHash;
        newProposal.value = _amount;
        newProposal._address = _recipient;
        newProposal.token = _token;
        newProposal.releaseBlock = block.number.add(20); //block.number.add(100);
        newProposal.status = 1;
        newProposal.pendingIndex = pendingProposals.length.add(1);
        newProposal._type = 1; //Transaction proposal
        pendingProposals.push(_proposalID);
        proposals[_proposalID] = newProposal;
        emit ProposalCreated(_proposalID);
    }

    function createtokenNewFeesProposal(
        uint256 _proposalID,
        uint256 _newFees,
        address _token
    ) external payable {
        _isValid(_proposalID);
        _isValidBalance();
        Proposal memory newProposal;
        newProposal.proposer = msg.sender;
        newProposal.value = _newFees;
        newProposal.token = _token;
        newProposal.releaseBlock = block.number.add(20); //block.number.add(100);
        newProposal.status = 1;
        newProposal.pendingIndex = pendingProposals.length.add(1);
        newProposal._type = 2; //Token proposal
        newProposal.tokenProposalPaidFees = msg.value;
        pendingProposals.push(_proposalID);
        proposals[_proposalID] = newProposal;
        emit ProposalCreated(_proposalID);
    }

    function createSetNewOwnerProposal(
        //3 set ENS new owner ,4 set new resolve address ,5 renew ENS Name
        uint256 _proposalID,
        address _newENSOwner
    ) external payable {
        _isValid(_proposalID);
        _isValidBalance();
        Proposal memory newProposal;
        newProposal.proposer = msg.sender;
        newProposal.releaseBlock = block.number.add(20); //block.number.add(100);
        newProposal.status = 1;
        newProposal._address = _newENSOwner;
        newProposal._type = 3; //new ENS Owner proposal
        newProposal.pendingIndex = pendingProposals.length.add(1);
        newProposal.tokenProposalPaidFees = msg.value;
        pendingProposals.push(_proposalID);
        proposals[_proposalID] = newProposal;
        emit ProposalCreated(_proposalID);
    }

    function createSetNewAddressProposal(
        //3 set ENS new owner ,4 set new resolve address ,5 renew ENS Name
        uint256 _proposalID,
        address _newAddress
    ) external payable {
        _isValid(_proposalID);
        _isValidBalance();
        Proposal memory newProposal;
        newProposal.proposer = msg.sender;
        newProposal.releaseBlock = block.number.add(20); //block.number.add(100);
        newProposal.status = 1;
        newProposal._address = _newAddress;
        newProposal._type = 4; //new ENS Resolve Address
        newProposal.pendingIndex = pendingProposals.length.add(1);
        newProposal.tokenProposalPaidFees = msg.value;
        pendingProposals.push(_proposalID);
        proposals[_proposalID] = newProposal;
        emit ProposalCreated(_proposalID);
    }

    function createRenewENSNameProposal(
        //3 set ENS new owner ,4 set new resolve address ,5 renew ENS Name
        uint256 _proposalID,
        uint256 _duration
    ) external payable {
        _isValid(_proposalID);
        _isValidBalance();
        Proposal memory newProposal;
        newProposal.proposer = msg.sender;
        newProposal.releaseBlock = block.number.add(20); //block.number.add(100);
        newProposal.status = 1;
        newProposal.value = _duration;
        newProposal._type = 5; //renew ENS Name
        newProposal.pendingIndex = pendingProposals.length.add(1);
        newProposal.tokenProposalPaidFees = msg.value;
        pendingProposals.push(_proposalID);
        proposals[_proposalID] = newProposal;
        emit ProposalCreated(_proposalID);
    }

    function voteAgainstProposal(uint256 _proposalID, bytes32 _version)
        external
    {
        isPending(_proposalID);

        require(
            block.number < proposals[_proposalID].releaseBlock &&
                (_voterRate(msg.sender, zefi_eth_uni_lp) >= 1 ||
                    _voterRate(msg.sender, zefi) >= 1) &&
                !proposals[_proposalID].votedAgainst[msg.sender],
            "ended" //short message due to byte size constraint concerns
        );
        proposals[_proposalID].zefiAgainstVotes = proposals[_proposalID]
            .zefiAgainstVotes
            .add(_voteBalances[msg.sender][zefi]);
        proposals[_proposalID]
            .zefi_eth_uni_lpAgainstVotes = proposals[_proposalID]
            .zefi_eth_uni_lpAgainstVotes
            .add(_voteBalances[msg.sender][zefi_eth_uni_lp]);
        proposalVoters[_proposalID].push(msg.sender);
        proposals[_proposalID].votedAgainst[msg.sender] = true;
        version[msg.sender] = _version;
    }

    function _removeFromPending(uint256 _proposalID) internal {
        uint256 _index;
        uint256 _lastindex;
        uint256 _lastProposalID;

        _index = proposals[_proposalID].pendingIndex.sub(1);
        _lastindex = pendingProposals.length.sub(1);
        _lastProposalID = pendingProposals[_lastindex];
        pendingProposals[_index] = pendingProposals[_lastindex];
        pendingProposals.pop();
        proposals[_lastProposalID].pendingIndex = _index.add(1);
        proposals[_proposalID].pendingIndex = 0;
    }

    function finalizeProposal(uint256 _proposalID) external {
        isPending(_proposalID);
        require(
            block.number >= proposals[_proposalID].releaseBlock,
            "still open"
        );

        if (proposals[_proposalID]._type == 1) {
            //transaction proposal
            address _token = proposals[_proposalID].token;

            IERC20 _erc20Token = IERC20(_token);
            require(
                proposals[_proposalID].value >= supportedTokens[_token].fees &&
                    _erc20Token.balanceOf(address(this)) >=
                    proposals[_proposalID].value,
                "inssuficient AMN1"
            );
        } else if (proposals[_proposalID]._type > 1) {
            // tokenNewFees proposal
            require(
                address(this).balance >=
                    proposals[_proposalID].tokenProposalPaidFees, // fees paid from proposer
                "AMN not enough"
            );
        }
        _finalizeProposal(_proposalID);
    }

    function againstRate(uint256 _proposalID) internal view returns (uint256) {
        uint256 _zefiVotes = proposals[_proposalID].zefiAgainstVotes;
        uint256 _zefi_eth_uni_lpVotes = proposals[_proposalID]
            .zefi_eth_uni_lpAgainstVotes;
        uint256 _againstRate;
        uint256 _zefiRate;
        uint256 _zefi_eth_uni_lpRate;
        if (_voteTotalSupply[zefi] > 0) {
            _zefiRate = _zefiVotes.mul(100).div(_voteTotalSupply[zefi]);
        }
        if (_voteTotalSupply[zefi_eth_uni_lp] > 0) {
            _zefi_eth_uni_lpRate = _zefi_eth_uni_lpVotes.mul(100).div(
                _voteTotalSupply[zefi_eth_uni_lp]
            );
        }
        _againstRate = _zefiRate.add(_zefi_eth_uni_lpRate);
        _againstRate = _againstRate.mul(50).div(100);
        return _againstRate;
    }

    function _finalizeProposal(uint256 _proposalID) internal {
        uint256 _againstRate = againstRate(_proposalID);
        uint256 _type = proposals[_proposalID]._type;
        uint256 _value = proposals[_proposalID].value;
        address _token = proposals[_proposalID].token;
        address _address = proposals[_proposalID]._address;
        address _proposer = proposals[_proposalID].proposer;
        if (_againstRate < 20) {
            proposals[_proposalID].status = 2;
            _removeFromPending(_proposalID);
            IERC20 _erc20Token = IERC20(_token);
            if (_type == 1) {
                _distributeFees(
                    _token,
                    _proposer,
                    msg.sender,
                    supportedTokens[_token].fees
                );
                _erc20Token.safeTransfer(
                    _address,
                    _value.sub(supportedTokens[_token].fees)
                );
            } else {
                if (_type == 2) {
                    uint256 _tokenIndex = supportedTokens[_token].index;

                    if (_value == 0) {
                        // remove it from supported;

                            address _lastToken
                         = supportedTokensList[supportedTokensList.length.sub(
                            1
                        )];
                        supportedTokensList[_tokenIndex.sub(1)] = _lastToken;
                        supportedTokensList.pop();
                        supportedTokens[_lastToken].index = _tokenIndex.add(1);
                        supportedTokens[_token].index = 0;
                    } else {
                        if (supportedTokens[_token].index == 0) {
                            supportedTokens[_token].index = supportedTokensList
                                .length
                                .add(1);
                            supportedTokensList.push(_token);
                        }
                        supportedTokens[_token].fees = _value;
                    }
                } else if (_type == 3) {
                    iEns.setOwner(nodeHashedName, _address);
                } else if (_type == 4) {
                    iResolver.setAddr(nodeHashedName, _address);
                } else if (_type == 5) {
                    uint256 _amount = iETHRegitrar.rentPrice(_NAME, _value);
                    require(address(this).balance >= _amount, "AMN not enough");
                    iETHRegitrar.renew{value: _amount}(_NAME, _value);
                }

                _distributeFees(
                    0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,
                    _proposer,
                    msg.sender,
                    proposals[_proposalID].tokenProposalPaidFees
                );
            }
        } else {
            proposals[_proposalID].status = 3;

            if (_againstRate >= 80) {
                _resetVoteBalancesList(_proposalID);
            }
            _removeFromPending(_proposalID);
            _resetHonestyCredit(_proposalID);

            if (_againstRate >= 50) {
                bondingBalance[_proposer] = 0;
                _generateRewardAddresses(_proposalID);
            }
        }
    }

    function _distributeFees(
        address _token,
        address _proposer,
        address _finalizer,
        uint256 _fees
    ) internal {
        collectedFees[_proposer][_token] = collectedFees[_proposer][_token].add(
            _fees.mul(5).div(100)
        );

        collectedFees[_finalizer][_token] = collectedFees[_finalizer][_token]
            .add(_fees.mul(5).div(100));
        uint256 _fees80 = _fees.mul(80).div(100);
        for (uint256 i = 0; i < rewardAddresses.length; i++) {
            address _voter = rewardAddresses[i];
            uint256 _reward = _honestyCredit[_voter].mul(_fees80);
            _reward = _reward.div(_honestyCreditTotal);

            uint256 _collectedFees = collectedFees[_voter][_token];

            _collectedFees = _collectedFees.add(_reward);
            collectedFees[_voter][_token] = _collectedFees;
        }
    }

    function _resetVoteBalancesList(uint256 _proposalID) internal {
        for (uint256 i = 0; i < voteBalancesList.length; i++) {
            address _voter = voteBalancesList[i];

            if (!proposals[_proposalID].votedAgainst[_voter]) {
                _voteTotalSupply[zefi] = _voteTotalSupply[zefi].sub(
                    _voteBalances[_voter][zefi]
                );
                _voteBalances[_voter][zefi] = 0;
                _voteTotalSupply[zefi_eth_uni_lp] = _voteTotalSupply[zefi_eth_uni_lp]
                    .sub(_voteBalances[_voter][zefi_eth_uni_lp]);

                _voteBalances[_voter][zefi_eth_uni_lp] = 0;
            }
        }
        delete voteBalancesList;
        voteBalancesList = proposalVoters[_proposalID];
        emit VoteBalancChanged();
    }

    function _resetHonestyCredit(uint256 _proposalID) internal {
        for (uint256 i = 0; i < rewardAddresses.length; i++) {
            address _voter = rewardAddresses[i];
            if (!proposals[_proposalID].votedAgainst[_voter]) {
                _honestyCredit[_voter] = 0;
            }
        }
    }

    function _generateRewardAddresses(uint256 _proposalID) internal {
        delete rewardAddresses;

        _honestyCreditTotal = 0;
        for (uint256 i = 0; i < proposalVoters[_proposalID].length; i++) {
            address _voter = proposalVoters[_proposalID][i];
            uint256 _rate = _voterRate(_voter, zefi);
            _rate = _rate.add(_voterRate(_voter, zefi_eth_uni_lp));
            _rate = _rate.div(2);
            rewardAddresses.push(_voter);
            _honestyCredit[_voter] = _honestyCredit[_voter].add(
                _rate.mul(1000)
            );
            if (_honestyCredit[_voter] > 100000) {
                _honestyCredit[_voter] = 100000;
            }
            _honestyCreditTotal = _honestyCreditTotal.add(
                _honestyCredit[_voter]
            );
        }
    }

    function _voterRate(address _account, address _token)
        internal
        view
        returns (uint256)
    {
        uint256 _rate;
        if (_voteTotalSupply[_token] == 0) {
            _rate = 0;
        } else {
            _rate = _voteBalances[_account][_token].mul(100).div(
                _voteTotalSupply[_token]
            );
        }
        return _rate;
    }

    function getVoteBalancesList() external view returns (address[] memory) {
        return voteBalancesList;
    }

    function getRewardAddresses() external view returns (address[] memory) {
        return rewardAddresses;
    }

    function getPendingProposals() external view returns (uint256[] memory) {
        return pendingProposals;
    }

    function getSupportedTokensList() external view returns (address[] memory) {
        return supportedTokensList;
    }

    function getVersion(address _account) external view returns (bytes32) {
        return version[_account];
    }

    function tokenFees(address _token) external view returns (uint256 fees) {
        return supportedTokens[_token].fees;
    }

    function collectRewards(address _token) external {
        uint256 _amount = collectedFees[msg.sender][_token];
        noZeroAmount(_amount);
        if (_token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            collectedFees[msg.sender][_token] = 0;
            msg.sender.transfer(_amount);
        } else {
            IERC20 _erc20Token = IERC20(_token);
            collectedFees[msg.sender][_token] = 0;
            _erc20Token.safeTransfer(msg.sender, _amount);
        }
    }
}