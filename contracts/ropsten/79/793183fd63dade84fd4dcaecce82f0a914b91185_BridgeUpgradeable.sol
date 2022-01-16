// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./VoterUpgradeable.sol";

import "./interfaces/IDepositExecute.sol";
import "./interfaces/ILiquidityPool.sol";
import "./interfaces/IERCHandler.sol";
import "./interfaces/IGenericHandler.sol";
import "./interfaces/IWETH.sol";

/**
    @title Facilitates deposits, creation and voting of deposit proposals, and deposit executions.
    @author Router Protocol
 */
contract BridgeUpgradeable is
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    // View Functions
    function fetchMAX_RELAYERS() public view virtual returns (uint256) {
        return MAX_RELAYERS;
    }

    function fetchMAX_FEE_SETTERS() public view virtual returns (uint256) {
        return MAX_FEE_SETTERS;
    }

    function fetch_chainID() public view virtual returns (uint8) {
        return _chainID;
    }

    function fetch_expiry() public view virtual returns (uint256) {
        return _expiry;
    }

    function fetch_whitelistEnabled() public view virtual returns (bool) {
        return _whitelistEnabled;
    }

    function fetch_depositCounts(uint8 _id) public view virtual returns (uint64) {
        return _depositCounts[_id];
    }

    function fetch_resourceIDToHandlerAddress(bytes32 _id) public view virtual returns (address) {
        return _resourceIDToHandlerAddress[_id];
    }

    function fetch_proposals(bytes32 _id) public view virtual returns (uint256) {
        return _proposals[_id];
    }

    function fetch_whitelist(address _beneficiary) public view virtual returns (bool) {
        return _whitelist[_beneficiary];
    }

    function fetch_quorum() public view virtual returns (uint64) {
        return _quorum;
    }

    function fetchTotalRelayers() public view virtual returns (uint256 count) {
        return totalRelayers;
    }

    function GetProposalHash(
        uint8 chainID,
        uint64 depositNonce,
        bytes32 dataHash
    ) public pure virtual returns (bytes32) {
        bytes32 proposalHash = keccak256(abi.encodePacked(chainID, depositNonce, dataHash));
        return proposalHash;
    }

    function HasVotedOnProposal(
        uint8 chainID,
        uint64 depositNonce,
        bytes32 dataHash
    ) public view virtual returns (bool) {
        bytes32 proposalHash = keccak256(abi.encodePacked(chainID, depositNonce, dataHash));
        uint256 id = _proposals[proposalHash];
        return _voter.Voted(id, msg.sender);
    }

    // View Functions

    // Data Structure Starts

    uint256 private constant MAX_RELAYERS = 200;
    uint256 private constant MAX_FEE_SETTERS = 3;
    uint8 private _chainID;
    uint256 private _expiry;
    bool private _whitelistEnabled;
    bytes32 public constant FEE_SETTER_ROLE = keccak256("FEE_SETTER_ROLE");
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant RESOURCE_SETTER = keccak256("RESOURCE_SETTER");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    uint256 private totalRelayers;

    uint64 private _quorum;

    VoterUpgradeable public _voter;

    // enum ProposalStatus { Inactive, Active, Passed, Executed, Cancelled }

    mapping(uint8 => uint64) private _depositCounts;

    mapping(bytes32 => address) private _resourceIDToHandlerAddress;

    mapping(bytes32 => uint256) private _proposals;

    mapping(address => bool) private _whitelist;

    mapping(uint256 => proposalStruct) private _proposalDetails;

    struct proposalStruct {
        uint8 chainID;
        uint64 depositNonce;
        bytes32 dataHash;
        bytes32 resourceID;
    }

    // Data Structure Ends

    event quorumChanged(uint64 quorum);
    event expiryChanged(uint256 expiry);
    event ProposalEvent(
        uint8 originChainID,
        uint64 depositNonce,
        VoterUpgradeable.ProposalStatus status,
        bytes32 dataHash
    );
    event ProposalVote(
        uint8 originChainID,
        uint64 depositNonce,
        VoterUpgradeable.ProposalStatus status,
        bytes32 dataHash
    );
    event Deposit(uint8 indexed destinationChainID, bytes32 indexed resourceID, uint64 indexed depositNonce);
    event Stake(address indexed staker, uint256 amount, address pool);
    event Unstake(address indexed unstaker, uint256 amount, address pool);
    event FeeSetterAdded(address feeSetter);
    event FeeSetterRemoved(address feeSetter);
    event AddedWhitelist(address whitelistAddress);
    event RemovedWhitelist(address whitelistAddress);
    event WhitelistingSetting(bool status);
    event AdminWithdraw(address handler, address tokenAddress, address recipient, uint256 amountOrTokenID);
    event Settlement(
        uint8 indexed destinationChainID,
        uint64 depositNonce,
        address settlementToken,
        uint256 settlementAmount
    );
    /**
        @notice RelayerAdded Event
        @notice Creates a event when Relayer Role is granted.
        @param relayer Address of relayer.
    */
    event RelayerAdded(address relayer);

    /**
        @notice RelayerRemoved Event
        @notice Creates a event when Relayer Role is revoked.
        @param relayer Address of relayer.
    */
    event RelayerRemoved(address relayer);

    // Modifier Section Starts

    modifier onlyAdminOrRelayer() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(RELAYER_ROLE, msg.sender),
            "sender is not relayer or admin"
        );
        _;
    }

    modifier isWhitelisted() {
        if (_whitelistEnabled) {
            require(_whitelist[msg.sender], "address is not whitelisted");
        }
        _;
    }

    modifier isWhitelistEnabled() {
        require(_whitelistEnabled, "BridgeUpgradeable: White listing is not enabled");
        _;
    }

    modifier isResourceID(bytes32 _id) {
        require(_resourceIDToHandlerAddress[_id] != address(0), "BridgeUpgradeable: No handler for resourceID");
        _;
    }

    modifier isProposalExists(
        uint8 chainID,
        uint64 depositNonce,
        bytes32 dataHash
    ) {
        bytes32 proposalHash = keccak256(abi.encodePacked(chainID, depositNonce, dataHash));
        require(_proposals[proposalHash] != 0, "BridgeUpgradeable: Proposal Already Exists");
        _;
    }

    // Modifier Section ends

    receive() external payable {}

    // Upgrade Section Starts
    /**
        @notice Initializes Bridge, creates and grants {msg.sender} the admin role,
        creates and grants {initialRelayers} the relayer role.
        @param chainID ID of chain the Bridge contract exists on.
        @param quorum Number of votes needed for a deposit proposal to be considered passed.
     */
    function initialize(
        uint8 chainID,
        uint256 quorum,
        uint256 expiry,
        address voter
    ) external initializer {
        __AccessControl_init();
        __Pausable_init();

        // Constructor Fx
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setRoleAdmin(FEE_SETTER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(RELAYER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(PAUSER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(RESOURCE_SETTER, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(EMERGENCY_ROLE, DEFAULT_ADMIN_ROLE);

        _voter = VoterUpgradeable(voter);

        _chainID = chainID;
        _quorum = uint64(quorum);
        _expiry = expiry;

        // Constructor Fx
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // Upgrade Section Ends

    // Access Control Section Starts

    /**
        @notice grantRole function
        @dev Overrides the grant role in accessControl contract.
        @dev If RELAYER_ROLE is granted then it would mint 1 voting token as voting weights.
        @dev The Token minted would be notional and non transferable type.
        @param role Hash of the role being granted
        @param account address to which role is being granted
    */
    function grantRole(bytes32 role, address account)
        public
        virtual
        override
        nonReentrant
        onlyRole(getRoleAdmin(role))
    {
        super.grantRole(role, account);
        if (role == RELAYER_ROLE && _voter.balanceOf(account) == 0 ether) {
            _voter.mint(account);
            totalRelayers = totalRelayers + 1;
            emit RelayerAdded(account);
        }
    }

    /**
        @notice revokeRole function
        @dev Overrides the grant role in accessControl contract.
        @dev If RELAYER_ROLE is revoked then it would burn 1 voting token as voting weights.
        @dev The Token burned would be notional and non transferable type.
        @param role Hash of the role being revoked
        @param account address to which role is being revoked
    */
    function revokeRole(bytes32 role, address account)
        public
        virtual
        override
        nonReentrant
        onlyRole(getRoleAdmin(role))
    {
        super.revokeRole(role, account);
        if (role == RELAYER_ROLE && _voter.balanceOf(account) == 1 ether) {
            _voter.burn(account);
            totalRelayers = totalRelayers - 1;
            emit RelayerRemoved(account);
        }
    }

    // Access Control Section Ends

    // Whitelist Section Starts
    /**
        @dev Adds single address to _whitelist.
        @param _beneficiary Address to be added to the _whitelist
    */
    function addToWhitelist(address _beneficiary) public virtual onlyRole(DEFAULT_ADMIN_ROLE) isWhitelistEnabled {
        _whitelist[_beneficiary] = true;
        emit AddedWhitelist(_beneficiary);
    }

    /**
        @dev Removes single address from _whitelist.
        @param _beneficiary Address to be removed to the _whitelist
    */
    function removeFromWhitelist(address _beneficiary) public virtual onlyRole(DEFAULT_ADMIN_ROLE) isWhitelistEnabled {
        _whitelist[_beneficiary] = false;
        emit RemovedWhitelist(_beneficiary);
    }

    /**
        @dev setWhitelisting whitelisting process.
    */
    function setWhitelisting(bool value) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _whitelistEnabled = value;
        emit WhitelistingSetting(value);
    }

    // Whitelist Section Ends

    // Pause Section Starts

    /**
        @notice Pauses deposits, proposal creation and voting, and deposit executions.
        @notice Only callable by an address that currently has the admin role.
    */
    function pause() public virtual onlyRole(PAUSER_ROLE) whenNotPaused {
        _pause();
    }

    /**
        @notice Unpauses deposits, proposal creation and voting, and deposit executions.
        @notice Only callable by an address that currently has the admin role.
     */
    function unpause() public virtual onlyRole(PAUSER_ROLE) whenPaused {
        _unpause();
    }

    // Pause Section Ends

    // Ancilary Admin Functions Starts

    /**
        @notice Modifies the number of votes required for a proposal to be considered passed.
        @notice Only callable by an address that currently has the admin role.
        @param newQuorum Value {newQuorum} will be changed to.
        @notice Emits {quorumChanged} event.
     */
    function adminChangeQuorum(uint256 newQuorum) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _quorum = uint64(newQuorum);
        emit quorumChanged(_quorum);
    }

    /**
        @notice Modifies the block expiry for a proposal.
        @notice Only callable by an address that currently has the admin role.
        @param newExpiry will be new value of _expiry.
        @notice Emits {expiryChanged} event.
     */
    function adminChangeExpiry(uint256 newExpiry) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _expiry = newExpiry;
        emit expiryChanged(_quorum);
    }

    /**
        @notice Sets a new resource for handler contracts that use the IERCHandler interface,
        and maps the {handlerAddress} to {resourceID} in {_resourceIDToHandlerAddress}.
        @notice Only callable by an address that currently has the admin role.
        @param handlerAddress Address of handler resource will be set for.
        @param resourceID ResourceID to be used when making deposits.
        @param tokenAddress Address of contract to be called when a deposit is made and a deposited is executed.
     */
    function adminSetResource(
        address handlerAddress,
        bytes32 resourceID,
        address tokenAddress
    ) public virtual onlyRole(RESOURCE_SETTER) {
        _resourceIDToHandlerAddress[resourceID] = handlerAddress;
        IERCHandler handler = IERCHandler(handlerAddress);
        handler.setResource(resourceID, tokenAddress);
    }

    function adminSetOneSplitAddress(address handlerAddress, address contractAddress)
        public
        virtual
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
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
    ) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        IERCHandler handler = IERCHandler(handlerAddress);
        handler.setLiquidityPool(name, symbol, decimals, tokenAddress, lpAddress);
    }

    function adminSetLiquidityPoolOwner(
        address handlerAddress,
        address newOwner,
        address tokenAddress,
        address lpAddress
    ) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
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
    ) public virtual onlyRole(RESOURCE_SETTER) {
        _resourceIDToHandlerAddress[resourceID] = handlerAddress;
        IGenericHandler handler = IGenericHandler(handlerAddress);
        handler.setResource(
            resourceID,
            contractAddress,
            depositFunctionSig,
            depositFunctionDepositerOffset,
            executeFunctionSig
        );
    }

    /**
        @notice Sets a resource as burnable for handler contracts that use the IERCHandler interface.
        @notice Only callable by an address that currently has the admin role.
        @param handlerAddress Address of handler resource will be set for.
        @param tokenAddress Address of contract to be called when a deposit is made and a deposited is executed.
     */
    function adminSetBurnable(address handlerAddress, address tokenAddress)
        public
        virtual
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        IERCHandler handler = IERCHandler(handlerAddress);
        handler.setBurnable(tokenAddress);
    }

    /**
        @notice Used to manually withdraw funds from ERC safes.
        @param handlerAddress Address of handler to withdraw from.
        @param tokenAddress Address of token to withdraw.
        @param recipient Address to withdraw tokens to.
        @param amount the amount of ERC20 tokens to withdraw.
     */
    function adminWithdraw(
        address handlerAddress,
        address tokenAddress,
        address recipient,
        uint256 amount
    ) public virtual nonReentrant onlyRole(EMERGENCY_ROLE) {
        IERCHandler handler = IERCHandler(handlerAddress);
        handler.withdraw(tokenAddress, recipient, amount);
        emit AdminWithdraw(handlerAddress, tokenAddress, recipient, amount);
    }

    /**
        @notice Used to manually withdraw funds from ERC safes.
        @param handlerAddress Address of handler to withdraw from.
        @param tokenAddress Address of token to withdraw.
        @param recipient Address to withdraw tokens to.
        @param amount the amount of ERC20 tokens to withdraw.
     */
    function adminWithdrawFees(
        address handlerAddress,
        address tokenAddress,
        address recipient,
        uint256 amount
    ) public virtual nonReentrant onlyRole(EMERGENCY_ROLE) {
        IERCHandler handler = IERCHandler(handlerAddress);
        handler.withdrawFees(tokenAddress, recipient, amount);
        emit AdminWithdraw(handlerAddress, tokenAddress, recipient, amount);
    }

    /**
        @notice Transfers eth in the contract to the specified addresses.
        The parameters addrs and amounts are mapped 1-1.
        This means that the address at index 0 for addrs will receive the amount (in WEI) from amounts at index 0.
        @param addrs Array of addresses to transfer {amounts} to.
        @param amounts Array of amonuts to transfer to {addrs}.
     */
    function transferFunds(address payable[] calldata addrs, uint256[] calldata amounts)
        public
        virtual
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(addrs.length == amounts.length, "addrs and amounts len mismatch");
        uint256 addrCount = addrs.length;
        for (uint256 i = 0; i < addrCount; i++) {
            addrs[i].transfer(amounts[i]);
        }
    }

    /**
       @notice Transfers ERC20 in the contract to the specified addresses. The parameters addrs
       and amounts are mapped 1-1.
       This means that the address at index 0 for addrs will receive the amount
       from amounts at index 0.
       @param addrs Array of addresses to transfer {amounts} to.
       @param tokens Array of addresses of {tokens} to transfer.
       @param amounts Array of amounts to transfer to {addrs}.
    */
    function transferFundsERC20(
        address[] calldata addrs,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) public virtual nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        require(addrs.length == amounts.length, "addrs and amounts len mismatch");
        require(addrs.length == tokens.length, "addrs and amounts len mismatch");
        uint256 addrCount = addrs.length;
        for (uint256 i = 0; i < addrCount; i++) {
            IERC20Upgradeable(tokens[i]).transfer(addrs[i], amounts[i]);
        }
    }

    /**
       @notice Used to set feeStatus
       @notice Only callable by admin.
    */
    function adminSetFeeStatus(bytes32 resourceID, bool status) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        address handlerAddress = _resourceIDToHandlerAddress[resourceID];
        IERCHandler handler = IERCHandler(handlerAddress);
        handler.toggleFeeStatus(status);
    }

    // Fee Function Starts

    /**
       @notice Used to set fee
       @notice Only callable by feeSetter.
    */
    function setBridgeFee(
        bytes32 resourceID,
        uint8 destinationChainID,
        address feeTokenAddress,
        uint256 transferFee,
        uint256 exchangeFee,
        bool accepted
    ) public virtual onlyRole(FEE_SETTER_ROLE) {
        address handlerAddress = _resourceIDToHandlerAddress[resourceID];
        IERCHandler handler = IERCHandler(handlerAddress);
        require(handler.getFeeStatus(), "fee is not enabled");
        handler.setBridgeFee(destinationChainID, feeTokenAddress, transferFee, exchangeFee, accepted);
    }

    function getBridgeFee(
        bytes32 resourceID,
        uint8 destChainID,
        address feeTokenAddress
    ) public view returns (uint256, uint256) {
        address handlerAddress = _resourceIDToHandlerAddress[resourceID];
        IERCHandler handler = IERCHandler(handlerAddress);
        return handler.getBridgeFee(destChainID, feeTokenAddress);
    }

    // Fee Function Ends

    // Deposit Function Starts

    function deposit(
        uint8 destinationChainID,
        bytes32 resourceID,
        bytes calldata data,
        uint256[] memory distribution,
        uint256[] memory flags,
        address[] memory path,
        address feeTokenAddress
    ) public virtual nonReentrant whenNotPaused isWhitelisted {
        _deposit(destinationChainID, resourceID, data, distribution, flags, path, feeTokenAddress);
    }

    function depositETH(
        uint8 destinationChainID,
        bytes32 resourceID,
        bytes calldata data,
        uint256[] memory distribution,
        uint256[] memory flags,
        address[] memory path,
        address feeTokenAddress
    ) public payable virtual nonReentrant whenNotPaused isWhitelisted {
        IERCHandler ercHandler = IERCHandler(_resourceIDToHandlerAddress[resourceID]);
        require(address(ercHandler) != address(0), "resourceID not mapped to handler");
        require(msg.value > 0, "depositETH: No native assets transferred");

        address weth = ercHandler._WETH();

        IWETH(weth).deposit{ value: msg.value }();
        IWETH(weth).transfer(msg.sender, msg.value);

        _deposit(destinationChainID, resourceID, data, distribution, flags, path, feeTokenAddress);
    }

    function _deposit(
        uint8 destinationChainID,
        bytes32 resourceID,
        bytes calldata data,
        uint256[] memory distribution,
        uint256[] memory flags,
        address[] memory path,
        address feeTokenAddress
    ) private {
        IDepositExecute.SwapInfo memory swapDetails = unpackDepositData(data);

        swapDetails.depositer = msg.sender;
        swapDetails.distribution = distribution;
        swapDetails.flags = flags;
        swapDetails.path = path;
        swapDetails.feeTokenAddress = feeTokenAddress;

        swapDetails.handler = _resourceIDToHandlerAddress[resourceID];
        require(swapDetails.handler != address(0), "resourceID not mapped to handler");

        swapDetails.depositNonce = ++_depositCounts[destinationChainID];

        IDepositExecute depositHandler = IDepositExecute(swapDetails.handler);
        depositHandler.deposit(resourceID, destinationChainID, swapDetails.depositNonce, swapDetails);

        emit Deposit(destinationChainID, resourceID, swapDetails.depositNonce);
    }

    function unpackDepositData(bytes calldata data)
        internal
        pure
        returns (IDepositExecute.SwapInfo memory depositData)
    {
        IDepositExecute.SwapInfo memory swapDetails;
        uint256 isDestNative;
        (
            swapDetails.srcTokenAmount,
            swapDetails.srcStableTokenAmount,
            swapDetails.destStableTokenAmount,
            swapDetails.destTokenAmount,
            isDestNative,
            swapDetails.lenRecipientAddress,
            swapDetails.lenSrcTokenAddress,
            swapDetails.lenDestTokenAddress
        ) = abi.decode(data, (uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256));
        swapDetails.isDestNative = isDestNative == 0 ? false : true;
        swapDetails.index = 256; // 32 * 6 -> 8
        bytes memory recipient = bytes(data[swapDetails.index:swapDetails.index + swapDetails.lenRecipientAddress]);
        swapDetails.index = swapDetails.index + swapDetails.lenRecipientAddress;
        bytes memory srcToken = bytes(data[swapDetails.index:swapDetails.index + swapDetails.lenSrcTokenAddress]);
        swapDetails.index = swapDetails.index + swapDetails.lenSrcTokenAddress;
        bytes memory destStableToken = bytes(
            data[swapDetails.index:swapDetails.index + swapDetails.lenDestTokenAddress]
        );
        swapDetails.index = swapDetails.index + swapDetails.lenDestTokenAddress;
        bytes memory destToken = bytes(data[swapDetails.index:swapDetails.index + swapDetails.lenDestTokenAddress]);

        bytes20 srcTokenAddress;
        bytes20 destStableTokenAddress;
        bytes20 destTokenAddress;
        bytes20 recipientAddress;
        assembly {
            srcTokenAddress := mload(add(srcToken, 0x20))
            destStableTokenAddress := mload(add(destStableToken, 0x20))
            destTokenAddress := mload(add(destToken, 0x20))
            recipientAddress := mload(add(recipient, 0x20))
        }
        swapDetails.srcTokenAddress = srcTokenAddress;
        swapDetails.destStableTokenAddress = address(destStableTokenAddress);
        swapDetails.destTokenAddress = destTokenAddress;
        swapDetails.recipient = address(recipientAddress);

        return swapDetails;
    }

    // Deposit Function Ends

    /**
       @notice Allows staking into liquidity pools.
       @notice Only callable when Bridge is not paused.
       @param resourceID ResourceID used to find address of handler to be used for stake
       @param tokenAddress Asset which needs to be staked.
       @param amount Amount that needs to be staked.
       @notice Emits {Stake} event.
    */
    function stake(
        bytes32 resourceID,
        address tokenAddress,
        uint256 amount
    ) public virtual nonReentrant whenNotPaused {
        address handler = _resourceIDToHandlerAddress[resourceID];
        ILiquidityPool depositHandler = ILiquidityPool(handler);
        IERCHandler ercHandler = IERCHandler(handler);
        address _tokenAddress = ercHandler.resourceIDToTokenContractAddress(resourceID);
        require(_tokenAddress == tokenAddress, "stakeETH: invalid token address");
        depositHandler.stake(msg.sender, tokenAddress, amount);
        emit Stake(msg.sender, amount, tokenAddress);
    }

    /**
       @notice Allows staking ETH into liquidity pools.
       @notice Only callable when Bridge is not paused.
       @param resourceID ResourceID used to find address of handler to be used for stake
       @param tokenAddress Asset which needs to be staked.
       @param amount Amount that needs to be staked.
       @notice Emits {Stake} event.
    */
    function stakeETH(
        bytes32 resourceID,
        address tokenAddress,
        uint256 amount
    ) public payable virtual nonReentrant whenNotPaused {
        address handler = _resourceIDToHandlerAddress[resourceID];
        ILiquidityPool depositHandler = ILiquidityPool(handler);
        IERCHandler ercHandler = IERCHandler(handler);
        address _tokenAddress = ercHandler.resourceIDToTokenContractAddress(resourceID);
        address WETH = ercHandler._WETH();
        require(_tokenAddress == tokenAddress, "stakeETH: invalid token address");
        require(tokenAddress == WETH, "stakeETH: incorrect weth address");
        require(msg.value == amount, "stakeETH: insufficient eth provided");

        IWETH(WETH).deposit{ value: amount }();
        assert(IWETH(WETH).transfer(handler, amount));
        depositHandler.stakeETH(msg.sender, tokenAddress, amount);
        emit Stake(msg.sender, amount, tokenAddress);
    }

    /**
       @notice Allows unstaking from liquidity pools.
       @notice Only callable when Bridge is not paused.
       @param resourceID ResourceID used to find address of handler to be used for unstake
       @param tokenAddress Asset which needs to be unstaked.
       @param amount Amount that needs to be unstaked.
       @notice Emits {Unstake} event.
    */
    function unstake(
        bytes32 resourceID,
        address tokenAddress,
        uint256 amount
    ) public virtual nonReentrant whenNotPaused {
        address handler = _resourceIDToHandlerAddress[resourceID];
        ILiquidityPool depositHandler = ILiquidityPool(handler);
        IERCHandler ercHandler = IERCHandler(handler);
        address _tokenAddress = ercHandler.resourceIDToTokenContractAddress(resourceID);
        require(_tokenAddress == tokenAddress, "stakeETH: invalid token address");
        depositHandler.unstake(msg.sender, tokenAddress, amount);
        emit Unstake(msg.sender, amount, tokenAddress);
    }

    /**
       @notice Allows unstaking ETH from liquidity pools.
       @notice Only callable when Bridge is not paused.
       @param resourceID ResourceID used to find address of handler to be used for unstake
       @param tokenAddress Asset which needs to be unstaked.
       @param amount Amount that needs to be unstaked.
       @notice Emits {Unstake} event.
    */
    function unstakeETH(
        bytes32 resourceID,
        address tokenAddress,
        uint256 amount
    ) public virtual nonReentrant whenNotPaused {
        address handler = _resourceIDToHandlerAddress[resourceID];
        ILiquidityPool depositHandler = ILiquidityPool(handler);
        IERCHandler ercHandler = IERCHandler(handler);
        address _tokenAddress = ercHandler.resourceIDToTokenContractAddress(resourceID);
        require(_tokenAddress == tokenAddress, "stakeETH: invalid token address");
        address WETH = ercHandler._WETH();
        require(tokenAddress == WETH, "stakeETH: incorrect weth address");
        depositHandler.unstakeETH(msg.sender, tokenAddress, amount);
        emit Unstake(msg.sender, amount, tokenAddress);
    }

    // Stating/UnStaking Function Ends

    // Voting Function starts

    /**
        @notice Returns a proposal.
        @param originChainID Chain ID deposit originated from.
        @param depositNonce ID of proposal generated by proposal's origin Bridge contract.
        @param dataHash Hash of data to be provided when deposit proposal is executed.
     */
    function getProposal(
        uint8 originChainID,
        uint64 depositNonce,
        bytes32 dataHash
    ) public view virtual returns (VoterUpgradeable.issueStruct memory status) {
        bytes32 proposalHash = keccak256(abi.encodePacked(originChainID, depositNonce, dataHash));
        return _voter.fetchIssueMap(_proposals[proposalHash]);
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
    function voteProposal(
        uint8 chainID,
        uint64 depositNonce,
        bytes32 resourceID,
        bytes32 dataHash
    ) public virtual isResourceID(resourceID) onlyRole(RELAYER_ROLE) whenNotPaused {
        bytes32 proposalHash = keccak256(abi.encodePacked(chainID, depositNonce, dataHash));
        if (_proposals[proposalHash] == 0) {
            uint256 id = _voter.createProposal(block.number + _expiry, _quorum);
            _proposals[proposalHash] = id;
            _proposalDetails[id] = proposalStruct(chainID, depositNonce, resourceID, dataHash);
            emit ProposalEvent(chainID, depositNonce, VoterUpgradeable.ProposalStatus.Active, dataHash);
        } else if (_voter.fetchIsExpired(_proposals[proposalHash])) {
            _voter.setStatus(_proposals[proposalHash]);
            emit ProposalEvent(chainID, depositNonce, _voter.getStatus(_proposals[proposalHash]), dataHash);
            return;
        }
        if (_voter.getStatus(_proposals[proposalHash]) != VoterUpgradeable.ProposalStatus.Cancelled) {
            _voter.vote(_proposals[proposalHash], 1, msg.sender);

            emit ProposalVote(chainID, depositNonce, _voter.getStatus(_proposals[proposalHash]), dataHash);
            if (_voter.getStatus(_proposals[proposalHash]) == VoterUpgradeable.ProposalStatus.Passed) {
                emit ProposalEvent(chainID, depositNonce, _voter.getStatus(_proposals[proposalHash]), dataHash);
            }
        }
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
    function cancelProposal(
        uint8 chainID,
        uint64 depositNonce,
        bytes32 dataHash
    ) public onlyAdminOrRelayer {
        bytes32 proposalHash = keccak256(abi.encodePacked(chainID, depositNonce, dataHash));
        VoterUpgradeable.ProposalStatus currentStatus = _voter.getStatus(_proposals[proposalHash]);
        require(
            currentStatus == VoterUpgradeable.ProposalStatus.Active ||
                currentStatus == VoterUpgradeable.ProposalStatus.Passed,
            "Proposal cannot be cancelled"
        );

        _voter.setStatus(_proposals[proposalHash]);

        emit ProposalEvent(chainID, depositNonce, VoterUpgradeable.ProposalStatus.Cancelled, dataHash);
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
    ) public virtual onlyRole(RELAYER_ROLE) whenNotPaused {
        address settlementToken;
        IDepositExecute.SwapInfo memory swapDetails = unpackDepositData(data);
        swapDetails.distribution = distribution;
        swapDetails.flags = flags;
        swapDetails.path = path;

        bytes32 dataHash = keccak256(abi.encodePacked(_resourceIDToHandlerAddress[resourceID], data));
        bytes32 proposalHash = keccak256(abi.encodePacked(chainID, depositNonce, dataHash));
        VoterUpgradeable.ProposalStatus currentStatus = _voter.getStatus(_proposals[proposalHash]);
        require(currentStatus == VoterUpgradeable.ProposalStatus.Passed, "Proposal must have Passed status");

        _voter.executeProposal(_proposals[proposalHash]);

        IDepositExecute depositHandler = IDepositExecute(_resourceIDToHandlerAddress[resourceID]);

        (settlementToken, swapDetails.returnAmount) = depositHandler.executeProposal(swapDetails, resourceID);
        emit Settlement(chainID, depositNonce, settlementToken, swapDetails.returnAmount);

        emit ProposalEvent(chainID, depositNonce, VoterUpgradeable.ProposalStatus.Executed, dataHash);
    }

    // Voting Function ends
}