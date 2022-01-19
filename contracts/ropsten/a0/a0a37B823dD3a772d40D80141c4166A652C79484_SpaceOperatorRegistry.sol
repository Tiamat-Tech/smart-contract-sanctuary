// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./ISpaceOperatorRegistry.sol";

contract SpaceOperatorRegistry is
    ISpaceOperatorRegistry,
    AccessControlUpgradeable
{
    bytes32 public constant SPACE_OPERATOR_REGISTER_ROLE =
        keccak256("SPACE_OPERATOR_REGISTER_ROLE");

    mapping(address => address) public operatorToSpace;
    mapping(address => uint8) public operatorToComission;

    mapping(address => bool) public isApprovedOperator;

    function initialize() public initializer {
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(SPACE_OPERATOR_REGISTER_ROLE, msg.sender);
    }

    function setOperatorForSpace(address _operator, address _space)
        external
        override
    {
        require(hasRole(SPACE_OPERATOR_REGISTER_ROLE, msg.sender));
        operatorToSpace[_operator] = _space;
    }

    function isSpaceOperator(address _operator)
        external
        view
        override
        returns (bool)
    {
        return isApprovedOperator[_operator];
    }

    function getSpaceOperatorFor(address _operator)
        external
        view
        override
        returns (address)
    {
        return operatorToSpace[_operator];
    }

    function getSpaceCommission(address _operator)
        external
        view
        override
        returns (uint8)
    {
        return operatorToComission[_operator];
    }

    function setSpaceCommission(address _operator, uint8 _commission)
        external
        override
    {
        require(hasRole(SPACE_OPERATOR_REGISTER_ROLE, msg.sender));
        operatorToComission[_operator] = _commission;
    }

    function isApprovedSpaceOperator(address _operator)
        external
        view
        override
        returns (bool)
    {
        return isApprovedOperator[_operator];
    }

    function setSpaceOperatorApproved(address _operator, bool _approved)
        external
        override
    {
        require(hasRole(SPACE_OPERATOR_REGISTER_ROLE, msg.sender));
        isApprovedOperator[_operator] = _approved;
    }
}