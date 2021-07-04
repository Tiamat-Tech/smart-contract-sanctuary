// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title TXValidator
 * @version 0.0.1
 * @author Francesco Sullo <[email protected]>
 */

// import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./interfaces/ITXValidator.sol";

contract TXValidator is Ownable, ITXValidator {

    using ECDSA for bytes32;

    mapping(uint => mapping(address => bool)) private _validatorsByGroupId;
    mapping(address => bytes32) private _validatorsNames;

    address public defaultValidator;
    uint public defaultValidFor = 3e4;
    mapping(uint => uint) public validForByGroupId;

    function isValidatorForGroup(uint groupId_, address validator_)
    external view override
    returns (bool)
    {
        return _validatorsByGroupId[groupId_][validator_];
    }

    constructor(
        address defaultValidator_
    ) {
        defaultValidator = defaultValidator_;
    }

    function updateDefaultValidator(address newDefaultValidator_) external override
    onlyOwner
    {
        defaultValidator = newDefaultValidator_;
    }

    function _addValidator(uint groupId_, bytes32 validatorName_, address validator_) internal
    {
        _validatorsByGroupId[groupId_][validator_] = true;
        if (_validatorsNames[validator_] != validatorName_) {
            _validatorsNames[validator_] = validatorName_;
        }
        emit ValidatorAdded(groupId_, validator_);
    }

    function addValidator(uint groupId_, bytes32 validatorName_, address validator_) external override
    onlyOwner
    {
        require(validator_ != address(0), "Validator can not be 0x0");
        require(validatorName_ != 0, "ValidatorName can not be empty");
        require(!_validatorsByGroupId[groupId_][validator_], "Validator already set");
        _addValidator(groupId_, validatorName_, validator_);
    }

    function _removeValidator(uint groupId_, address validator_) internal
    {
        delete _validatorsByGroupId[groupId_][validator_];
        emit ValidatorRemoved(groupId_, validator_);
    }

    function removeValidator(uint groupId_, address validator_) external override
    onlyOwner
    {
        require(_validatorsByGroupId[groupId_][validator_], "Validator not found");
        _removeValidator(groupId_, validator_);
    }

    function updateValidator(uint groupId_, address validator_, address newValidator_) external override
    onlyOwner
    {
        require(newValidator_ != address(0), "New validator can not be 0x0");
        require(newValidator_ != validator_, "No changes");
        require(_validatorsByGroupId[groupId_][validator_], "Validator not found");
        require(!_validatorsByGroupId[groupId_][newValidator_], "New validator already set");
        bytes32 validatorName = _validatorsNames[validator_];
        _removeValidator(groupId_, validator_);
        _addValidator(groupId_, validatorName, newValidator_);
    }

    function updateTimestampValidFor(uint groupId_, uint _validFor) external override
    onlyOwner
    {
        validForByGroupId[groupId_] = _validFor;
        emit ValidForByGroupIdUpdated(groupId_, _validFor);
    }

    function getChainId()
    public view override
    returns (uint256) {
        uint256 id;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            id := chainid()
        }
        return id;
    }

    function isValidForGroupId(
        uint groupId_,
        uint timestamp_
    ) external view override
    returns (bool)
    {
        require(
            // solium-disable-next-line security/no-block-members
            timestamp_ < block.timestamp,
            "Invalid timestamp"
        );
        uint validFor = validForByGroupId[groupId_];
        if (validFor == 0) {
            validFor = defaultValidFor;
        }
        require(
            // solium-disable-next-line security/no-block-members
            timestamp_ > block.timestamp - validFor,
            "Signature expired"
        );
        return true;
    }

    function isSignedByValidator(
        uint groupId_,
        bytes32 hash_,
        bytes memory signature_
    ) public view override
    returns (address)
    {
        address validator = ECDSA.recover(hash_, signature_);
//        console.log("validator %s", validator);
        if (validator == defaultValidator || _validatorsByGroupId[groupId_][validator]) {
            return validator;
        } else {
            return address(0);
        }
    }

    function getValidatorName(
        address address_
    ) public view override
    returns (bytes32)
    {
        return _validatorsNames[address_];
    }

}