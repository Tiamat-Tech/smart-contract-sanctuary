pragma solidity >= 0.6.12;
pragma experimental ABIEncoderV2;

import "./utils/AccessControl.sol";
import "./utils/Pausable.sol";
import "./utils/SafeMath.sol";
import "./utils/SafeCast.sol";
import "./interfaces/IDepositExecute.sol";
import "./interfaces/ILiquidityPool.sol";
import "./interfaces/IERCHandler.sol";
import "./interfaces/IGenericHandler.sol";

/**
    @title Facilitates deposits, creation and voting of deposit proposals, and deposit executions.
    @author ChainSafe Systems.
 */
contract Bridge is Pausable, AccessControl, SafeMath {
    using SafeCast for *;

    // Limit relayers number because proposal can fit only so much votes
    uint256 constant public MAX_RELAYERS = 200;

    uint8   public _chainID;
    uint8   public _relayerThreshold;
    uint128 public _baseFee;
    uint64  public _transferFeeMultiplier;
    uint64  public _exchangeFeeMultiplier;
    uint40  public _expiry;
    bool    public _whitelistEnabled = false;

    enum ProposalStatus {Inactive, Active, Passed, Executed, Cancelled}

    struct Proposal {
        ProposalStatus _status;
        uint200 _yesVotes;      // bitmap, 200 maximum votes
        uint8   _yesVotesTotal;
        uint40  _proposedBlock; // 1099511627775 maximum block
    }

    // destinationChainID => number of deposits
    mapping(uint8 => uint64) public _depositCounts;
    // resourceID => handler address
    mapping(bytes32 => address) public _resourceIDToHandlerAddress;
    // destinationChainID + depositNonce => dataHash => Proposal
    mapping(uint72 => mapping(bytes32 => Proposal)) private _proposals;
    // whitelistedAddress => access status
    mapping(address => bool) public _whitelist;

    event RelayerThresholdChanged(uint256 newThreshold);
    event RelayerAdded(address relayer);
    event RelayerRemoved(address relayer);
    event Deposit(
        uint8   destinationChainID,
        bytes32 resourceID,
        uint64  depositNonce
    );
    event ProposalEvent(
        uint8          originChainID,
        uint64         depositNonce,
        ProposalStatus status,
        bytes32 dataHash
    );
    event ProposalVote(
        uint8   originChainID,
        uint64  depositNonce,
        ProposalStatus status,
        bytes32 dataHash
    );
    event Stake(
        address staker,
        uint256 amount,
        address pool
    );

    event Unstake(
        address unstaker,
        uint256 amount,
        address pool
    );

    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");


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

    modifier isWhitelisted() {
        if(_whitelistEnabled){
            require(_whitelist[msg.sender]);
        }
        _;
    }

    modifier isWhitelistEnabled() {
        require(_whitelistEnabled);
        _;
    }

    receive() external payable {
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

    function _relayerBit(address relayer) private view returns(uint) {
        return uint(1) << sub(AccessControl.getRoleMemberIndex(RELAYER_ROLE, relayer), 1);
    }

    function _hasVoted(Proposal memory proposal, address relayer) private view returns(bool) {
        return (_relayerBit(relayer) & uint(proposal._yesVotes)) > 0;
    }

    /**
        @notice Initializes Bridge, creates and grants {msg.sender} the admin role,
        creates and grants {initialRelayers} the relayer role.
        @param chainID ID of chain the Bridge contract exists on.
        @param initialRelayers Addresses that should be initially granted the relayer role.
        @param initialRelayerThreshold Number of votes needed for a deposit proposal to be considered passed.
     */
    constructor (uint8 chainID, address[] memory initialRelayers, uint256 initialRelayerThreshold, uint256 baseFee, uint256 expiry) public {
        _chainID = chainID;
        _relayerThreshold = initialRelayerThreshold.toUint8();
        _baseFee = baseFee.toUint128();
        _transferFeeMultiplier = 2;
        _exchangeFeeMultiplier = 11;
        _expiry = expiry.toUint40();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        uint256 initialRelayerCount = initialRelayers.length;
        for (uint256 i; i < initialRelayerCount; i++) {
            grantRole(RELAYER_ROLE, initialRelayers[i]);
        }
    }

    // ADDRESS WHITELIST HANDLERS
    /**
    * @dev Adds single address to _whitelist.
    * @param _beneficiary Address to be added to the _whitelist
    */
    function addToWhitelist(address _beneficiary) external onlyAdmin isWhitelistEnabled {
        _whitelist[_beneficiary] = true;
    }

    /**
    * @dev Adds list of addresses to _whitelist. Not overloaded due to limitations with truffle testing.
    * @param _beneficiaries Addresses to be added to the _whitelist
    */
    function addManyToWhitelist(address[] calldata _beneficiaries) external onlyAdmin isWhitelistEnabled {
        uint256 _length = _beneficiaries.length; 
        for (uint256 i = 0; i < _length; i++) {
        _whitelist[_beneficiaries[i]] = true;
        }
    }

    /**
    * @dev Removes single address from _whitelist.
    * @param _beneficiary Address to be removed to the _whitelist
    */
    function removeFromWhitelist(address _beneficiary) external onlyAdmin isWhitelistEnabled {
        _whitelist[_beneficiary] = false;
    }

    /**
    * @dev Disables whitelisting process.
    */
    function disableWhitelisting() external onlyAdmin {
        _whitelistEnabled = false;
    }

    /**
    * @dev Enables whitelisting process.
    */
    function enableWhitelisting() external onlyAdmin {
        _whitelistEnabled = true;
    }

    /**
        @notice Returns true if {relayer} has voted on {destNonce} {dataHash} proposal.
        @notice Naming left unchanged for backward compatibility.
        @param destNonce destinationChainID + depositNonce of the proposal.
        @param dataHash Hash of data to be provided when deposit proposal is executed.
        @param relayer Address to check.
     */
    function _hasVotedOnProposal(uint72 destNonce, bytes32 dataHash, address relayer) public view returns(bool) {
        return _hasVoted(_proposals[destNonce][dataHash], relayer);
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
        require(msg.sender != newAdmin, 'Cannot renounce oneself');
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
    function adminChangeRelayerThreshold(uint256 newThreshold) external onlyAdmin {
        _relayerThreshold = newThreshold.toUint8();
        emit RelayerThresholdChanged(newThreshold);
    }

    /**
        @notice Grants {relayerAddress} the relayer role.
        @notice Only callable by an address that currently has the admin role, which is
                checked in grantRole().
        @param relayerAddress Address of relayer to be added.
        @notice Emits {RelayerAdded} event.
     */
    function adminAddRelayer(address relayerAddress) external {
        require(!hasRole(RELAYER_ROLE, relayerAddress), "addr already has relayer role!");
        require(_totalRelayers() < MAX_RELAYERS, "relayers limit reached");
        grantRole(RELAYER_ROLE, relayerAddress);
        emit RelayerAdded(relayerAddress);
    }

    /**
        @notice Removes relayer role for {relayerAddress}.
        @notice Only callable by an address that currently has the admin role, which is
                checked in revokeRole().
        @param relayerAddress Address of relayer to be removed.
        @notice Emits {RelayerRemoved} event.
     */
    function adminRemoveRelayer(address relayerAddress) external {
        require(hasRole(RELAYER_ROLE, relayerAddress), "addr doesn't have relayer role!");
        revokeRole(RELAYER_ROLE, relayerAddress);
        emit RelayerRemoved(relayerAddress);
    }

    /**
        @notice Sets a new resource for handler contracts that use the IERCHandler interface,
        and maps the {handlerAddress} to {resourceID} in {_resourceIDToHandlerAddress}.
        @notice Only callable by an address that currently has the admin role.
        @param handlerAddress Address of handler resource will be set for.
        @param resourceID ResourceID to be used when making deposits.
        @param tokenAddress Address of contract to be called when a deposit is made and a deposited is executed.
     */
    function adminSetResource(address handlerAddress, bytes32 resourceID, address tokenAddress) external onlyAdmin {
        _resourceIDToHandlerAddress[resourceID] = handlerAddress;
        IERCHandler handler = IERCHandler(handlerAddress);
        handler.setResource(resourceID, tokenAddress);
    }

    function adminSetOneSplitAddress(address handlerAddress, address contractAddress) external onlyAdmin {
        IERCHandler handler = IERCHandler(handlerAddress);
        handler.setOneSplitAddress(contractAddress);
    }

    /**
        @notice Creates new liquidity pool
        @notice Only callable by an address that currently has the admin role.
        @param handlerAddress Address of handler resource will be set for.
        @param tokenAddress Address of token for which pool needs to be created.
     */

    function adminSetLiquidityPool(
        string memory name, 
        string memory symbol,
        uint8 decimals,
        address handlerAddress,
        address tokenAddress,
        address lpAddress
    ) external onlyAdmin {
        IERCHandler handler = IERCHandler(handlerAddress);
        handler.setLiquidityPool(name, symbol, decimals, tokenAddress, lpAddress);
    }

    function adminSetLiquidityPoolOwner(address handlerAddress, address newOwner, address tokenAddress, address lpAddress) external onlyAdmin {
        IERCHandler handler = IERCHandler(handlerAddress);
        handler.setLiquidityPoolOwner(newOwner, tokenAddress, lpAddress);
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
        uint256 depositFunctionDepositerOffset,
        bytes4 executeFunctionSig
    ) external onlyAdmin {
        _resourceIDToHandlerAddress[resourceID] = handlerAddress;
        IGenericHandler handler = IGenericHandler(handlerAddress);
        handler.setResource(resourceID, contractAddress, depositFunctionSig, depositFunctionDepositerOffset, executeFunctionSig);
    }

    /**
        @notice Sets a resource as burnable for handler contracts that use the IERCHandler interface.
        @notice Only callable by an address that currently has the admin role.
        @param handlerAddress Address of handler resource will be set for.
        @param tokenAddress Address of contract to be called when a deposit is made and a deposited is executed.
     */
    function adminSetBurnable(address handlerAddress, address tokenAddress) external onlyAdmin {
        IERCHandler handler = IERCHandler(handlerAddress);
        handler.setBurnable(tokenAddress);
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
        uint72 nonceAndID = (uint72(depositNonce) << 8) | uint8(originChainID);
        return _proposals[nonceAndID][dataHash];
    }

    /**
        @notice Returns total relayers number.
        @notice Added for backwards compatibility.
     */
    function _totalRelayers() public view returns (uint) {
        return AccessControl.getRoleMemberCount(RELAYER_ROLE);
    }



    /**
        @notice Used to set deposit fee.
        @notice Only callable by admin.
        @param  baseFee Value {_baseFee} will be updated to.
        @param  transferFeeMultiplier Value {_transferFeeMultiplier} will be updated to.
        @param  exchangeFeeMultiplier Value {_exchangeFeeMultiplier} will be updated to.
     */
    function adminSetFee(uint256 baseFee, uint64 transferFeeMultiplier, uint64 exchangeFeeMultiplier) external onlyAdmin {
        _baseFee = baseFee.toUint128();
        _transferFeeMultiplier = transferFeeMultiplier;
        _exchangeFeeMultiplier = exchangeFeeMultiplier;
    }

    function getFee() public view returns (uint128, uint64, uint64) {
        return (_baseFee, _transferFeeMultiplier, _exchangeFeeMultiplier);
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
        @notice Emits {Deposit} event.
     */
        
    function deposit(
        uint8 destinationChainID, 
        bytes32 resourceID, 
        bytes calldata data, 
        uint256[] memory distribution, 
        uint256[] memory flags,
        address[] memory path
    ) external payable whenNotPaused isWhitelisted {
        IDepositExecute.SwapInfo memory swapDetails;

        swapDetails.distribution = distribution;
        swapDetails.flags = flags;
        swapDetails.path = path;
        swapDetails.providedFee = msg.value;
        swapDetails.baseFee = _baseFee;
        swapDetails.transferFeeMultiplier = _transferFeeMultiplier;
        swapDetails.exchangeFeeMultiplier = _exchangeFeeMultiplier;

        swapDetails.handler = _resourceIDToHandlerAddress[resourceID];
        require(swapDetails.handler != address(0), "resourceID not mapped to handler");

        swapDetails.depositNonce = ++_depositCounts[destinationChainID];

        IDepositExecute depositHandler = IDepositExecute(swapDetails.handler);
        address(uint160(swapDetails.handler)).transfer(msg.value);
        depositHandler.deposit(
            resourceID,
            destinationChainID,
            swapDetails.depositNonce,
            msg.sender,
            data,
            swapDetails
        );

        emit Deposit(destinationChainID, resourceID, swapDetails.depositNonce);
    }

    /**
        @notice Allows unstaking from liquidity pools.
        @notice Only callable when Bridge is not paused.
        @param handler Address of handler in which pool is deployed.
        @param tokenAddress Asset which needs to be staked.
        @param amount Amount that needs to be staked.
        @notice Emits {Stake} event.
     */
    function stake(address handler, address tokenAddress, uint256 amount) external payable whenNotPaused {
        ILiquidityPool depositHandler = ILiquidityPool(handler);
        IERCHandler ercHandler = IERCHandler(handler);

        if(tokenAddress == ercHandler.getWETHAddress()) {
            address(uint160(handler)).transfer(amount);
        }
        depositHandler.stake(msg.sender, tokenAddress, amount);
        emit Stake(msg.sender, amount, tokenAddress);
    }

    /**
        @notice Allows unstaking from liquidity pools.
        @notice Only callable when Bridge is not paused.
        @param handler Address of handler in which pool is deployed.
        @param tokenAddress Asset which needs to be unstaked.
        @param amount Amount that needs to be unstaked.
        @notice Emits {Unstake} event.
     */
    function unstake(address handler, address tokenAddress, uint256 amount) external whenNotPaused {
        ILiquidityPool depositHandler = ILiquidityPool(handler);
        depositHandler.unstake(msg.sender, tokenAddress, amount);
        emit Unstake(msg.sender, amount, tokenAddress);
    }

    /**
        @notice When called, {msg.sender} will be marked as voting in favor of proposal.
        @notice Only callable by relayers when Bridge is not paused.
        @param chainID ID of chain deposit originated from.
        @param depositNonce ID of deposited generated by origin Bridge contract.
        @param dataHash Hash of data provided when deposit was made.
        @notice Proposal must not have already been passed or executed.
        @notice {msg.sender} must not have already voted on proposal.
        @notice Emits {ProposalEvent} event with status indicating the proposal status.
        @notice Emits {ProposalVote} event.
     */
    function voteProposal(uint8 chainID, uint64 depositNonce, bytes32 resourceID, bytes32 dataHash) external onlyRelayers whenNotPaused {

        uint72 nonceAndID = (uint72(depositNonce) << 8) | uint8(chainID);
        Proposal memory proposal = _proposals[nonceAndID][dataHash];

        require(_resourceIDToHandlerAddress[resourceID] != address(0), "no handler for resourceID");
        require(uint(proposal._status) <= 1, "proposal already passed/executed/cancelled");
        require(!_hasVoted(proposal, msg.sender), "relayer already voted");

        if (proposal._status == ProposalStatus.Inactive) {
            proposal = Proposal({
                _status : ProposalStatus.Active,
                _yesVotes : 0,
                _yesVotesTotal : 0,
                _proposedBlock : uint40(block.number) // Overflow is desired.
            });

            emit ProposalEvent(chainID, depositNonce, ProposalStatus.Active, dataHash);
        } else if (uint40(sub(block.number, proposal._proposedBlock)) > _expiry) {
            // if the number of blocks that has passed since this proposal was
            // submitted exceeds the expiry threshold set, cancel the proposal
            proposal._status = ProposalStatus.Cancelled;

            emit ProposalEvent(chainID, depositNonce, ProposalStatus.Cancelled, dataHash);
        }

        if (proposal._status != ProposalStatus.Cancelled) {
            proposal._yesVotes = (proposal._yesVotes | _relayerBit(msg.sender)).toUint200();
            proposal._yesVotesTotal++; // TODO: check if bit counting is cheaper.

            emit ProposalVote(chainID, depositNonce, proposal._status, dataHash);

            // Finalize if _relayerThreshold has been reached
            if (proposal._yesVotesTotal >= _relayerThreshold) {
                proposal._status = ProposalStatus.Passed;

                emit ProposalEvent(chainID, depositNonce, ProposalStatus.Passed, dataHash);
            }
        }
        _proposals[nonceAndID][dataHash] = proposal;
    }

    /**
        @notice Cancels a deposit proposal that has not been executed yet.
        @notice Only callable by relayers when Bridge is not paused.
        @param chainID ID of chain deposit originated from.
        @param depositNonce ID of deposited generated by origin Bridge contract.
        @param dataHash Hash of data originally provided when deposit was made.
        @notice Proposal must be past expiry threshold.
        @notice Emits {ProposalEvent} event with status {Cancelled}.
     */
    function cancelProposal(uint8 chainID, uint64 depositNonce, bytes32 dataHash) public onlyAdminOrRelayer {
        uint72 nonceAndID = (uint72(depositNonce) << 8) | uint8(chainID);
        Proposal memory proposal = _proposals[nonceAndID][dataHash];
        ProposalStatus currentStatus = proposal._status;

        require(currentStatus == ProposalStatus.Active || currentStatus == ProposalStatus.Passed,
            "Proposal cannot be cancelled");
        require(uint40(sub(block.number, proposal._proposedBlock)) > _expiry, "Proposal not at expiry threshold");

        proposal._status = ProposalStatus.Cancelled;
        _proposals[nonceAndID][dataHash] = proposal;

        emit ProposalEvent(chainID, depositNonce, ProposalStatus.Cancelled, dataHash);
    }

    /**
        @notice Executes a deposit proposal that is considered passed using a specified handler contract.
        @notice Only callable by relayers when Bridge is not paused.
        @param chainID ID of chain deposit originated from.
        @param resourceID ResourceID to be used when making deposits.
        @param depositNonce ID of deposited generated by origin Bridge contract.
        @param data Data originally provided when deposit was made.
        @notice Proposal must have Passed status.
        @notice Hash of {data} must equal proposal's {dataHash}.
        @notice Emits {ProposalEvent} event with status {Executed}.
     */
    function executeProposal(
        uint8 chainID, 
        uint64 depositNonce, 
        bytes calldata data, 
        bytes32 resourceID, 
        uint256[] memory distribution, 
        uint256[] memory flags,
        address[] memory path
    ) external onlyRelayers whenNotPaused {
        IDepositExecute.SwapInfo memory swapDetails;
        swapDetails.distribution = distribution;
        swapDetails.flags = flags;
        swapDetails.path = path;

        address handler = _resourceIDToHandlerAddress[resourceID];
        uint72 nonceAndID = (uint72(depositNonce) << 8) | uint8(chainID);
        bytes32 dataHash = keccak256(abi.encodePacked(handler, data));
        Proposal storage proposal = _proposals[nonceAndID][dataHash];

        require(proposal._status == ProposalStatus.Passed, "Proposal must have Passed status");

        require(uint40(sub(block.number, proposal._proposedBlock)) <= _expiry, "Proposal is not within expiry threshold");
        proposal._status = ProposalStatus.Executed;

        IDepositExecute depositHandler = IDepositExecute(handler);
        depositHandler.executeProposal(resourceID, data, swapDetails);

        emit ProposalEvent(chainID, depositNonce, ProposalStatus.Executed, dataHash);
    }

    /**
        @notice Transfers eth in the contract to the specified addresses. The parameters addrs and amounts are mapped 1-1.
        This means that the address at index 0 for addrs will receive the amount (in WEI) from amounts at index 0.
        @param addrs Array of addresses to transfer {amounts} to.
        @param amounts Array of amonuts to transfer to {addrs}.
     */
    function transferFunds(address payable[] calldata addrs, uint[] calldata amounts) external onlyAdmin {
        require(addrs.length == amounts.length, "addrs and amounts len mismatch");
        uint256 addrCount = addrs.length;
        for (uint256 i = 0; i < addrCount; i++) {
            addrs[i].transfer(amounts[i]);
        }
    }

}