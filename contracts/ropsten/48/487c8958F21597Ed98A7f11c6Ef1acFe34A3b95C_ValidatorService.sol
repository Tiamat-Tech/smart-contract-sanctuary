// SPDX-License-Identifier: AGPL-3.0-only

/*
    ValidatorService.sol - SKALE Manager
    Copyright (C) 2019-Present SKALE Labs
    @author Dmytro Stebaiev
    @author Artem Payvin
    @author Vadim Yavorsky

    SKALE Manager is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    SKALE Manager is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with SKALE Manager.  If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity 0.8.11;

import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

import "@skalenetwork/skale-manager-interfaces/delegation/IValidatorService.sol";
import "@skalenetwork/skale-manager-interfaces/delegation/IDelegationController.sol";

import "../Permissions.sol";

/**
 * @title ValidatorService
 * @dev This contract handles all validator operations including registration,
 * node management, validator-specific delegation parameters, and more.
 * 
 * TIP: For more information see our main instructions
 * https://forum.skale.network/t/skale-mainnet-launch-faq/182[SKALE MainNet Launch FAQ].
 * 
 * Validators register an address, and use this address to accept delegations and
 * register nodes.
 */
contract ValidatorService is Permissions, IValidatorService {

    using ECDSAUpgradeable for bytes32;

    mapping (uint => Validator) public validators;
    mapping (uint => bool) private _trustedValidators;
    uint[] public trustedValidatorsList;
    //       address => validatorId
    mapping (address => uint) private _validatorAddressToId;
    //       address => validatorId
    mapping (address => uint) private _nodeAddressToValidatorId;
    // validatorId => nodeAddress[]
    mapping (uint => address[]) private _nodeAddresses;
    uint public numberOfValidators;
    bool public useWhitelist;

    bytes32 public constant VALIDATOR_MANAGER_ROLE = keccak256("VALIDATOR_MANAGER_ROLE");

    modifier onlyValidatorManager() {
        require(hasRole(VALIDATOR_MANAGER_ROLE, msg.sender), "VALIDATOR_MANAGER_ROLE is required");
        _;
    }

    modifier checkValidatorExists(uint validatorId) {
        require(validatorExists(validatorId), "Validator with such ID does not exist");
        _;
    }

    /**
     * @dev Creates a new validator ID that includes a validator name, description,
     * commission or fee rate, and a minimum delegation amount accepted by the validator.
     * 
     * Emits a {ValidatorRegistered} event.
     * 
     * Requirements:
     * 
     * - Sender must not already have registered a validator ID.
     * - Fee rate must be between 0 - 1000‰. Note: in per mille.
     */
    function registerValidator(
        string calldata name,
        string calldata description,
        uint feeRate,
        uint minimumDelegationAmount
    )
        external
        override
        returns (uint validatorId)
    {
        require(!validatorAddressExists(msg.sender), "Validator with such address already exists");
        require(feeRate <= 1000, "Fee rate of validator should be lower than 100%");
        validatorId = ++numberOfValidators;
        validators[validatorId] = IValidatorService.Validator(
            name,
            msg.sender,
            address(0),
            description,
            feeRate,
            block.timestamp,
            minimumDelegationAmount,
            true
        );
        _setValidatorAddress(validatorId, msg.sender);

        emit ValidatorRegistered(validatorId);
    }

    /**
     * @dev Allows Admin to enable a validator by adding their ID to the
     * trusted list.
     * 
     * Emits a {ValidatorWasEnabled} event.
     * 
     * Requirements:
     * 
     * - Validator must not already be enabled.
     */
    function enableValidator(uint validatorId)
        external
        override
        checkValidatorExists(validatorId)
        onlyValidatorManager
    {
        require(!_trustedValidators[validatorId], "Validator is already enabled");
        _trustedValidators[validatorId] = true;
        trustedValidatorsList.push(validatorId);
        emit ValidatorWasEnabled(validatorId);
    }

    /**
     * @dev Allows Admin to disable a validator by removing their ID from
     * the trusted list.
     * 
     * Emits a {ValidatorWasDisabled} event.
     * 
     * Requirements:
     * 
     * - Validator must not already be disabled.
     */
    function disableValidator(uint validatorId)
        external
        override
        checkValidatorExists(validatorId)
        onlyValidatorManager
    {
        require(_trustedValidators[validatorId], "Validator is already disabled");
        _trustedValidators[validatorId] = false;
        uint position = _find(trustedValidatorsList, validatorId);
        if (position < trustedValidatorsList.length) {
            trustedValidatorsList[position] =
                trustedValidatorsList[trustedValidatorsList.length - 1];
        }
        trustedValidatorsList.pop();
        emit ValidatorWasDisabled(validatorId);
    }

    /**
     * @dev Owner can disable the trusted validator list. Once turned off, the
     * trusted list cannot be re-enabled.
     */
    function disableWhitelist() external override onlyValidatorManager {
        useWhitelist = false;
        emit WhitelistDisabled(false);
    }

    /**
     * @dev Allows `msg.sender` to request a new address.
     * 
     * Requirements:
     *
     * - `msg.sender` must already be a validator.
     * - New address must not be null.
     * - New address must not be already registered as a validator.
     */
    function requestForNewAddress(address newValidatorAddress) external override {
        require(newValidatorAddress != address(0), "New address cannot be null");
        require(_validatorAddressToId[newValidatorAddress] == 0, "Address already registered");
        // check Validator Exist inside getValidatorId
        uint validatorId = getValidatorId(msg.sender);

        validators[validatorId].requestedAddress = newValidatorAddress;
        emit RequestNewAddress(validatorId, msg.sender, newValidatorAddress);
    }

    /**
     * @dev Allows msg.sender to confirm an address change.
     * 
     * Emits a {ValidatorAddressChanged} event.
     * 
     * Requirements:
     * 
     * - Must be owner of new address.
     */
    function confirmNewAddress(uint validatorId)
        external
        override
        checkValidatorExists(validatorId)
    {
        require(
            getValidator(validatorId).requestedAddress == msg.sender,
            "The validator address cannot be changed because it is not the actual owner"
        );
        delete validators[validatorId].requestedAddress;
        _setValidatorAddress(validatorId, msg.sender);

        emit ValidatorAddressChanged(validatorId, validators[validatorId].validatorAddress);
    }

    /**
     * @dev Links a node address to validator ID. Validator must present
     * the node signature of the validator ID.
     * 
     * Requirements:
     * 
     * - Signature must be valid.
     * - Address must not be assigned to a validator.
     */
    function linkNodeAddress(address nodeAddress, bytes calldata sig) external override {
        // check Validator Exist inside getValidatorId
        uint validatorId = getValidatorId(msg.sender);
        require(
            keccak256(abi.encodePacked(validatorId)).toEthSignedMessageHash().recover(sig) == nodeAddress,
            "Signature is not pass"
        );
        require(_validatorAddressToId[nodeAddress] == 0, "Node address is a validator");

        _addNodeAddress(validatorId, nodeAddress);
        emit NodeAddressWasAdded(validatorId, nodeAddress);
    }

    /**
     * @dev Unlinks a node address from a validator.
     * 
     * Emits a {NodeAddressWasRemoved} event.
     */
    function unlinkNodeAddress(address nodeAddress) external override {
        // check Validator Exist inside getValidatorId
        uint validatorId = getValidatorId(msg.sender);

        this.removeNodeAddress(validatorId, nodeAddress);
        emit NodeAddressWasRemoved(validatorId, nodeAddress);
    }

    /**
     * @dev Allows a validator to set a minimum delegation amount.
     */
    function setValidatorMDA(uint minimumDelegationAmount) external override {
        // check Validator Exist inside getValidatorId
        uint validatorId = getValidatorId(msg.sender);
        
        emit SetMinimumDelegationAmount(
            validatorId,
            validators[validatorId].minimumDelegationAmount,
            minimumDelegationAmount
        );
        validators[validatorId].minimumDelegationAmount = minimumDelegationAmount;
    }

    /**
     * @dev Allows a validator to set a new validator name.
     */
    function setValidatorName(string calldata newName) external override {
        // check Validator Exist inside getValidatorId
        uint validatorId = getValidatorId(msg.sender);

        emit SetValidatorName(validatorId, validators[validatorId].name, newName);
        validators[validatorId].name = newName;
    }

    /**
     * @dev Allows a validator to set a new validator description.
     */
    function setValidatorDescription(string calldata newDescription) external override {
        // check Validator Exist inside getValidatorId
        uint validatorId = getValidatorId(msg.sender);

        emit SetValidatorDescription(validatorId, validators[validatorId].description, newDescription);
        validators[validatorId].description = newDescription;
    }

    /**
     * @dev Allows a validator to start accepting new delegation requests.
     * 
     * Requirements:
     * 
     * - Must not have already enabled accepting new requests.
     */
    function startAcceptingNewRequests() external override {
        // check Validator Exist inside getValidatorId
        uint validatorId = getValidatorId(msg.sender);
        require(!isAcceptingNewRequests(validatorId), "Accepting request is already enabled");

        validators[validatorId].acceptNewRequests = true;
        emit AcceptingNewRequests(validatorId, true);
    }

    /**
     * @dev Allows a validator to stop accepting new delegation requests.
     * 
     * Requirements:
     * 
     * - Must not have already stopped accepting new requests.
     */
    function stopAcceptingNewRequests() external override {
        // check Validator Exist inside getValidatorId
        uint validatorId = getValidatorId(msg.sender);
        require(isAcceptingNewRequests(validatorId), "Accepting request is already disabled");

        validators[validatorId].acceptNewRequests = false;
        emit AcceptingNewRequests(validatorId, false);
    }

    function removeNodeAddress(uint validatorId, address nodeAddress)
        external
        override
        allowTwo("ValidatorService", "Nodes")
    {
        require(_nodeAddressToValidatorId[nodeAddress] == validatorId,
            "Validator does not have permissions to unlink node");
        delete _nodeAddressToValidatorId[nodeAddress];
        for (uint i = 0; i < _nodeAddresses[validatorId].length; ++i) {
            if (_nodeAddresses[validatorId][i] == nodeAddress) {
                if (i + 1 < _nodeAddresses[validatorId].length) {
                    _nodeAddresses[validatorId][i] =
                        _nodeAddresses[validatorId][_nodeAddresses[validatorId].length - 1];
                }
                delete _nodeAddresses[validatorId][_nodeAddresses[validatorId].length - 1];
                _nodeAddresses[validatorId].pop();
                break;
            }
        }
    }

    /**
     * @dev Returns the amount of validator bond (self-delegation).
     */
    function getAndUpdateBondAmount(uint validatorId)
        external
        override
        returns (uint)
    {
        IDelegationController delegationController = IDelegationController(
            contractManager.getContract("DelegationController")
        );
        return delegationController.getAndUpdateDelegatedByHolderToValidatorNow(
            getValidator(validatorId).validatorAddress,
            validatorId
        );
    }

    /**
     * @dev Returns node addresses linked to the msg.sender.
     */
    function getMyNodesAddresses() external view override returns (address[] memory) {
        return getNodeAddresses(getValidatorId(msg.sender));
    }

    /**
     * @dev Returns the list of trusted validators.
     */
    function getTrustedValidators() external view override returns (uint[] memory) {
        return trustedValidatorsList;
    }

    /**
     * @dev Checks whether the validator ID is linked to the validator address.
     */
    function checkValidatorAddressToId(address validatorAddress, uint validatorId)
        external
        view
        override
        returns (bool)
    {
        return getValidatorId(validatorAddress) == validatorId ? true : false;
    }

    /**
     * @dev Returns the validator ID linked to a node address.
     * 
     * Requirements:
     * 
     * - Node address must be linked to a validator.
     */
    function getValidatorIdByNodeAddress(address nodeAddress) external view override returns (uint validatorId) {
        validatorId = _nodeAddressToValidatorId[nodeAddress];
        require(validatorId != 0, "Node address is not assigned to a validator");
    }

    function checkValidatorCanReceiveDelegation(uint validatorId, uint amount) external view override {
        require(isAuthorizedValidator(validatorId), "Validator is not authorized to accept delegation request");
        require(isAcceptingNewRequests(validatorId), "The validator is not currently accepting new requests");
        require(
            validators[validatorId].minimumDelegationAmount <= amount,
            "Amount does not meet the validator's minimum delegation amount"
        );
    }

    function initialize(address contractManagerAddress) public override initializer {
        Permissions.initialize(contractManagerAddress);
        useWhitelist = true;
    }

    /**
     * @dev Returns a validator's node addresses.
     */
    function getNodeAddresses(uint validatorId) public view override returns (address[] memory) {
        return _nodeAddresses[validatorId];
    }

    /**
     * @dev Checks whether validator ID exists.
     */
    function validatorExists(uint validatorId) public view override returns (bool) {
        return validatorId <= numberOfValidators && validatorId != 0;
    }

    /**
     * @dev Checks whether validator address exists.
     */
    function validatorAddressExists(address validatorAddress) public view override returns (bool) {
        return _validatorAddressToId[validatorAddress] != 0;
    }

    /**
     * @dev Checks whether validator address exists.
     */
    function checkIfValidatorAddressExists(address validatorAddress) public view override {
        require(validatorAddressExists(validatorAddress), "Validator address does not exist");
    }

    /**
     * @dev Returns the Validator struct.
     */
    function getValidator(uint validatorId)
        public
        view
        override
        checkValidatorExists(validatorId)
        returns (IValidatorService.Validator memory)
    {
        return validators[validatorId];
    }

    /**
     * @dev Returns the validator ID for the given validator address.
     */
    function getValidatorId(address validatorAddress) public view override returns (uint) {
        checkIfValidatorAddressExists(validatorAddress);
        return _validatorAddressToId[validatorAddress];
    }

    /**
     * @dev Checks whether the validator is currently accepting new delegation requests.
     */
    function isAcceptingNewRequests(uint validatorId)
        public
        view
        override
        checkValidatorExists(validatorId)
        returns (bool)
    {
        return validators[validatorId].acceptNewRequests;
    }

    function isAuthorizedValidator(uint validatorId)
        public
        view
        override
        checkValidatorExists(validatorId)
        returns (bool)
    {
        return _trustedValidators[validatorId] || !useWhitelist;
    }

    // private

    /**
     * @dev Links a validator address to a validator ID.
     * 
     * Requirements:
     * 
     * - Address is not already in use by another validator.
     */
    function _setValidatorAddress(uint validatorId, address validatorAddress) private {
        if (_validatorAddressToId[validatorAddress] == validatorId) {
            return;
        }
        require(_validatorAddressToId[validatorAddress] == 0, "Address is in use by another validator");
        address oldAddress = validators[validatorId].validatorAddress;
        delete _validatorAddressToId[oldAddress];
        _nodeAddressToValidatorId[validatorAddress] = validatorId;
        validators[validatorId].validatorAddress = validatorAddress;
        _validatorAddressToId[validatorAddress] = validatorId;
    }

    /**
     * @dev Links a node address to a validator ID.
     * 
     * Requirements:
     * 
     * - Node address must not be already linked to a validator.
     */
    function _addNodeAddress(uint validatorId, address nodeAddress) private {
        if (_nodeAddressToValidatorId[nodeAddress] == validatorId) {
            return;
        }
        require(_nodeAddressToValidatorId[nodeAddress] == 0, "Validator cannot override node address");
        _nodeAddressToValidatorId[nodeAddress] = validatorId;
        _nodeAddresses[validatorId].push(nodeAddress);
    }

    function _find(uint[] memory array, uint index) private pure returns (uint) {
        uint i;
        for (i = 0; i < array.length; i++) {
            if (array[i] == index) {
                return i;
            }
        }
        return array.length;
    }
}