pragma solidity 0.6.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./utils/Pausable.sol";
import "./utils/ReducedSafeMath.sol";
import "./interfaces/IDepositExecute.sol";
import "./interfaces/IBridge.sol";
import "./interfaces/IERCHandler.sol";
import "./interfaces/IERC20Handler.sol";
import "./interfaces/IGenericHandler.sol";

/**
    @title Facilitates deposits, creation and votiing of deposit proposals, and deposit executions.
    @author ChainSafe Systems.
 */
contract Bridge is Pausable, AccessControl, ReducedSafeMath {

    uint8   public _chainID;
    uint256 public _relayerThreshold;
    uint256 public _totalRelayers;
    uint256 public _totalProposals;

    enum Vote {No, Yes}

    enum ProposalStatus {Inactive, Active, Executed}

    struct Proposal {
        bytes32 _resourceID;
        bytes32 _dataHash;
        address[] _yesVotes;
        address[] _noVotes;
        ProposalStatus _status;
        uint256 _proposedBlock;
    }

    // destinationChainID => number of deposits
    mapping(uint8 => uint64) public _depositCounts;
    // resourceID => handler address
    mapping(bytes32 => address) public _resourceIDToHandlerAddress;
    // destinationChainID + depositNonce => dataHash => Proposal
    mapping(uint72 => mapping(bytes32 => Proposal)) public _proposals;
    // destinationChainID + depositNonce => dataHash => relayerAddress => bool
    mapping(uint72 => mapping(bytes32 => mapping(address => bool))) public _hasVotedOnProposal;
    // destinationChainID => deposit fee
    mapping(uint8 => uint256) public _fees;

    event RelayerThresholdChanged(uint indexed newThreshold);
    event RelayerAdded(address indexed relayer);
    event RelayerRemoved(address indexed relayer);
    event Deposit(
        uint8   indexed destinationChainID,
        bytes32 indexed resourceID,
        uint64  indexed depositNonce
    );
    event ProposalEvent(
        uint8           indexed originChainID,
        uint64          indexed depositNonce,
        ProposalStatus  indexed status,
        bytes32 resourceID,
        bytes32 dataHash
    );

    event ProposalVote(
        uint8   indexed originChainID,
        uint64  indexed depositNonce,
        ProposalStatus indexed status,
        bytes32 resourceID
    );

    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    bytes32 public constant FEE_SETTER_ROLE = keccak256("FEE_SETTER_ROLE");
    bytes32 public constant RESOURCE_SETTER_ROLE = keccak256("RESOURCE_SETTER_ROLE");

    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }

    modifier onlyAdminOrRelayer() {
        _onlyAdminOrRelayer();
        _;
    }

    modifier onlyRelayers() {
        _onlyRelayers();
        _;
    }

    modifier onlyFeeSetter() {
        require(hasRole(FEE_SETTER_ROLE, msg.sender), "sender is not fee setter");
        _;
    }

    modifier onlyResourceSetter() {
        require(hasRole(RESOURCE_SETTER_ROLE, msg.sender), "sender is not resource setter");
        _;
    }

    function _onlyAdminOrRelayer() private view {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(RELAYER_ROLE, msg.sender),
            "sender is not relayer or admin");
    }

    function _onlyAdmin() private view {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "sender doesn't have admin role");
    }

    function _onlyRelayers() private view {
        require(hasRole(RELAYER_ROLE, msg.sender), "sender doesn't have relayer role");
    }

    /**
        @notice Initializes Bridge, creates and grants {msg.sender} the admin role,
        creates and grants {initialRelayers} the relayer role.
        @param chainID ID of chain the Bridge contract exists on.
        @param initialRelayers Addresses that should be initially granted the relayer role.
        @param initialRelayerThreshold Number of votes needed for a deposit proposal to be considered passed.
     */
    constructor (uint8 chainID, address[] memory initialRelayers, uint initialRelayerThreshold) public {
        _chainID = chainID;
        _relayerThreshold = initialRelayerThreshold;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FEE_SETTER_ROLE, msg.sender);
        _setupRole(RESOURCE_SETTER_ROLE, msg.sender);
        _setRoleAdmin(RELAYER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(FEE_SETTER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(RESOURCE_SETTER_ROLE, DEFAULT_ADMIN_ROLE);

        for (uint i; i < initialRelayers.length; i++) {
            grantRole(RELAYER_ROLE, initialRelayers[i]);
            _totalRelayers++;
        }
    }

    /**
        @notice Returns true if {relayer} has the relayer role.
        @param relayer Address to check.
     */
    function isRelayer(address relayer) external view returns (bool) {
        return hasRole(RELAYER_ROLE, relayer);
    }

    /**
        @notice Removes admin role from {msg.sender} and grants it to {newAdmin}.
        @notice Only callable by an address that currently has the admin role.
        @param newAdmin Address that admin role will be granted to.
     */
    function renounceAdmin(address newAdmin) external onlyAdmin {
        grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        renounceRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
        @notice Pauses deposits, proposal creation and voting, and deposit executions.
        @notice Only callable by an address that currently has the admin role.
     */
    function adminPauseTransfers() external onlyAdmin {
        _pause();
    }

    /**
        @notice Unpauses deposits, proposal creation and voting, and deposit executions.
        @notice Only callable by an address that currently has the admin role.
     */
    function adminUnpauseTransfers() external onlyAdmin {
        _unpause();
    }

    /**
        @notice Modifies the number of votes required for a proposal to be considered passed.
        @notice Only callable by an address that currently has the admin role.
        @param newThreshold Value {_relayerThreshold} will be changed to.
        @notice Emits {RelayerThresholdChanged} event.
     */
    function adminChangeRelayerThreshold(uint newThreshold) external onlyAdmin {
        _relayerThreshold = newThreshold;
        emit RelayerThresholdChanged(newThreshold);
    }

    /**
        @notice Grants {relayerAddress} the relayer role and increases {_totalRelayer} count.
        @notice Only callable by an address that currently has the admin role.
        @param relayerAddress Address of relayer to be added.
        @notice Emits {RelayerAdded} event.
     */
    function adminAddRelayer(address relayerAddress) external onlyAdmin {
        require(!hasRole(RELAYER_ROLE, relayerAddress), "addr already has relayer role!");
        grantRole(RELAYER_ROLE, relayerAddress);
        emit RelayerAdded(relayerAddress);
        _totalRelayers++;
    }

    /**
        @notice Removes relayer role for {relayerAddress} and decreases {_totalRelayer} count.
        @notice Only callable by an address that currently has the admin role.
        @param relayerAddress Address of relayer to be removed.
        @notice Emits {RelayerRemoved} event.
     */
    function adminRemoveRelayer(address relayerAddress) external onlyAdmin {
        require(hasRole(RELAYER_ROLE, relayerAddress), "addr doesn't have relayer role!");
        revokeRole(RELAYER_ROLE, relayerAddress);
        emit RelayerRemoved(relayerAddress);
        _totalRelayers--;
    }

    /**
        @notice Sets a new resource for handler contracts that use the IERCHandler interface,
        and maps the {handlerAddress} to {resourceID} in {_resourceIDToHandlerAddress}.
        @notice Only callable by an address that currently has the admin role.
        @param handlerAddress Address of handler resource will be set for.
        @param resourceID ResourceID to be used when making deposits.
        @param tokenAddress Address of contract to be called when a deposit is made and a deposited is executed.
     */
    function adminSetResource(address handlerAddress, bytes32 resourceID, address tokenAddress) external onlyResourceSetter {
        _resourceIDToHandlerAddress[resourceID] = handlerAddress;
        IERCHandler handler = IERCHandler(handlerAddress);
        handler.setResource(resourceID, tokenAddress);
    }

    /**
        @notice Sets a new resource for handler contracts that use the IGenericHandler interface,
        and maps the {handlerAddress} to {resourceID} in {_resourceIDToHandlerAddress}.
        @notice Only callable by an address that currently has the admin role.
        @param handlerAddress Address of handler resource will be set for.
        @param resourceID ResourceID to be used when making deposits.
        @param contractAddress Address of contract to be called when a deposit is made and a deposited is executed.
     */
    function adminSetGenericResource(
        address handlerAddress,
        bytes32 resourceID,
        address contractAddress,
        bytes4 depositFunctionSig,
        bytes4 executeFunctionSig
    ) external onlyResourceSetter {
        _resourceIDToHandlerAddress[resourceID] = handlerAddress;
        IGenericHandler handler = IGenericHandler(handlerAddress);
        handler.setResource(resourceID, contractAddress, depositFunctionSig, executeFunctionSig);
    }

    /**
        @notice Sets a resource as burnable for handler contracts that use the IERCHandler interface.
        @notice Only callable by an address that currently has the admin role.
        @param handlerAddress Address of handler resource will be set for.
        @param tokenAddress Address of contract to be called when a deposit is made and a deposited is executed.
        @param burnable Does the token need to be burned and minted
     */
    function adminSetBurnable(address handlerAddress, address tokenAddress, bool burnable) external onlyResourceSetter {
        IERCHandler handler = IERCHandler(handlerAddress);
        handler.setBurnable(tokenAddress, burnable);
    }

    /**
        @notice Returns a proposal.
        @param originChainID Chain ID deposit originated from.
        @param depositNonce ID of proposal generated by proposal's origin Bridge contract.
        @param dataHash Hash of data to be provided when deposit proposal is executed.
        @return Proposal which consists of:
        - _dataHash Hash of data to be provided when deposit proposal is executed.
        - _yesVotes Number of votes in favor of proposal.
        - _noVotes Number of votes against proposal.
        - _status Current status of proposal.
     */
    function getProposal(uint8 originChainID, uint64 depositNonce, bytes32 dataHash) external view returns (Proposal memory) {
        uint72 nonceAndID = (uint72(depositNonce) << 8) | uint72(originChainID);
        return _proposals[nonceAndID][dataHash];
    }

    /**
        @notice Changes deposit fee.
        @notice Only callable by fee setter.
        @param newFee Value {_fees[destinationChainID]} will be updated to.
     */
    function changeFee(uint8 destinationChainID, uint newFee) external onlyFeeSetter {
        _fees[destinationChainID] = newFee;
    }

    function setFeePercent(address handlerAddress, uint256 feePercent) external onlyFeeSetter {
        IERC20Handler handler = IERC20Handler(handlerAddress);
        handler.setFeePercent(feePercent);
    }

    function setFeePercentTreasury(address handlerAddress, address treasuryAddress) external onlyAdmin {
        IERC20Handler handler = IERC20Handler(handlerAddress);
        handler.setFeePercentTreasury(treasuryAddress);
    }

    /**
        @notice Used to manually withdraw funds from ERC safes.
        @param handlerAddress Address of handler to withdraw from.
        @param tokenAddress Address of token to withdraw.
        @param recipient Address to withdraw tokens to.
        @param amountOrTokenID Either the amount of ERC20 tokens or the ERC721 token ID to withdraw.
     */
    function adminWithdraw(
        address handlerAddress,
        address tokenAddress,
        address recipient,
        uint256 amountOrTokenID
    ) external onlyAdmin {
        IERCHandler handler = IERCHandler(handlerAddress);
        handler.withdraw(tokenAddress, recipient, amountOrTokenID);
    }

    /**
        @notice Initiates a transfer using a specified handler contract.
        @notice Only callable when Bridge is not paused.
        @param destinationChainID ID of chain deposit will be bridged to.
        @param resourceID ResourceID used to find address of handler to be used for deposit.
        @param data Additional data to be passed to specified handler.
        @param _auxData Unused parameter, can be used for everything, for example, writing IDs of apps from which the deposit was made.
        @notice Emits {Deposit} event.
     */
    function deposit(uint8 destinationChainID, bytes32 resourceID, bytes calldata data, bytes calldata _auxData) external payable whenNotPaused {
        require(msg.value == _fees[destinationChainID], "Incorrect fee supplied");

        address handler = _resourceIDToHandlerAddress[resourceID];
        require(handler != address(0), "resourceID not mapped to handler");

        uint64 depositNonce = ++_depositCounts[destinationChainID];

        IDepositExecute depositHandler = IDepositExecute(handler);
        depositHandler.deposit(resourceID, destinationChainID, depositNonce, msg.sender, data);

        emit Deposit(destinationChainID, resourceID, depositNonce);
    }

    /**
        @notice When called, {msg.sender} will be marked as voting in favor of proposal.
        @notice Only callable by relayers when Bridge is not paused.
        @param chainID ID of chain deposit originated from.
        @param depositNonce ID of deposited generated by origin Bridge contract.
        @param data data provided when deposit was made.
        @notice Proposal must not have already been passed or executed.
        @notice {msg.sender} must not have already voted on proposal.
        @notice Emits {ProposalEvent} event with status indicating the proposal status.
        @notice Emits {ProposalVote} event.
     */
    function voteProposal(uint8 chainID, uint64 depositNonce, bytes32 resourceID, bytes calldata data) external onlyRelayers whenNotPaused {
        address handler = _resourceIDToHandlerAddress[resourceID];
        bytes32 dataHash = keccak256(abi.encodePacked(handler, data));

        uint72 nonceAndID = (uint72(depositNonce) << 8) | uint72(chainID);
        Proposal storage proposal = _proposals[nonceAndID][dataHash];

        require(_resourceIDToHandlerAddress[resourceID] != address(0), "no handler for resourceID");
        require(uint(proposal._status) <= 1, "proposal already executed");
        require(!_hasVotedOnProposal[nonceAndID][dataHash][msg.sender], "relayer already voted");

        if (uint(proposal._status) == 0) {
            ++_totalProposals;
            _proposals[nonceAndID][dataHash] = Proposal({
                _resourceID : resourceID,
                _dataHash : dataHash,
                _yesVotes : new address[](1),
                _noVotes : new address[](0),
                _status : ProposalStatus.Active,
                _proposedBlock : block.number
                });

            proposal._yesVotes[0] = msg.sender;
            emit ProposalEvent(chainID, depositNonce, ProposalStatus.Active, resourceID, dataHash);
        } else {
            require(dataHash == proposal._dataHash, "datahash mismatch");
            proposal._yesVotes.push(msg.sender);
        }
        
        _hasVotedOnProposal[nonceAndID][dataHash][msg.sender] = true;
        emit ProposalVote(chainID, depositNonce, proposal._status, resourceID);

        // if _relayerThreshold has been exceeded
        if (proposal._yesVotes.length >= _relayerThreshold) {
            require(dataHash == proposal._dataHash, "data doesn't match datahash");

            proposal._status = ProposalStatus.Executed;

            IDepositExecute depositHandler = IDepositExecute(_resourceIDToHandlerAddress[proposal._resourceID]);

            depositHandler.executeProposal(proposal._resourceID, data);

            emit ProposalEvent(chainID, depositNonce, proposal._status, proposal._resourceID, proposal._dataHash);
        }
    }

    /**
        @notice Transfers eth in the contract to the specified addresses. The parameters addrs and amounts are mapped 1-1.
        This means that the address at index 0 for addrs will receive the amount (in WEI) from amounts at index 0.
        @param addrs Array of addresses to transfer {amounts} to.
        @param amounts Array of amonuts to transfer to {addrs}.
     */
    function transferFunds(address payable[] calldata addrs, uint[] calldata amounts) external onlyAdmin {
        for (uint i = 0; i < addrs.length; i++) {
            addrs[i].transfer(amounts[i]);
        }
    }

    function transferFundsERC20(address[] calldata addrs, address[] calldata tokenAddrs, uint[] calldata amounts) external onlyAdmin {
        for (uint i = 0; i < addrs.length; i++) {
            IERC20 token = IERC20(tokenAddrs[i]);
            SafeERC20.safeTransfer(token, addrs[i], amounts[i]);
        }
    }
}