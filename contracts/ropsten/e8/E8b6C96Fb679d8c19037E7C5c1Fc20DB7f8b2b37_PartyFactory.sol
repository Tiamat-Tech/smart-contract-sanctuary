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

    // Store created parties
    address[] public parties;

    // Events
    event PartyCreated(address partyAddress);

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
        bytes32 r,
        bytes32 s,
        uint8 v,
        IERC20 _stableCoin,
        uint256 _initialDeposit,
        bytes32 salt
    ) external payable returns (address) {
        // Clone the Implementation Party
        address partyClone = Clones.cloneDeterministic(implementationAddress, salt);

        // Initialize the Party
        Party(partyClone).init(
            _minDeposit,
            _maxDeposit,
            _partyInfo,
            r,
            s,
            v,
            _stableCoin,
            _initialDeposit
        );

        // Add created Party to PartyFactory
        parties.push(partyClone);

        // Emit party creation event;
        emit PartyCreated(partyClone);

        // Return new party address
        return partyClone;
    }

    /**
     * @dev Get Parties
     * Returns the deployed Party contracts by the Factory
     */
    function getParties() external view returns (address[] memory) {
        return parties;
    }
}