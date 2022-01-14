// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./party.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * @dev PartyFactory contract for polkaparty.app.
 * ubinatus - 2022/01/08:
 * The purpose of this contract is to allow party creators to
 * deploy a new Party contract and make the initial deposit in
 * a single call. ERC20 approvals are made to the Party Factory,
 * which will serve as in middle man, so that the deployed contract
 * can be initialized with the desired funds.
 *
 * Used the Clones contract, which follows the implementation of the
 * EIP-1167, to save gas fees while creating clones with separate state.
 * The deployed bytecode just delegates all calls to the master contract 
 * address. So Ownability of the Party contract delegated by the Factory is 
 * still referring to the actual sender that invokes the createClone function.
 */

contract PartyFactory is Ownable {
    using SafeERC20 for IERC20;

    // Set Implementation Contract
    address public implementationAddress;

    IERC20 tokenAddress;

    // Store created parties
    address[] public parties;
    mapping(address => bool) public statusParties;

    // Events
    event DepositEvent(address caller, address partyAddress, uint256 amount, uint256 cut);
    event JoinEvent(address caller, address partyAddress, string joinPartyId, string userId, uint256 amount, uint256 cut);
    event CreateEvent(address caller, string partyName, string partyId, address partyAddress, string ownerId);
    event WithdrawEvent(address userAddress, uint256 withdrawPercentage, address partyAddress, uint256 amount);
    event LeavePartyEvent(address userAddress, uint256 weight, address partyAddress);
    event KickPartyEvent(address userAddress, address kickedAddress, uint256 weight, address partyAddress);
    event ClosePartyEvent(address partyAddress, address ownerAddress);
    event Qoute0xSwap(IERC20 sellTokenAddress, IERC20 buyTokenAddress, address spender, address swapTarget, string transactionType, uint256 sellAmount, uint256 buyAmount);

    constructor(address _implementationAddress) {
        setImplementationAddress(_implementationAddress);
    }

    /**
     * @dev Set implementation address
     * Lets the PartyFactory owner to change the Party Implementation address
     */
    function setImplementationAddress(address _implementationAddress)
        public
        onlyOwner
    {
        implementationAddress = _implementationAddress;
    }

    /**
     * @dev Get deterministic Party address
     * Computes the address of a clone deployed using the implementation address
     */
    function getPartyAddress(bytes32 salt) external view returns (address) {
        require(implementationAddress != address(0), "implementationAddress must be set");
        return Clones.predictDeterministicAddress(implementationAddress, salt);
    }

    /**
     * @dev Create Party
     * Deploys a new Party Contract
     */
    function createParty(
        uint256 _minDeposit,
        uint256 _maxDeposit,
        Party.PartyInfo memory _partyInfo,
        string memory _joinPartyId,
        Party.Sig memory _createRSV,
        IERC20 _stableCoin,
        uint256 _initialDeposit,
        bytes32 salt
    ) external payable returns (address) {
        // Clone the Implementation Party
        address partyClone = Clones.cloneDeterministic(implementationAddress, salt);
        uint cut = Party(partyClone).getPlatformFee(_initialDeposit);
        tokenAddress = IERC20(_stableCoin);
        // Initialize the Party
        Party(partyClone).init(
            _minDeposit,
            _maxDeposit,
            _partyInfo,
            _createRSV,
            _stableCoin,
            _initialDeposit
        );  

        // Add created Party to PartyFactory
        parties.push(partyClone);
        statusParties[partyClone] = true;
        // Emit party creation event;
        emit CreateEvent(msg.sender, _partyInfo.partyName, _partyInfo.idParty, partyClone, _partyInfo.ownerId);
        emit JoinEvent(msg.sender, partyClone, _joinPartyId, _partyInfo.ownerId, _initialDeposit, cut);
        // Return new party address
        return partyClone;
    }
    function withdraw(
        address _partyAddress,
        uint256 _withdrawPercentage,
        uint256 _amount,
        uint256 _n,
        uint256 _nonce,
        Party.SwapWithoutRSV[] memory _tokenData,
        Party.Sig memory _platformRSV
    ) external payable partiesFromHere(_partyAddress){
        Party(_partyAddress).withdraw(msg.sender, _partyAddress, _withdrawPercentage, _amount, _n, _nonce, _tokenData, _platformRSV);
        emit WithdrawEvent(msg.sender, _withdrawPercentage, _partyAddress, _amount);

    }
    function fillQuote(
        address _partyAddress,
        IERC20 sellTokenAddress,
        IERC20 buyTokenAddress,
        address spender, 
        address payable swapTarget, 
        bytes memory swapCallData, 
        uint256 sellAmount, 
        uint256 buyAmount, 
        Party.Sig memory approveRSV
    ) external partiesFromHere(_partyAddress) {
        Party(_partyAddress).fillQuote(sellTokenAddress, buyTokenAddress, spender, swapTarget, swapCallData, sellAmount, buyAmount, approveRSV);
        if (sellTokenAddress == tokenAddress) {
            emit Qoute0xSwap(sellTokenAddress, buyTokenAddress, spender, swapTarget, "BUY", sellAmount, buyAmount);
        } else {
            emit Qoute0xSwap(sellTokenAddress, buyTokenAddress, spender, swapTarget, "SELL", sellAmount, buyAmount);
        }
    }
    function deposit(address _partyAddress, uint256 _amount) external partiesFromHere(_partyAddress){
        uint cut = Party(_partyAddress).getPlatformFee(_amount);
        Party(_partyAddress).deposit(_partyAddress, msg.sender, _amount);
        emit DepositEvent(msg.sender, _partyAddress, _amount, cut);
    }
    function joinParty(
        Party.Sig memory _joinRSV,
        address _partyAddress,
        string memory _userId,
        string memory _joinPartyId,
        uint256 _amount
    ) external partiesFromHere(_partyAddress) {
        uint cut = Party(_partyAddress).getPlatformFee(_amount);
        Party(_partyAddress).joinParty(_joinRSV, msg.sender, _partyAddress, _userId, _joinPartyId, _amount);
        emit JoinEvent(msg.sender, _partyAddress, _joinPartyId, _userId, _amount, cut);
    }
    function leaveParty(
        address _partyAddress,
        uint256 _weightUser,
        uint256 _n,
        Party.SwapWithoutRSV[] memory _tokenData,
        Party.Sig memory _leaveRSV
    ) external partiesFromHere(_partyAddress) {
        Party(_partyAddress).leaveParty(_partyAddress, msg.sender, _weightUser, _n, _tokenData, _leaveRSV);
        emit LeavePartyEvent(msg.sender, _weightUser, _partyAddress);
    }
    function kickParty(
        address _partyAddress,
        address _quittingMember,
        uint256 _weightUser,
        uint256 _n,
        Party.SwapWithoutRSV[] memory _tokenData,
        Party.Sig memory _kickRSV
    ) external partiesFromHere(_partyAddress) {
        Party(_partyAddress).kickParty(_partyAddress, msg.sender, _quittingMember, _weightUser, _n, _tokenData, _kickRSV);
        emit KickPartyEvent(msg.sender, _quittingMember, _weightUser, _partyAddress);
    }
    function closeParty(address _partyAddress, Party.Sig memory _closeRSV) external partiesFromHere(_partyAddress) {
        Party(_partyAddress).closeParty(_partyAddress, msg.sender, _closeRSV);
        emit ClosePartyEvent(_partyAddress, Party(_partyAddress).owner());
    }

    /**
     * @dev Get Parties
     * Returns the deployed Party contracts by the Factory
     */
    function getParties() external view returns (address[] memory) {
        return parties;
    }

    modifier partiesFromHere(address _partyAddress){
        require(statusParties[_partyAddress] == true, "Parties is not exist");
        _;
    }
}